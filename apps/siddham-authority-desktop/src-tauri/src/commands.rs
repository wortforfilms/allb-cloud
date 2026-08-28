use crate::{
    domain::{
        Effect, EvidenceEvent, GovernedOperationResult, OperationRequest, ProtectedAction,
        RuntimeCapability, SystemStatus,
    },
    evidence,
    policy::PolicyEngine,
    Runtime,
};
use rusqlite::Connection;
use tauri::State;
use uuid::Uuid;

#[tauri::command]
pub fn execute_governed(
    request: OperationRequest,
    state: State<Runtime>,
) -> Result<GovernedOperationResult, String> {
    let mut db = state
        .db
        .lock()
        .map_err(|_| "Database lock unavailable".to_string())?;
    execute_governed_local(&state.policy, &mut db, request)
}

fn execute_governed_local(
    policy: &PolicyEngine,
    db: &mut Connection,
    request: OperationRequest,
) -> Result<GovernedOperationResult, String> {
    let decision = policy.evaluate(&request);
    let authorization = evidence::append_authorization(db, &request, &decision)
        .map_err(|_| "Authorization evidence could not be recorded".to_string())?;
    if decision.effect != Effect::Permit {
        return Ok(GovernedOperationResult {
            authorization,
            execution: None,
            execution_evidence: None,
        });
    }
    if request.action != ProtectedAction::RuntimeExecute {
        return Ok(GovernedOperationResult {
            authorization,
            execution: None,
            execution_evidence: None,
        });
    }
    let operation = request
        .operation
        .as_ref()
        .ok_or_else(|| "Runtime operation payload is required".to_string())?;
    let operation_id = format!(
        "OP-{}",
        &Uuid::new_v4().simple().to_string()[..8].to_uppercase()
    );
    let execution =
        maataa_runtime::execute_contract_operation(&request.request_id, &operation_id, operation)
            .map_err(|_| "Local MAATAA operation failed".to_string())?;
    let execution_evidence = evidence::append_execution(db, &authorization, &execution)
        .map_err(|_| "Execution evidence could not be recorded".to_string())?;
    Ok(GovernedOperationResult {
        authorization,
        execution: Some(execution),
        execution_evidence: Some(execution_evidence),
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::AssuranceLevel;
    use siddham_contracts::{RuntimeOperation, SCHEMA_VERSION};

    fn request(action: ProtectedAction) -> OperationRequest {
        OperationRequest {
            schema_version: SCHEMA_VERSION.into(),
            request_id: "REQ-command".into(),
            principal: "Release Authority".into(),
            action: action.clone(),
            resource: "Core".into(),
            workspace: "Core".into(),
            assurance: AssuranceLevel::AAL3,
            operation: (action == ProtectedAction::RuntimeExecute).then(|| {
                RuntimeOperation::TokenizeBrahmi {
                    text: "𑀅".into()
                }
            }),
        }
    }

    #[test]
    fn permitted_operation_executes_and_links_evidence() {
        let mut db = crate::storage::memory().unwrap();
        let result = execute_governed_local(
            &PolicyEngine::default(),
            &mut db,
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
        let mut db = crate::storage::memory().unwrap();
        let result = execute_governed_local(
            &PolicyEngine::default(),
            &mut db,
            request(ProtectedAction::HardwareProgram),
        )
        .unwrap();
        assert_eq!(result.authorization.decision, Effect::Deny);
        assert!(result.execution.is_none());
        assert!(result.execution_evidence.is_none());
        assert!(evidence::verify(&db).unwrap());
    }
}

#[tauri::command]
pub fn runtime_capabilities() -> Vec<RuntimeCapability> {
    maataa_runtime::runtime_capabilities()
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
        policy_version: state.policy.version().into(),
        evidence_chain_valid: evidence::verify(&db)
            .map_err(|_| "Evidence chain could not be verified".to_string())?,
        sync_mode: "offline_outbox",
        capabilities: maataa_runtime::runtime_capabilities(),
    })
}
