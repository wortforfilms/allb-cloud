use crate::domain::{
    AssuranceLevel, AuthorizationDecision, Effect, OperationRequest, ProtectedAction,
};
use sha2::{Digest, Sha256};
use siddham_contracts::SCHEMA_VERSION;

const POLICY_VERSION: &str = "workspace-core@24.09";
const POLICY_RULES: &str = "release-authority:workspace:view,runtime:execute;rtl-engineer:workspace:view,runtime:execute;ai-agent:workspace:view,runtime:execute;investor-viewer:workspace:view;all-other-actions:deny-unavailable";

pub struct PolicyEngine {
    version: String,
    digest: String,
}

impl Default for PolicyEngine {
    fn default() -> Self {
        Self {
            version: POLICY_VERSION.into(),
            digest: hex::encode(Sha256::digest(POLICY_RULES.as_bytes())),
        }
    }
}

impl PolicyEngine {
    pub fn version(&self) -> &str {
        &self.version
    }

    pub fn evaluate(&self, request: &OperationRequest) -> AuthorizationDecision {
        let malformed = request.schema_version != SCHEMA_VERSION
            || [
                &request.request_id,
                &request.principal,
                &request.resource,
                &request.workspace,
            ]
            .iter()
            .any(|value| value.trim().is_empty());
        let operation_shape_invalid = match request.action {
            ProtectedAction::RuntimeExecute => request.operation.is_none(),
            _ => request.operation.is_some(),
        };
        let allowed = match request.principal.as_str() {
            "Release Authority" => matches!(
                request.action,
                ProtectedAction::WorkspaceView | ProtectedAction::RuntimeExecute
            ),
            "RTL Engineer" | "AI Agent" => matches!(
                request.action,
                ProtectedAction::WorkspaceView | ProtectedAction::RuntimeExecute
            ),
            "Investor Viewer" => request.action == ProtectedAction::WorkspaceView,
            _ => false,
        };
        let (effect, reasons) = if malformed {
            (
                Effect::Deny,
                vec![
                    "Malformed or unsupported contract version",
                    "Default-deny policy applied",
                ],
            )
        } else if operation_shape_invalid {
            (
                Effect::Deny,
                vec![
                    "Operation payload does not match the protected action",
                    "Default-deny policy applied",
                ],
            )
        } else if request.action == ProtectedAction::DatasetExport
            && request.resource == "Restricted IP"
        {
            (
                Effect::RequireApproval,
                vec![
                    "Restricted IP export requires Release Authority",
                    "Approval workflow is not yet implemented",
                ],
            )
        } else if request.action == ProtectedAction::ReleaseApprove
            && request.assurance != AssuranceLevel::AAL3
        {
            (
                Effect::RequireStepUpAuthentication,
                vec!["Release approval requires phishing-resistant AAL3"],
            )
        } else if !allowed {
            (
                Effect::Deny,
                vec![
                    "No implemented handler and matching principal authority",
                    "Default-deny policy applied",
                ],
            )
        } else {
            (
                Effect::Permit,
                vec!["Explicit principal, action, contract, and handler rule matched"],
            )
        };
        AuthorizationDecision {
            effect,
            reasons: reasons.into_iter().map(String::from).collect(),
            policy_version: self.version.clone(),
            policy_digest: self.digest.clone(),
            request_hash: hash_request(request),
        }
    }
}

pub fn hash_request(request: &OperationRequest) -> String {
    let canonical = serde_json::to_string(request).expect("operation request serializes");
    hex::encode(Sha256::digest(canonical.as_bytes()))
}

#[cfg(test)]
mod tests {
    use super::*;
    use siddham_contracts::RuntimeOperation;

    fn request(principal: &str, action: ProtectedAction) -> OperationRequest {
        OperationRequest {
            schema_version: SCHEMA_VERSION.into(),
            request_id: "REQ-test".into(),
            principal: principal.into(),
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
    fn runtime_execute_is_explicitly_permitted() {
        assert_eq!(
            PolicyEngine::default()
                .evaluate(&request(
                    "Release Authority",
                    ProtectedAction::RuntimeExecute
                ))
                .effect,
            Effect::Permit
        );
    }
    #[test]
    fn viewer_cannot_execute_runtime() {
        assert_eq!(
            PolicyEngine::default()
                .evaluate(&request("Investor Viewer", ProtectedAction::RuntimeExecute))
                .effect,
            Effect::Deny
        );
    }
    #[test]
    fn unavailable_protected_action_fails_closed() {
        for action in [
            ProtectedAction::DatasetRead,
            ProtectedAction::DatasetExport,
            ProtectedAction::ModelPromote,
            ProtectedAction::AgentDelegate,
            ProtectedAction::PolicyEdit,
            ProtectedAction::HardwareProgram,
            ProtectedAction::ReleaseApprove,
            ProtectedAction::EvidenceExport,
        ] {
            assert_ne!(
                PolicyEngine::default()
                    .evaluate(&request("Release Authority", action))
                    .effect,
                Effect::Permit
            );
        }
    }
    #[test]
    fn runtime_action_requires_operation_payload() {
        let mut value = request("Release Authority", ProtectedAction::RuntimeExecute);
        value.operation = None;
        assert_eq!(
            PolicyEngine::default().evaluate(&value).effect,
            Effect::Deny
        );
    }
    #[test]
    fn unknown_action_does_not_deserialize() {
        let fixture = include_str!("../../../../contracts/fixtures/invalid-unknown-action.json");
        assert!(serde_json::from_str::<OperationRequest>(fixture).is_err());
    }
}
