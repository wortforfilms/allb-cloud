pub use siddham_contracts::{
    AssuranceLevel, AuthorizationDecision, Effect, EvidenceEvent, ExecutionEvidence,
    GovernedOperationResult, OperationRequest, ProtectedAction, RuntimeCapability,
};

#[derive(Debug, serde::Serialize)]
pub struct SystemStatus {
    pub database: &'static str,
    pub policy_version: String,
    pub evidence_chain_valid: bool,
    pub sync_mode: &'static str,
    pub capabilities: Vec<RuntimeCapability>,
}
