use crate::{
    approval::{self, ApprovalView},
    domain::{
        Effect, EvidenceEvent, GovernedOperationResult, OperationRequest, RuntimeCapability,
        SystemStatus,
    },
    evidence,
    executor::{self, HandlerMetadata},
    identity::{self, AuthenticatedContext, FederationProviderStatus},
    policy::PolicyEngine,
    Runtime,
};
use rusqlite::Connection;
use tauri::State;
use uuid::Uuid;

#[tauri::command]
pub fn execute_governed(
    session_id: String,
    approval_id: Option<String>,
    request: OperationRequest,
    state: State<Runtime>,
) -> Result<GovernedOperationResult, String> {
    let mut db = state
        .db
        .lock()
        .map_err(|_| "Database lock unavailable".to_string())?;
    execute_governed_with_approval_local(
        &state.policy,
        &mut db,
        &session_id,
        approval_id.as_deref(),
        request,
    )
}

#[cfg(test)]
fn execute_governed_local(
    policy: &PolicyEngine,
    db: &mut Connection,
    session_id: &str,
    request: OperationRequest,
) -> Result<GovernedOperationResult, String> {
    execute_governed_with_approval_local(policy, db, session_id, None, request)
}

fn execute_governed_with_approval_local(
    policy: &PolicyEngine,
    db: &mut Connection,
    session_id: &str,
    approval_id: Option<&str>,
    mut request: OperationRequest,
) -> Result<GovernedOperationResult, String> {
    let context = identity::authenticate(db, session_id, &request.workspace)?;
    request.principal = context.principal_id;
    request.assurance = match context.assurance.as_str() {
        "AAL3" => crate::domain::AssuranceLevel::AAL3,
        "AAL2" => crate::domain::AssuranceLevel::AAL2,
        "mTLS" => crate::domain::AssuranceLevel::MutualTls,
        "Scoped capability" => crate::domain::AssuranceLevel::ScopedCapability,
        _ => return Err("Session has an unsupported assurance level".into()),
    };
    let request_hash = crate::policy::hash_request(&request);
    if let Err(error) = claim_request(db, session_id, &request.request_id, &request_hash) {
        if approval_id.is_none()
            || !claimed_request_matches(db, session_id, &request.request_id, &request_hash)?
        {
            return Err(error);
        }
    }
    let mut decision = policy.evaluate(db, &request, &context.role);
    let handler = executor::for_action(&request.action);
    let prepared = if decision.effect == Effect::Permit
        || (decision.effect == Effect::RequireApproval && handler.available)
    {
        Some(executor::prepare(db, &request)?)
    } else {
        None
    };
    if decision.effect == Effect::RequireApproval {
        if let Some(id) = approval_id {
            if !handler.available {
                return Err(format!(
                    "Handler {} is explicitly unavailable; approval was not consumed",
                    handler.id
                ));
            }
            approval::consume(db, id, &request.request_id, &request_hash)?;
            decision.effect = Effect::Permit;
            decision.reasons = vec![
                "Active policy requires approval".into(),
                "Exact request-bound approval consumed once".into(),
            ];
        }
    }
    let authorization = evidence::append_authorization(db, &request, &decision)
        .map_err(|_| "Authorization evidence could not be recorded".to_string())?;
    if decision.effect == Effect::RequireApproval {
        approval::request(db, &request, &decision.request_hash, 1)?;
    }
    if decision.effect != Effect::Permit {
        return Ok(GovernedOperationResult {
            authorization,
            execution: None,
            execution_evidence: None,
        });
    }
    let operation_id = format!(
        "OP-{}",
        Uuid::new_v4().simple().to_string()[..8].to_uppercase()
    );
    assign_operation_id(db, &request.request_id, &operation_id)?;
    let execution = executor::execute(
        db,
        &request,
        &operation_id,
        prepared
            .as_ref()
            .expect("permitted requests prepare a handler"),
    )?;
    let execution_evidence = evidence::append_execution(db, &authorization, &execution)
        .map_err(|_| "Execution evidence could not be recorded".to_string())?;
    Ok(GovernedOperationResult {
        authorization,
        execution: Some(execution),
        execution_evidence: Some(execution_evidence),
    })
}

fn claimed_request_matches(
    db: &Connection,
    session_id: &str,
    request_id: &str,
    request_hash: &str,
) -> Result<bool, String> {
    db.query_row("select exists(select 1 from authority_request where request_id=?1 and session_id=?2 and request_hash=?3 and operation_id is null)",rusqlite::params![request_id,session_id,request_hash],|r|r.get(0)).map_err(|_|"Request claim could not be verified".to_string())
}

