use crate::{
    domain::{AuthorizationDecision, EvidenceEvent, ExecutionEvidence, OperationRequest},
    policy,
};
use chrono::Utc;
use rusqlite::{params, Connection};
use serde::Serialize;
use sha2::{Digest, Sha256};
use siddham_contracts::ExecutionResult;
#[cfg(test)]
use siddham_contracts::{AssuranceLevel, ProtectedAction};
use uuid::Uuid;

const EVIDENCE_SCHEMA_VERSION: u32 = 2;

#[derive(Serialize)]
struct AuthorizationHash<'a> {
    schema_version: u32,
    id: &'a str,
    request: &'a OperationRequest,
    decision: &'a AuthorizationDecision,
    previous_event_hash: Option<&'a str>,
    created_at: &'a str,
}

#[derive(Serialize)]
struct ExecutionHash<'a> {
    id: &'a str,
    authorization_event_id: &'a str,
    result: &'a ExecutionResult,
    created_at: &'a str,
}

pub fn append_authorization(
    db: &mut Connection,
    request: &OperationRequest,
    decision: &AuthorizationDecision,
) -> rusqlite::Result<EvidenceEvent> {
    let tx = db.transaction()?;
    let previous: Option<String> = tx
        .query_row(
            "select event_hash from audit_event order by seq desc limit 1",
            [],
            |row| row.get(0),
        )
        .ok();
    let id = event_id("AUTH");
    let created_at = Utc::now().to_rfc3339();
    let event_hash = authorization_hash(&id, request, decision, previous.as_deref(), &created_at);
    let assurance = enum_string(&request.assurance);
    let reasons = serde_json::to_string(&decision.reasons).expect("reasons serialize");
    tx.execute(
        "insert into audit_event(id,principal,action,resource,workspace,decision,policy_version,request_hash,event_hash,previous_event_hash,created_at,assurance,decision_reasons,policy_digest,schema_version,request_id) values(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        params![&id,&request.principal,request.action.as_str(),&request.resource,&request.workspace,decision.effect.as_str(),&decision.policy_version,&decision.request_hash,&event_hash,&previous,&created_at,assurance,reasons,&decision.policy_digest,EVIDENCE_SCHEMA_VERSION,&request.request_id],
    )?;
    let payload =
        serde_json::to_string(&(request, decision)).expect("authorization outbox serializes");
    tx.execute(
        "insert into sync_outbox(event_id,payload,created_at) values(?,?,?)",
        params![&id, payload, &created_at],
    )?;
    tx.commit()?;
    Ok(EvidenceEvent {
        id,
        request_id: request.request_id.clone(),
        principal: request.principal.clone(),
        action: request.action.clone(),
        resource: request.resource.clone(),
        workspace: request.workspace.clone(),
        assurance: request.assurance.clone(),
        decision: decision.effect.clone(),
        reasons: decision.reasons.clone(),
        policy_version: decision.policy_version.clone(),
        policy_digest: decision.policy_digest.clone(),
        request_hash: decision.request_hash.clone(),
        event_hash,
        previous_event_hash: previous,
        schema_version: EVIDENCE_SCHEMA_VERSION,
        created_at,
    })
}

pub fn append_execution(
    db: &mut Connection,
    authorization: &EvidenceEvent,
    result: &ExecutionResult,
) -> rusqlite::Result<ExecutionEvidence> {
    let tx = db.transaction()?;
    let id = event_id("EXEC");
    let created_at = Utc::now().to_rfc3339();
    let event_hash = execution_hash(&id, &authorization.id, result, &created_at);
    tx.execute(
        "insert into execution_event(id,authorization_event_id,request_id,operation_id,status,execution_mode,input_digest,output_digest,event_hash,created_at) values(?,?,?,?,?,?,?,?,?,?)",
        params![&id,&authorization.id,&result.request_id,&result.operation_id,enum_string(&result.status),enum_string(&result.execution_mode),&result.input_digest,&result.output_digest,&event_hash,&created_at],
    )?;
    let payload = serde_json::to_string(result).expect("execution outbox serializes");
    tx.execute(
        "insert into execution_outbox(event_id,payload,created_at) values(?,?,?)",
        params![&id, payload, &created_at],
    )?;
    tx.commit()?;
    Ok(ExecutionEvidence {
        id,
        authorization_event_id: authorization.id.clone(),
        request_id: result.request_id.clone(),
        operation_id: result.operation_id.clone(),
        status: result.status.clone(),
        execution_mode: result.execution_mode.clone(),
        input_digest: result.input_digest.clone(),
        output_digest: result.output_digest.clone(),
        event_hash,
        created_at,
    })
}

