use serde::{Deserialize, Serialize};

pub const SCHEMA_VERSION: &str = "1.1.0";
pub const SUPPORTED_SCHEMA_MAJOR: u64 = 1;
pub const MINIMUM_SCHEMA_MINOR: u64 = 0;
pub const MAXIMUM_SCHEMA_MINOR: u64 = 1;

pub fn is_compatible_schema_version(version: &str) -> bool {
    let parts: Vec<_> = version.split('.').collect();
    if parts.len() != 3 {
        return false;
    }
    let Ok(major) = parts[0].parse::<u64>() else {
        return false;
    };
    let Ok(minor) = parts[1].parse::<u64>() else {
        return false;
    };
    let Ok(_patch) = parts[2].parse::<u64>() else {
        return false;
    };
    major == SUPPORTED_SCHEMA_MAJOR
        && (MINIMUM_SCHEMA_MINOR..=MAXIMUM_SCHEMA_MINOR).contains(&minor)
}

pub fn is_valid_contract_id(value: &str) -> bool {
    let bytes = value.as_bytes();
    (3..=64).contains(&bytes.len())
        && bytes[0].is_ascii_lowercase()
        && bytes
            .iter()
            .all(|byte| byte.is_ascii_lowercase() || byte.is_ascii_digit() || *byte == b'-')
}

pub fn is_valid_sha256_digest(value: &str) -> bool {
    value.len() == 71
        && value.starts_with("sha256:")
        && value[7..]
            .bytes()
            .all(|byte| byte.is_ascii_hexdigit() && !byte.is_ascii_uppercase())
}

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

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
pub enum PrincipalKind {
    Human,
    Service,
    Device,
}
#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
pub enum PrincipalStatus {
    Active,
    Suspended,
    Revoked,
}
#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
pub enum WorkspaceStatus {
    Active,
    Suspended,
    Archived,
}
#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
pub enum ResourceKind {
    Dataset,
    Model,
    Agent,
    Policy,
    Hardware,
    Evidence,
    Release,
}
#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
pub enum ResourceStatus {
    Active,
    Quarantined,
    Archived,
}
#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
pub enum ApprovalStatus {
    Pending,
    Approved,
    Rejected,
    Expired,
    Cancelled,
}
#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
pub enum SyncStatus {
    Queued,
    Sent,
    Acknowledged,
    Rejected,
    Failed,
}
#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum ContractErrorCode {
    InvalidContract,
    UnsupportedVersion,
    Unauthorized,
    ApprovalRequired,
    ResourceNotFound,
    Conflict,
    RateLimited,
    DependencyUnavailable,
    InternalError,
}
#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
pub enum ReleaseStatus {
    Draft,
    Candidate,
    Approved,
    Published,
    Withdrawn,
}

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct Principal {
    pub schema_version: String,
    pub id: String,
    pub kind: PrincipalKind,
    pub display_name: String,
    pub status: PrincipalStatus,
}
#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct Workspace {
    pub schema_version: String,
    pub id: String,
    pub organization_id: String,
    pub display_name: String,
    pub status: WorkspaceStatus,
}
#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct Resource {
    pub schema_version: String,
    pub id: String,
    pub workspace_id: String,
    pub kind: ResourceKind,
    pub display_name: String,
    pub status: ResourceStatus,
    pub digest: Option<String>,
}
#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct Approval {
    pub schema_version: String,
    pub id: String,
    pub request_id: String,
    pub request_hash: String,
    pub status: ApprovalStatus,
    pub requested_by: String,
    pub decided_by: Option<String>,
    pub expires_at: String,
    pub decided_at: Option<String>,
}
#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct SyncEnvelope {
    pub schema_version: String,
    pub id: String,
    pub workspace_id: String,
    pub sequence: u64,
    pub payload_digest: String,
    pub status: SyncStatus,
    pub remote_receipt: Option<String>,
}
#[derive(Clone, Debug, Deserialize, Serialize, PartialEq)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct ContractError {
    pub schema_version: String,
    pub code: ContractErrorCode,
    pub message: String,
    pub request_id: Option<String>,
    pub retryable: bool,
    pub details: Option<serde_json::Value>,
}
#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct ReleaseRecord {
    pub schema_version: String,
    pub id: String,
    pub workspace_id: String,
    pub artifact_digest: String,
    pub status: ReleaseStatus,
    pub approved_by: Option<String>,
    pub created_at: String,
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
    #[test]
    fn schema_compatibility_accepts_supported_minors_and_rejects_unknown_major() {
        assert!(is_compatible_schema_version("1.0.9"));
        assert!(is_compatible_schema_version(SCHEMA_VERSION));
        assert!(!is_compatible_schema_version("2.0.0"));
        assert!(!is_compatible_schema_version("1.2.0"));
        assert!(!is_compatible_schema_version("invalid"));
        assert!(is_valid_contract_id("workspace-core"));
        assert!(!is_valid_contract_id("Workspace Core"));
        assert!(is_valid_sha256_digest(&format!(
            "sha256:{}",
            "a".repeat(64)
        )));
        assert!(!is_valid_sha256_digest("sha256:abc"));
    }
}
