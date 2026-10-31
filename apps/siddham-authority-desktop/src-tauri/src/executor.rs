use crate::domain::{OperationRequest, ProtectedAction};
use rusqlite::{params, Connection};
use serde::Serialize;
use serde_json::json;
use sha2::{Digest, Sha256};
use siddham_contracts::{
    ExecutionMode, ExecutionResult, ExecutionStatus, RuntimeOperation, SCHEMA_VERSION,
};
use std::time::Instant;

const MAX_INPUT_BYTES: u32 = 16 * 1024;
const DEADLINE_SECONDS: u32 = 2;

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct HandlerMetadata {
    pub id: &'static str,
    pub action: &'static str,
    pub available: bool,
    pub approval_required: bool,
    pub target: &'static str,
    pub max_input_bytes: u32,
    pub deadline_millis: u32,
    pub detail: &'static str,
}

pub fn registry() -> Vec<HandlerMetadata> {
    vec![
        handler(
            "workspace-view",
            "workspace:view",
            true,
            false,
            "software-native",
            "Workspace metadata view",
        ),
        handler(
            "maataa-runtime",
            "runtime:execute",
            true,
            false,
            "software-native",
            "Three typed MAATAA language operations",
        ),
        handler(
            "dataset-read",
            "dataset:read",
            true,
            false,
            "software-native",
            "Governed dataset metadata read",
        ),
        handler(
            "dataset-export",
            "dataset:export",
            true,
            true,
            "software-native",
            "Approval-bound dataset manifest export",
        ),
        handler(
            "model-promote",
            "model:promote",
            true,
            true,
            "software-native",
            "Approval-bound local model state transition",
        ),
        handler(
            "agent-delegation",
            "agent:delegate",
            false,
            true,
            "unavailable",
            "Use the scoped delegation lifecycle; request payload contract pending",
        ),
        handler(
            "policy-lifecycle",
            "policy:edit",
            false,
            true,
            "unavailable",
            "Use validated policy lifecycle; governed edit payload contract pending",
        ),
        handler(
            "release-approve",
            "release:approve",
            true,
            true,
            "software-native",
            "Approval-bound local release state transition",
        ),
        handler(
            "evidence-export",
            "evidence:export",
            true,
            false,
            "software-native",
            "Local evidence summary export",
        ),
        handler(
            "hardware-program",
            "hardware:program",
            false,
            true,
            "unavailable",
            "Blocked pending Phase 11 hardware qualification",
        ),
    ]
}
fn handler(
    id: &'static str,
    action: &'static str,
    available: bool,
    approval_required: bool,
    target: &'static str,
    detail: &'static str,
) -> HandlerMetadata {
    HandlerMetadata {
        id,
        action,
        available,
        approval_required,
        target,
        max_input_bytes: MAX_INPUT_BYTES,
        deadline_millis: DEADLINE_SECONDS * 1000,
        detail,
    }
}
pub fn for_action(action: &ProtectedAction) -> HandlerMetadata {
    registry()
        .into_iter()
        .find(|h| h.action == action.as_str())
        .expect("every protected action is registered")
}

pub fn ensure_defaults(db: &Connection) -> rusqlite::Result<()> {
    for (id, kind, status, metadata) in [
        (
            "benchmark-data",
            "dataset",
            "active",
            r#"{"classification":"internal","records":3}"#,
        ),
        (
            "restricted-ip",
            "dataset",
            "restricted",
            r#"{"classification":"restricted","records":1}"#,
        ),
        (
            "model-release",
            "model",
            "candidate",
            r#"{"version":"local-candidate"}"#,
        ),
        (
            "release-local",
            "release",
            "candidate",
            r#"{"channel":"local"}"#,
        ),
        (
            "evidence-ledger",
            "evidence",
            "active",
            r#"{"format":"linked-sha256"}"#,
        ),
    ] {
        db.execute("insert or ignore into governed_object(id,workspace_id,kind,status,content_digest,metadata,updated_at) values(?1,'siddham-core-rd',?2,?3,?4,?5,datetime('now'))",params![id,kind,status,digest(metadata.as_bytes()),metadata])?;
    }
    Ok(())
}

pub fn prepare(db: &Connection, request: &OperationRequest) -> Result<HandlerMetadata, String> {
    let meta = for_action(&request.action);
    if !meta.available {
        return Err(format!("Handler {} is explicitly unavailable", meta.id));
    }
    let bytes = serde_json::to_vec(request)
        .map_err(|_| "Execution input could not be encoded".to_string())?;
    if bytes.len() > meta.max_input_bytes as usize {
        return Err("Execution input exceeds the handler limit".into());
    }
    validate_operation(request.operation.as_ref())?;
    validate_resource(db, request)?;
    db.execute("insert or ignore into execution_control(request_id,deadline_at,max_input_bytes,created_at) values(?1,datetime('now',?2),?3,datetime('now'))",params![request.request_id,format!("+{DEADLINE_SECONDS} seconds"),meta.max_input_bytes]).map_err(|_|"Execution controls could not be established".to_string())?;
    let cancelled: bool = db
        .query_row(
            "select cancelled_at is not null from execution_control where request_id=?1",
            [&request.request_id],
            |r| r.get(0),
        )
        .map_err(|_| "Execution cancellation state unavailable".to_string())?;
    if cancelled {
        return Err("Execution was cancelled before dispatch".into());
    }
    Ok(meta)
}

