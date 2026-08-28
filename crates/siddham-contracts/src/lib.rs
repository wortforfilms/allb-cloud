use serde::{Deserialize, Serialize};

pub const SCHEMA_VERSION: &str = "1.0.0";

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
pub enum AssuranceLevel {
    AAL2,
    AAL3,
    #[serde(rename = "mTLS")]
    MutualTls,
    #[serde(rename = "Scoped capability")]
    ScopedCapability,
}

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
pub enum Effect {
    Permit,
    Deny,
    RequireApproval,
    RequireStepUpAuthentication,
}

impl Effect {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Permit => "Permit",
            Self::Deny => "Deny",
            Self::RequireApproval => "RequireApproval",
            Self::RequireStepUpAuthentication => "RequireStepUpAuthentication",
        }
    }
}

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
pub enum ProtectedAction {
    #[serde(rename = "workspace:view")]
    WorkspaceView,
    #[serde(rename = "runtime:execute")]
    RuntimeExecute,
    #[serde(rename = "dataset:read")]
    DatasetRead,
    #[serde(rename = "dataset:export")]
    DatasetExport,
    #[serde(rename = "model:promote")]
    ModelPromote,
    #[serde(rename = "agent:delegate")]
    AgentDelegate,
    #[serde(rename = "policy:edit")]
    PolicyEdit,
    #[serde(rename = "hardware:program")]
    HardwareProgram,
    #[serde(rename = "release:approve")]
    ReleaseApprove,
    #[serde(rename = "evidence:export")]
    EvidenceExport,
}

impl ProtectedAction {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::WorkspaceView => "workspace:view",
            Self::RuntimeExecute => "runtime:execute",
            Self::DatasetRead => "dataset:read",
            Self::DatasetExport => "dataset:export",
            Self::ModelPromote => "model:promote",
            Self::AgentDelegate => "agent:delegate",
            Self::PolicyEdit => "policy:edit",
            Self::HardwareProgram => "hardware:program",
            Self::ReleaseApprove => "release:approve",
            Self::EvidenceExport => "evidence:export",
        }
    }
}

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq)]
#[serde(tag = "kind", rename_all = "camelCase", deny_unknown_fields)]
pub enum RuntimeOperation {
    TokenizeBrahmi { text: String },
    EvaluateSandhi { left: String, right: String },
    LookupSutra { sutra_id: String },
}

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct OperationRequest {
    pub schema_version: String,
    pub request_id: String,
    pub principal: String,
    pub action: ProtectedAction,
    pub resource: String,
    pub workspace: String,
    pub assurance: AssuranceLevel,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub operation: Option<RuntimeOperation>,
}

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
pub struct AuthorizationDecision {
    pub effect: Effect,
    pub reasons: Vec<String>,
    pub policy_version: String,
    pub policy_digest: String,
    pub request_hash: String,
}

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
pub enum ExecutionMode {
    SoftwareNative,
    SoftwareWasm,
    SiddhamNpu,
}

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
pub enum ExecutionStatus {
    Succeeded,
    Failed,
    NotExecuted,
}

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
pub struct RuntimeCapability {
    pub id: String,
    pub available: bool,
    pub mode: ExecutionMode,
    pub detail: String,
}

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq)]
pub struct ExecutionResult {
    pub schema_version: String,
    pub operation_id: String,
    pub request_id: String,
    pub runtime_version: String,
    pub execution_mode: ExecutionMode,
    pub status: ExecutionStatus,
    pub input_digest: String,
    pub output_digest: String,
    pub output: serde_json::Value,
    pub duration_micros: u64,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct EvidenceEvent {
    pub id: String,
    pub request_id: String,
    pub principal: String,
    pub action: ProtectedAction,
    pub resource: String,
    pub workspace: String,
    pub assurance: AssuranceLevel,
    pub decision: Effect,
    pub reasons: Vec<String>,
    pub policy_version: String,
    pub policy_digest: String,
    pub request_hash: String,
    pub event_hash: String,
    pub previous_event_hash: Option<String>,
    pub schema_version: u32,
    pub created_at: String,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct ExecutionEvidence {
    pub id: String,
    pub authorization_event_id: String,
    pub request_id: String,
    pub operation_id: String,
    pub status: ExecutionStatus,
    pub execution_mode: ExecutionMode,
    pub input_digest: String,
    pub output_digest: String,
    pub event_hash: String,
    pub created_at: String,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct GovernedOperationResult {
    pub authorization: EvidenceEvent,
    pub execution: Option<ExecutionResult>,
    pub execution_evidence: Option<ExecutionEvidence>,
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn valid_fixture_matches_contract() {
        let fixture = include_str!("../../../contracts/fixtures/valid-runtime-execute.json");
        let request: OperationRequest = serde_json::from_str(fixture).unwrap();
        assert_eq!(request.action, ProtectedAction::RuntimeExecute);
        assert!(matches!(
            request.operation,
            Some(RuntimeOperation::TokenizeBrahmi { .. })
        ));
    }
    #[test]
    fn unknown_action_fails_closed() {
        let fixture = include_str!("../../../contracts/fixtures/invalid-unknown-action.json");
        assert!(serde_json::from_str::<OperationRequest>(fixture).is_err());
    }
}