pub fn list(db: &Connection, limit: u32) -> rusqlite::Result<Vec<EvidenceEvent>> {
    let mut statement = db.prepare("select id,request_id,principal,action,resource,workspace,assurance,decision,decision_reasons,policy_version,policy_digest,request_hash,event_hash,previous_event_hash,schema_version,created_at from audit_event order by seq desc limit ?")?;
    let events = statement.query_map([limit], event_from_row)?.collect();
    events
}

pub fn verify(db: &Connection) -> rusqlite::Result<bool> {
    let mut statement = db.prepare("select id,request_id,principal,action,resource,workspace,assurance,decision,decision_reasons,policy_version,policy_digest,request_hash,event_hash,previous_event_hash,schema_version,created_at from audit_event order by seq asc")?;
    let events: Vec<EvidenceEvent> = statement
        .query_map([], event_from_row)?
        .collect::<rusqlite::Result<_>>()?;
    let mut previous: Option<String> = None;
    for event in events {
        if event.previous_event_hash != previous || event.schema_version != EVIDENCE_SCHEMA_VERSION
        {
            return Ok(false);
        }
        let request = OperationRequest {
            schema_version: siddham_contracts::SCHEMA_VERSION.into(),
            request_id: event.request_id,
            principal: event.principal,
            action: event.action,
            resource: event.resource,
            workspace: event.workspace,
            assurance: event.assurance,
            operation: None,
        };
        let decision = AuthorizationDecision {
            effect: event.decision,
            reasons: event.reasons,
            policy_version: event.policy_version,
            policy_digest: event.policy_digest,
            request_hash: event.request_hash,
        };
        // Runtime operation payload is covered by request_hash but is not stored in v2 audit columns.
        // The serialized outbox is the reconstruction authority for runtime requests.
        let stored_payload: String = db.query_row(
            "select payload from sync_outbox where event_id=?",
            [&event.id],
            |row| row.get(0),
        )?;
        let (stored_request, stored_decision): (OperationRequest, AuthorizationDecision) =
            match serde_json::from_str(&stored_payload) {
                Ok(value) => value,
                Err(_) => return Ok(false),
            };
        if stored_request.request_id != request.request_id
            || stored_decision != decision
            || policy::hash_request(&stored_request) != decision.request_hash
        {
            return Ok(false);
        }
        if event.event_hash
            != authorization_hash(
                &event.id,
                &stored_request,
                &decision,
                previous.as_deref(),
                &event.created_at,
            )
        {
            return Ok(false);
        }
        previous = Some(event.event_hash);
    }
    verify_execution_links(db)
}

fn verify_execution_links(db: &Connection) -> rusqlite::Result<bool> {
    let mut statement = db.prepare("select id,authorization_event_id,request_id,operation_id,status,execution_mode,input_digest,output_digest,event_hash,created_at from execution_event order by seq asc")?;
    let rows = statement.query_map([], |row| {
        Ok((
            row.get::<_, String>(0)?,
            row.get::<_, String>(1)?,
            row.get::<_, String>(2)?,
            row.get::<_, String>(3)?,
            row.get::<_, String>(4)?,
            row.get::<_, String>(5)?,
            row.get::<_, String>(6)?,
            row.get::<_, String>(7)?,
            row.get::<_, String>(8)?,
            row.get::<_, String>(9)?,
        ))
    })?;
    for row in rows {
        let (
            id,
            auth_id,
            request_id,
            operation_id,
            status,
            mode,
            input_digest,
            output_digest,
            event_hash,
            created_at,
        ) = row?;
        let payload: String = db.query_row(
            "select payload from execution_outbox where event_id=?",
            [&id],
            |r| r.get(0),
        )?;
        let result: ExecutionResult = match serde_json::from_str(&payload) {
            Ok(value) => value,
            Err(_) => return Ok(false),
        };
        if result.request_id != request_id
            || result.operation_id != operation_id
            || enum_string(&result.status) != status
            || enum_string(&result.execution_mode) != mode
            || result.input_digest != input_digest
            || result.output_digest != output_digest
            || execution_hash(&id, &auth_id, &result, &created_at) != event_hash
        {
            return Ok(false);
        }
    }
    Ok(true)
}

fn event_from_row(row: &rusqlite::Row<'_>) -> rusqlite::Result<EvidenceEvent> {
    Ok(EvidenceEvent {
        id: row.get(0)?,
        request_id: row.get(1)?,
        principal: row.get(2)?,
        action: parse_enum(row.get(3)?)?,
        resource: row.get(4)?,
        workspace: row.get(5)?,
        assurance: parse_enum(row.get(6)?)?,
        decision: parse_enum(row.get(7)?)?,
        reasons: serde_json::from_str(&row.get::<_, String>(8)?).map_err(json_error)?,
        policy_version: row.get(9)?,
        policy_digest: row.get(10)?,
        request_hash: row.get(11)?,
        event_hash: row.get(12)?,
        previous_event_hash: row.get(13)?,
        schema_version: row.get(14)?,
        created_at: row.get(15)?,
    })
}