fn validate_resource(db: &Connection, request: &OperationRequest) -> Result<(), String> {
    let kind = match request.action {
        ProtectedAction::DatasetRead | ProtectedAction::DatasetExport => Some("dataset"),
        ProtectedAction::ModelPromote => Some("model"),
        ProtectedAction::ReleaseApprove => Some("release"),
        _ => None,
    };
    if let Some(kind) = kind {
        let exists:bool=db.query_row("select exists(select 1 from governed_object where id=?1 and workspace_id=?2 and kind=?3)",params![request.resource,request.workspace,kind],|r|r.get(0)).map_err(|_|"Governed resource validation unavailable".to_string())?;
        if !exists {
            return Err("Governed resource not found in this workspace".into());
        }
    }
    Ok(())
}

pub fn execute(
    db: &Connection,
    request: &OperationRequest,
    operation_id: &str,
    meta: &HandlerMetadata,
) -> Result<ExecutionResult, String> {
    db.execute("insert into handler_execution(operation_id,request_id,handler_id,target,status,started_at) values(?1,?2,?3,?4,'started',datetime('now'))",params![operation_id,request.request_id,meta.id,meta.target]).map_err(|_|"Handler execution is not idempotently claimable".to_string())?;
    let started = Instant::now();
    let input = serde_json::to_vec(request)
        .map_err(|_| "Execution input could not be encoded".to_string())?;
    let result=match request.action{
        ProtectedAction::RuntimeExecute=>maataa_runtime::execute_contract_operation(&request.request_id,operation_id,request.operation.as_ref().ok_or_else(||"Runtime operation payload is required".to_string())?),
        ProtectedAction::WorkspaceView=>query_one(db,"select json_object('id',id,'organizationId',organization_id,'displayName',display_name,'status',status) from workspace where id=?1",&request.workspace),
        ProtectedAction::DatasetRead=>query_object(db,request,"dataset",false),
        ProtectedAction::DatasetExport=>query_object(db,request,"dataset",true),
        ProtectedAction::ModelPromote=>transition(db,request,"model","promoted"),
        ProtectedAction::ReleaseApprove=>transition(db,request,"release","approved"),
        ProtectedAction::EvidenceExport=>evidence_summary(db,request),
        _=>Err(format!("Handler {} is explicitly unavailable",meta.id)),
    }?;
    let result = if request.action == ProtectedAction::RuntimeExecute {
        result
    } else {
        let output = result.output;
        let output_bytes = serde_json::to_vec(&output)
            .map_err(|_| "Execution output could not be encoded".to_string())?;
        ExecutionResult {
            schema_version: SCHEMA_VERSION.into(),
            operation_id: operation_id.into(),
            request_id: request.request_id.clone(),
            runtime_version: env!("CARGO_PKG_VERSION").into(),
            execution_mode: ExecutionMode::SoftwareNative,
            status: ExecutionStatus::Succeeded,
            input_digest: digest(&input),
            output_digest: digest(&output_bytes),
            output,
            duration_micros: started.elapsed().as_micros().try_into().unwrap_or(u64::MAX),
        }
    };
    if started.elapsed().as_secs() > u64::from(DEADLINE_SECONDS) {
        db.execute("update handler_execution set status='timed_out',completed_at=datetime('now'),error='deadline exceeded' where operation_id=?1",[operation_id]).ok();
        return Err("Handler deadline exceeded".into());
    }
    db.execute("update handler_execution set status='succeeded',completed_at=datetime('now') where operation_id=?1",[operation_id]).map_err(|_|"Execution status could not be finalized".to_string())?;
    Ok(result)
}

pub fn cancel(db: &Connection, request_id: &str) -> Result<bool, String> {
    Ok(db.execute("update execution_control set cancelled_at=datetime('now') where request_id=?1 and cancelled_at is null",[request_id]).map_err(|_|"Execution could not be cancelled".to_string())?==1)
}