pub(crate) fn claim_request(
    db: &Connection,
    session_id: &str,
    request_id: &str,
    request_hash: &str,
) -> Result<(), String> {
    db.execute(
        "insert into authority_request(request_id,session_id,request_hash,created_at,expires_at) values(?1,?2,?3,datetime('now'),datetime('now','+24 hours'))",
        rusqlite::params![request_id, session_id, request_hash],
    )
    .map(|_| ())
    .map_err(|_| "Request ID has already been claimed; replay rejected".to_string())
}

fn assign_operation_id(
    db: &Connection,
    request_id: &str,
    operation_id: &str,
) -> Result<(), String> {
    if db.execute("update authority_request set operation_id=?1 where request_id=?2 and operation_id is null", rusqlite::params![operation_id, request_id]).map_err(|_| "Operation ID could not be assigned".to_string())? != 1 {
        return Err("Request already has an operation ID; duplicate execution rejected".into());
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::{AssuranceLevel, ProtectedAction};
    use siddham_contracts::{RuntimeOperation, SCHEMA_VERSION};

    fn request(action: ProtectedAction) -> OperationRequest {
        OperationRequest {
            schema_version: SCHEMA_VERSION.into(),
            request_id: "req-command".into(),
            principal: "release-authority".into(),
            action: action.clone(),
            resource: "runtime-core".into(),
            workspace: "siddham-core-rd".into(),
            assurance: AssuranceLevel::AAL3,
            operation: (action == ProtectedAction::RuntimeExecute).then(|| {
                RuntimeOperation::TokenizeBrahmi {
                    text: "𑀅".into()
                }
            }),
        }
    }

    fn database() -> (Connection, String) {
        let mut db = crate::storage::memory().unwrap();
        let session_id = identity::ensure_local_bootstrap(&mut db).unwrap();
        crate::policy::ensure_default(&db).unwrap();
        crate::executor::ensure_defaults(&db).unwrap();
        (db, session_id)
    }

    #[test]
    fn permitted_operation_executes_and_links_evidence() {
        let (mut db, session_id) = database();
        let result = execute_governed_local(
            &PolicyEngine,
            &mut db,
            &session_id,
            request(ProtectedAction::RuntimeExecute),
        )
        .unwrap();
        assert_eq!(result.authorization.decision, Effect::Permit);
        assert!(result.execution.is_some());
        assert_eq!(
            result.execution_evidence.unwrap().authorization_event_id,
            result.authorization.id
        );
        assert!(evidence::verify(&db).unwrap());
    }

    #[test]
    fn unavailable_action_is_recorded_but_never_executed() {
        let (mut db, session_id) = database();
        let result = execute_governed_local(
            &PolicyEngine,
            &mut db,
            &session_id,
            request(ProtectedAction::HardwareProgram),
        )
        .unwrap();
        assert_eq!(result.authorization.decision, Effect::Deny);
        assert!(result.execution.is_none());
        assert!(result.execution_evidence.is_none());
        assert!(evidence::verify(&db).unwrap());
    }

    #[test]
    fn request_cannot_choose_a_more_privileged_principal_or_assurance() {
        let (mut db, session_id) = database();
        db.execute(
            "update authority_session set assurance='AAL2' where id=?1",
            [&session_id],
        )
        .unwrap();
        let mut forged = request(ProtectedAction::ReleaseApprove);
        forged.principal = "release-authority".into();
        forged.assurance = AssuranceLevel::AAL3;
        let result = execute_governed_local(&PolicyEngine, &mut db, &session_id, forged).unwrap();
        assert_eq!(
            result.authorization.decision,
            Effect::RequireStepUpAuthentication
        );
    }

    #[test]
    fn cross_workspace_substitution_is_rejected_before_policy_or_evidence() {
        let (mut db, session_id) = database();
        let mut forged = request(ProtectedAction::RuntimeExecute);
        forged.workspace = "prototype-lab".into();
        assert!(execute_governed_local(&PolicyEngine, &mut db, &session_id, forged).is_err());
        assert!(evidence::list(&db, 10).unwrap().is_empty());
    }

    #[test]
    fn request_replay_is_rejected_without_second_execution_or_evidence() {
        let (mut db, session_id) = database();
        let first = execute_governed_local(
            &PolicyEngine,
            &mut db,
            &session_id,
            request(ProtectedAction::RuntimeExecute),
        )
        .unwrap();
        assert!(first.execution.is_some());
        let replay = execute_governed_local(
            &PolicyEngine,
            &mut db,
            &session_id,
            request(ProtectedAction::RuntimeExecute),
        );
        assert!(replay.is_err());
        assert_eq!(evidence::list(&db, 10).unwrap().len(), 1);
        let operations: i64 = db
            .query_row("select count(*) from execution_event", [], |r| r.get(0))
            .unwrap();
        assert_eq!(operations, 1);
    }

    #[test]
    fn each_permitted_execution_gets_exactly_one_operation_id() {
        let (mut db, session_id) = database();
        execute_governed_local(
            &PolicyEngine,
            &mut db,
            &session_id,
            request(ProtectedAction::RuntimeExecute),
        )
        .unwrap();
        let count: i64 = db
            .query_row(
                "select count(operation_id) from authority_request where request_id='req-command'",
                [],
                |r| r.get(0),
            )
            .unwrap();
        assert_eq!(count, 1);
    }

    #[test]
    fn approval_decision_creates_a_bound_pending_inbox_item() {
        let (mut db, session_id) = database();
        let mut operation = request(ProtectedAction::DatasetExport);
        operation.resource = "restricted-ip".into();
        let result =
            execute_governed_local(&PolicyEngine, &mut db, &session_id, operation).unwrap();
        assert_eq!(result.authorization.decision, Effect::RequireApproval);
        let approvals = approval::list(&db, "siddham-core-rd").unwrap();
        assert_eq!(approvals.len(), 1);
        assert_eq!(approvals[0].request_hash, result.authorization.request_hash);
        assert_eq!(approvals[0].status, "pending");
    }

    #[test]
    fn approved_dataset_export_resumes_once_through_the_registry() {
        let (mut db, session_id) = database();
        db.execute("insert into principal values('security-checker','human','Security Checker','active',datetime('now'),null)",[]).unwrap();
        db.execute("insert into device values('device-checker','security-checker','Checker device','sha256:checker','active',0,datetime('now'),null)",[]).unwrap();
        db.execute("insert into workspace_membership values('siddham-core-rd','security-checker','security-reviewer','active',datetime('now'))",[]).unwrap();
        let checker = format!("session-{}", Uuid::new_v4().simple());
        db.execute("insert into authority_session values(?1,'security-checker','device-checker','AAL3',0,datetime('now'),datetime('now','+8 hours'),null)",[&checker]).unwrap();
        let mut operation = request(ProtectedAction::DatasetExport);
        operation.resource = "restricted-ip".into();
        let pending =
            execute_governed_local(&PolicyEngine, &mut db, &session_id, operation.clone()).unwrap();
        assert_eq!(pending.authorization.decision, Effect::RequireApproval);
        let approval_id = approval::list(&db, "siddham-core-rd").unwrap()[0]
            .id
            .clone();
        approval::decide(
            &db,
            &checker,
            &approval_id,
            "approve",
            "independent export review",
        )
        .unwrap();
        let executed = execute_governed_with_approval_local(
            &PolicyEngine,
            &mut db,
            &session_id,
            Some(&approval_id),
            operation.clone(),
        )
        .unwrap();
        assert_eq!(executed.authorization.decision, Effect::Permit);
        assert_eq!(
            executed.execution.as_ref().unwrap().output["exportType"],
            "manifest-only"
        );
        assert!(execute_governed_with_approval_local(
            &PolicyEngine,
            &mut db,
            &session_id,
            Some(&approval_id),
            operation
        )
        .is_err());
    }

    #[test]
    fn cancelled_pending_execution_cannot_resume() {
        let (mut db, session_id) = database();
        let mut operation = request(ProtectedAction::DatasetExport);
        operation.resource = "restricted-ip".into();
        execute_governed_local(&PolicyEngine, &mut db, &session_id, operation.clone()).unwrap();
        assert!(executor::cancel(&db, &operation.request_id).unwrap());
        let approval_id = approval::list(&db, "siddham-core-rd").unwrap()[0]
            .id
            .clone();
        db.execute(
            "update approval_request set status='approved',decided_at=datetime('now') where id=?1",
            [&approval_id],
        )
        .unwrap();
        assert!(execute_governed_with_approval_local(
            &PolicyEngine,
            &mut db,
            &session_id,
            Some(&approval_id),
            operation
        )
        .is_err());
        let status: String = db
            .query_row(
                "select status from approval_request where id=?1",
                [approval_id],
                |r| r.get(0),
            )
            .unwrap();
        assert_eq!(status, "approved");
    }
}

#[tauri::command]
pub fn identity_context(state: State<Runtime>) -> Result<AuthenticatedContext, String> {
    let db = state
        .db
        .lock()
        .map_err(|_| "Database lock unavailable".to_string())?;
    identity::authenticate(&db, &state.local_session_id, "siddham-core-rd")
}

#[tauri::command]
pub fn list_federation_providers(
    state: State<Runtime>,
) -> Result<Vec<FederationProviderStatus>, String> {
    let db = state
        .db
        .lock()
        .map_err(|_| "Database lock unavailable".to_string())?;
    identity::federation_providers(&db)
        .map_err(|_| "Federation configuration could not be loaded".to_string())
}

#[tauri::command]
pub fn revoke_current_session(state: State<Runtime>) -> Result<bool, String> {
    let db = state
        .db
        .lock()
        .map_err(|_| "Database lock unavailable".to_string())?;
    identity::revoke_session(&db, &state.local_session_id)
        .map_err(|_| "Session could not be revoked".to_string())
}

#[tauri::command]
pub fn revoke_current_device(state: State<Runtime>) -> Result<bool, String> {
    let db = state
        .db
        .lock()
        .map_err(|_| "Database lock unavailable".to_string())?;
    identity::revoke_device(&db, "device-local-authority")
        .map_err(|_| "Device could not be revoked".to_string())
}

#[tauri::command]
pub fn list_approvals(state: State<Runtime>) -> Result<Vec<ApprovalView>, String> {
    let db = state
        .db
        .lock()
        .map_err(|_| "Database lock unavailable".to_string())?;
    let context = identity::authenticate(&db, &state.local_session_id, "siddham-core-rd")?;
    approval::list(&db, &context.workspace_id)
}

#[tauri::command]
pub fn submit_approval_decision(
    session_id: String,
    approval_id: String,
    decision: String,
    comment: String,
    state: State<Runtime>,
) -> Result<ApprovalView, String> {
    let db = state
        .db
        .lock()
        .map_err(|_| "Database lock unavailable".to_string())?;
    approval::decide(&db, &session_id, &approval_id, &decision, &comment)
}

#[tauri::command]
pub fn cancel_approval(approval_id: String, state: State<Runtime>) -> Result<ApprovalView, String> {
    let db = state
        .db
        .lock()
        .map_err(|_| "Database lock unavailable".to_string())?;
    let context = identity::authenticate(&db, &state.local_session_id, "siddham-core-rd")?;
    approval::cancel(&db, &approval_id, &context.principal_id)
}

#[tauri::command]
pub fn runtime_capabilities() -> Vec<RuntimeCapability> {
    maataa_runtime::runtime_capabilities()
}

#[tauri::command]
pub fn handler_registry() -> Vec<HandlerMetadata> {
    executor::registry()
}

#[tauri::command]
pub fn cancel_execution(request_id: String, state: State<Runtime>) -> Result<bool, String> {
    let db = state
        .db
        .lock()
        .map_err(|_| "Database lock unavailable".to_string())?;
    executor::cancel(&db, &request_id)
}

#[tauri::command]
pub fn list_evidence(state: State<Runtime>) -> Result<Vec<EvidenceEvent>, String> {
    let db = state
        .db
        .lock()
        .map_err(|_| "Database lock unavailable".to_string())?;
    evidence::list(&db, 100).map_err(|_| "Evidence could not be loaded".to_string())
}

#[tauri::command]
pub fn verify_evidence_chain(state: State<Runtime>) -> Result<bool, String> {
    let db = state
        .db
        .lock()
        .map_err(|_| "Database lock unavailable".to_string())?;
    evidence::verify(&db).map_err(|_| "Evidence chain could not be verified".to_string())
}

#[tauri::command]
pub fn system_status(state: State<Runtime>) -> Result<SystemStatus, String> {
    let db = state
        .db
        .lock()
        .map_err(|_| "Database lock unavailable".to_string())?;
    Ok(SystemStatus {
        database: "ready",
        policy_version: state.policy.active_version(&db)?,
        evidence_chain_valid: evidence::verify(&db)
            .map_err(|_| "Evidence chain could not be verified".to_string())?,
        sync_mode: "offline_outbox",
        capabilities: maataa_runtime::runtime_capabilities(),
    })
}