fn parse_enum<T: serde::de::DeserializeOwned>(value: String) -> rusqlite::Result<T> {
    serde_json::from_value(serde_json::Value::String(value)).map_err(json_error)
}
fn json_error(error: serde_json::Error) -> rusqlite::Error {
    rusqlite::Error::FromSqlConversionFailure(0, rusqlite::types::Type::Text, Box::new(error))
}
fn enum_string<T: Serialize>(value: &T) -> String {
    serde_json::to_value(value)
        .expect("enum serializes")
        .as_str()
        .expect("enum is string")
        .into()
}
fn event_id(prefix: &str) -> String {
    format!(
        "{prefix}-{}",
        &Uuid::new_v4().simple().to_string()[..8].to_uppercase()
    )
}
fn authorization_hash(
    id: &str,
    request: &OperationRequest,
    decision: &AuthorizationDecision,
    previous: Option<&str>,
    created_at: &str,
) -> String {
    digest(
        &serde_json::to_vec(&AuthorizationHash {
            schema_version: EVIDENCE_SCHEMA_VERSION,
            id,
            request,
            decision,
            previous_event_hash: previous,
            created_at,
        })
        .expect("authorization hash serializes"),
    )
}
fn execution_hash(
    id: &str,
    authorization_event_id: &str,
    result: &ExecutionResult,
    created_at: &str,
) -> String {
    digest(
        &serde_json::to_vec(&ExecutionHash {
            id,
            authorization_event_id,
            result,
            created_at,
        })
        .expect("execution hash serializes"),
    )
}
fn digest(bytes: &[u8]) -> String {
    hex::encode(Sha256::digest(bytes))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{policy::PolicyEngine, storage};
    use siddham_contracts::{RuntimeOperation, SCHEMA_VERSION};
    fn request() -> OperationRequest {
        OperationRequest {
            schema_version: SCHEMA_VERSION.into(),
            request_id: "REQ-test".into(),
            principal: "Release Authority".into(),
            action: ProtectedAction::RuntimeExecute,
            resource: "Tokenizer".into(),
            workspace: "Core".into(),
            assurance: AssuranceLevel::AAL3,
            operation: Some(RuntimeOperation::TokenizeBrahmi {
                text: "𑀅".into()
            }),
        }
    }
    #[test]
    fn linked_authorization_and_execution_verify() {
        let mut db = storage::memory().unwrap();
        let request = request();
        let decision = PolicyEngine::default().evaluate(&request);
        let auth = append_authorization(&mut db, &request, &decision).unwrap();
        let result = maataa_runtime::execute_contract_operation(
            &request.request_id,
            "OP-test",
            request.operation.as_ref().unwrap(),
        )
        .unwrap();
        let execution = append_execution(&mut db, &auth, &result).unwrap();
        assert_eq!(execution.authorization_event_id, auth.id);
        assert!(verify(&db).unwrap());
    }
    #[test]
    fn execution_outbox_failure_rolls_back_execution() {
        let mut db = storage::memory().unwrap();
        let request = request();
        let decision = PolicyEngine::default().evaluate(&request);
        let auth = append_authorization(&mut db, &request, &decision).unwrap();
        db.execute_batch("create trigger reject_execution_outbox before insert on execution_outbox begin select raise(abort,'forced'); end;").unwrap();
        let result = maataa_runtime::execute_contract_operation(
            &request.request_id,
            "OP-test",
            request.operation.as_ref().unwrap(),
        )
        .unwrap();
        assert!(append_execution(&mut db, &auth, &result).is_err());
        let count: u32 = db
            .query_row("select count(*) from execution_event", [], |row| row.get(0))
            .unwrap();
        assert_eq!(count, 0);
    }

    #[test]
    fn tampered_execution_breaks_verification() {
        let mut db = storage::memory().unwrap();
        let request = request();
        let decision = PolicyEngine::default().evaluate(&request);
        let auth = append_authorization(&mut db, &request, &decision).unwrap();
        let result = maataa_runtime::execute_contract_operation(
            &request.request_id,
            "OP-test",
            request.operation.as_ref().unwrap(),
        )
        .unwrap();
        append_execution(&mut db, &auth, &result).unwrap();
        db.execute_batch("drop trigger execution_no_update;")
            .unwrap();
        db.execute("update execution_event set output_digest = 'forged'", [])
            .unwrap();
        assert!(!verify(&db).unwrap());
    }
}