fn validate_operation(operation: Option<&RuntimeOperation>) -> Result<(), String> {
    match operation {
        Some(RuntimeOperation::TokenizeBrahmi { text }) if text.len() > 4096 => {
            Err("Brahmi input exceeds 4096 bytes".into())
        }
        Some(RuntimeOperation::EvaluateSandhi { left, right })
            if left.len() > 256 || right.len() > 256 =>
        {
            Err("Sandhi term exceeds 256 bytes".into())
        }
        Some(RuntimeOperation::LookupSutra { sutra_id }) if sutra_id.len() > 32 => {
            Err("Sutra ID exceeds 32 bytes".into())
        }
        _ => Ok(()),
    }
}
fn query_one(db: &Connection, sql: &str, id: &str) -> Result<ExecutionResult, String> {
    let value: String = db
        .query_row(sql, [id], |r| r.get(0))
        .map_err(|_| "Governed object not found".to_string())?;
    placeholder(
        serde_json::from_str(&value)
            .map_err(|_| "Governed object metadata is invalid".to_string())?,
    )
}
fn query_object(
    db: &Connection,
    request: &OperationRequest,
    kind: &str,
    export: bool,
) -> Result<ExecutionResult, String> {
    let value:String=db.query_row("select json_object('id',id,'kind',kind,'status',status,'contentDigest',content_digest,'metadata',json(metadata)) from governed_object where id=?1 and workspace_id=?2 and kind=?3",params![request.resource,request.workspace,kind],|r|r.get(0)).map_err(|_|"Governed object not found in this workspace".to_string())?;
    let mut output: serde_json::Value = serde_json::from_str(&value)
        .map_err(|_| "Governed object metadata is invalid".to_string())?;
    if export {
        output["exportType"] = json!("manifest-only");
    }
    placeholder(output)
}
fn transition(
    db: &Connection,
    request: &OperationRequest,
    kind: &str,
    status: &str,
) -> Result<ExecutionResult, String> {
    if db.execute("update governed_object set status=?1,updated_at=datetime('now') where id=?2 and workspace_id=?3 and kind=?4",params![status,request.resource,request.workspace,kind]).map_err(|_|"Governed state transition failed".to_string())?!=1{return Err("Governed object not found in this workspace".into());}
    placeholder(json!({"id":request.resource,"kind":kind,"status":status}))
}
fn evidence_summary(
    db: &Connection,
    _request: &OperationRequest,
) -> Result<ExecutionResult, String> {
    let(count,latest):(u64,Option<String>)=db.query_row("select count(*),(select event_hash from audit_event order by seq desc limit 1) from audit_event",[],|r|Ok((r.get(0)?,r.get(1)?))).map_err(|_|"Evidence summary unavailable".to_string())?;
    placeholder(
        json!({"format":"linked-sha256-summary","eventCount":count,"latestEventHash":latest}),
    )
}
fn placeholder(output: serde_json::Value) -> Result<ExecutionResult, String> {
    Ok(ExecutionResult {
        schema_version: String::new(),
        operation_id: String::new(),
        request_id: String::new(),
        runtime_version: String::new(),
        execution_mode: ExecutionMode::SoftwareNative,
        status: ExecutionStatus::Succeeded,
        input_digest: String::new(),
        output_digest: String::new(),
        output,
        duration_micros: 0,
    })
}
fn digest(bytes: &[u8]) -> String {
    hex::encode(Sha256::digest(bytes))
}

#[cfg(test)]
mod tests {
    use super::*;
    use siddham_contracts::{AssuranceLevel, SCHEMA_VERSION};
    fn db() -> Connection {
        let mut db = crate::storage::memory().unwrap();
        let session = crate::identity::ensure_local_bootstrap(&mut db).unwrap();
        crate::policy::ensure_default(&db).unwrap();
        ensure_defaults(&db).unwrap();
        db.execute("insert into authority_request(request_id,session_id,request_hash,created_at,expires_at) values('req-handler',?1,'test',datetime('now'),datetime('now','+1 hour'))",[session]).unwrap();
        db
    }
    fn request(action: ProtectedAction, resource: &str) -> OperationRequest {
        OperationRequest {
            schema_version: SCHEMA_VERSION.into(),
            request_id: "req-handler".into(),
            principal: "release-authority".into(),
            action,
            resource: resource.into(),
            workspace: "siddham-core-rd".into(),
            assurance: AssuranceLevel::AAL3,
            operation: None,
        }
    }
    #[test]
    fn every_action_has_registry_metadata() {
        for action in [
            ProtectedAction::WorkspaceView,
            ProtectedAction::RuntimeExecute,
            ProtectedAction::DatasetRead,
            ProtectedAction::DatasetExport,
            ProtectedAction::ModelPromote,
            ProtectedAction::AgentDelegate,
            ProtectedAction::PolicyEdit,
            ProtectedAction::HardwareProgram,
            ProtectedAction::ReleaseApprove,
            ProtectedAction::EvidenceExport,
        ] {
            assert_eq!(for_action(&action).action, action.as_str())
        }
    }
    #[test]
    fn dataset_export_is_real_but_manifest_only() {
        let db = db();
        let req = request(ProtectedAction::DatasetExport, "restricted-ip");
        let meta = prepare(&db, &req).unwrap();
        let result = execute(&db, &req, "op-export", &meta).unwrap();
        assert_eq!(result.output["exportType"], "manifest-only")
    }
    #[test]
    fn unavailable_hardware_fails_before_dispatch() {
        let db = db();
        assert!(prepare(&db, &request(ProtectedAction::HardwareProgram, "device")).is_err())
    }
}
