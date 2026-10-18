//! Policy record and lifecycle.
//!
//! STATUS: INTENTIONAL-HOLD — not exposed through Tauri commands.
//!
//! SECURITY CONSTRAINT: Lifecycle operations must derive the actor from an
//! authenticated session. Audit events must be attributed server-side, not
//! from caller-supplied strings.
//!
//! Tracked: `docs/PRODUCT_ROADMAP.md`, Phase 8 (Complete product UX).

use crate::domain::{
    AssuranceLevel, AuthorizationDecision, Effect, OperationRequest, ProtectedAction,
};
use rusqlite::{params, Connection, OptionalExtension};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use siddham_contracts::{is_compatible_schema_version, is_valid_contract_id};
use uuid::Uuid;

const DEFAULT_POLICY_ID: &str = "policy-workspace-core-24-09";
const DEFAULT_POLICY_VERSION: &str = "workspace-core@24.09";
const DEFAULT_POLICY: &str = r#"{"allow":{"ai-agent":["workspace:view","runtime:execute"],"investor-viewer":["workspace:view"],"release-authority":["workspace:view","runtime:execute","dataset:read","evidence:export"],"rtl-engineer":["workspace:view","runtime:execute","dataset:read"]},"approval":["dataset:export","model:promote","agent:delegate","policy:edit","release:approve"],"deny":["hardware:program"],"releaseAssurance":"AAL3"}"#;

#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct PolicyDocument {
    pub allow: std::collections::BTreeMap<String, Vec<String>>,
    pub approval: Vec<String>,
    pub deny: Vec<String>,
    pub release_assurance: String,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PolicyRecord {
    pub id: String,
    pub version: String,
    pub digest: String,
    pub state: String,
    pub created_by: String,
    pub created_at: String,
    pub activated_at: Option<String>,
    pub retired_at: Option<String>,
}

#[derive(Default)]
pub struct PolicyEngine;

pub fn ensure_default(db: &Connection) -> rusqlite::Result<()> {
    db.execute("insert or ignore into policy_bundle(id,version,document,digest,state,created_by,created_at,activated_at) values(?1,?2,?3,?4,'active','release-authority',datetime('now'),datetime('now'))", params![DEFAULT_POLICY_ID,DEFAULT_POLICY_VERSION,DEFAULT_POLICY,digest(DEFAULT_POLICY)])?;
    db.execute("insert into policy_lifecycle_event(id,policy_id,action,actor,details,created_at) select ?1,?2,'create','release-authority','default local policy',datetime('now') where not exists(select 1 from policy_lifecycle_event where policy_id=?2)", params![event_id(),DEFAULT_POLICY_ID])?;
    Ok(())
}

impl PolicyEngine {
    pub fn active_version(&self, db: &Connection) -> Result<String, String> {
        db.query_row("select version from policy_bundle where state='active' order by activated_at desc limit 1", [], |r| r.get(0)).optional().map_err(|_| "Policy authority unavailable".to_string())?.ok_or_else(|| "No active policy; default deny".to_string())
    }

    pub fn evaluate(
        &self,
        db: &Connection,
        request: &OperationRequest,
        role: &str,
    ) -> AuthorizationDecision {
        let loaded = db.query_row("select version,document,digest from policy_bundle where state='active' order by activated_at desc limit 1", [], |r| Ok((r.get::<_,String>(0)?,r.get::<_,String>(1)?,r.get::<_,String>(2)?))).optional().ok().flatten();
        let request_hash = hash_request(request);
        let Some((version, raw, policy_digest)) = loaded else {
            return make_decision(
                Effect::Deny,
                vec!["No active policy", "Default-deny policy applied"],
                "none",
                "",
                request_hash,
            );
        };
        let Ok(document) = serde_json::from_str::<PolicyDocument>(&raw) else {
            return make_decision(
                Effect::Deny,
                vec![
                    "Active policy document is invalid",
                    "Default-deny policy applied",
                ],
                &version,
                &policy_digest,
                request_hash,
            );
        };
        let action = request.action.as_str();
        let malformed = !is_compatible_schema_version(&request.schema_version)
            || [
                &request.request_id,
                &request.principal,
                &request.resource,
                &request.workspace,
            ]
            .iter()
            .any(|v| !is_valid_contract_id(v));
        let invalid_shape = match request.action {
            ProtectedAction::RuntimeExecute => request.operation.is_none(),
            _ => request.operation.is_some(),
        };
        let denied = document.deny.iter().any(|v| v == action);
        let approval = document.approval.iter().any(|v| v == action);
        let allowed = document
            .allow
            .get(role)
            .is_some_and(|values| values.iter().any(|v| v == action));
        let (effect, reasons) = if malformed {
            (
                Effect::Deny,
                vec![
                    "Malformed or unsupported contract version",
                    "Default-deny policy applied",
                ],
            )
        } else if invalid_shape {
            (
                Effect::Deny,
                vec![
                    "Operation payload does not match the protected action",
                    "Default-deny policy applied",
                ],
            )
        } else if denied {
            (
                Effect::Deny,
                vec!["Explicit deny rule matched", "Deny-overrides applied"],
            )
        } else if request.action == ProtectedAction::ReleaseApprove
            && request.assurance != AssuranceLevel::AAL3
        {
            (
                Effect::RequireStepUpAuthentication,
                vec!["Release approval requires phishing-resistant AAL3"],
            )
        } else if approval {
            (
                Effect::RequireApproval,
                vec![
                    "Durable approval is required",
                    "Phase 5 approval artifact is unavailable",
                ],
            )
        } else if allowed {
            (
                Effect::Permit,
                vec!["Active policy role and action rule matched"],
            )
        } else {
            (
                Effect::Deny,
                vec![
                    "No active allow rule matched",
                    "Default-deny policy applied",
                ],
            )
        };
        make_decision(effect, reasons, &version, &policy_digest, request_hash)
    }
}

#[allow(dead_code)] // INTENTIONAL-HOLD — see module doc
pub fn create_draft(
    db: &Connection,
    version: &str,
    document: &str,
    actor: &str,
) -> Result<PolicyRecord, String> {
    let _: PolicyDocument =
        serde_json::from_str(document).map_err(|_| "Policy document is invalid".to_string())?;
    if version.is_empty() || version.len() > 80 {
        return Err("Policy version is invalid".into());
    }
    let id = format!("policy-{}", Uuid::new_v4().simple());
    let policy_digest = digest(document);
    db.execute("insert into policy_bundle(id,version,document,digest,state,created_by,created_at) values(?1,?2,?3,?4,'draft',?5,datetime('now'))",params![id,version,document,policy_digest,actor]).map_err(|_|"Policy version already exists or could not be created".to_string())?;
    append_event(db, &id, "create", actor, "draft created")
        .map_err(|_| "Policy provenance could not be recorded".to_string())?;
    get(db, &id).map_err(|_| "Policy could not be loaded".to_string())
}

#[allow(dead_code)] // INTENTIONAL-HOLD — see module doc
pub fn simulate(
    db: &Connection,
    policy_id: &str,
    request: &OperationRequest,
    role: &str,
    actor: &str,
) -> Result<AuthorizationDecision, String> {
    let (version, raw, policy_digest): (String, String, String) = db
        .query_row(
            "select version,document,digest from policy_bundle where id=?1",
            [policy_id],
            |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)),
        )
        .map_err(|_| "Policy not found".to_string())?;
    let document: PolicyDocument =
        serde_json::from_str(&raw).map_err(|_| "Policy document is invalid".to_string())?;
    append_event(db, policy_id, "simulate", actor, &hash_request(request))
        .map_err(|_| "Simulation provenance could not be recorded".to_string())?;
    let allowed = document
        .allow
        .get(role)
        .is_some_and(|v| v.iter().any(|a| a == request.action.as_str()));
    Ok(make_decision(
        if allowed {
            Effect::Permit
        } else {
            Effect::Deny
        },
        vec!["Draft policy simulation; no activation or execution occurred"],
        &version,
        &policy_digest,
        hash_request(request),
    ))
}

#[allow(dead_code)] // INTENTIONAL-HOLD — see module doc
pub fn activate(db: &mut Connection, policy_id: &str, actor: &str) -> Result<(), String> {
    let tx = db
        .transaction()
        .map_err(|_| "Policy transaction unavailable".to_string())?;
    tx.execute(
        "update policy_bundle set state='retired',retired_at=datetime('now') where state='active'",
        [],
    )
    .map_err(|_| "Active policy could not be retired".to_string())?;
    if tx.execute("update policy_bundle set state='active',activated_at=datetime('now'),retired_at=null where id=?1 and state='draft'",[policy_id]).map_err(|_|"Policy could not be activated".to_string())? != 1 { return Err("Only a draft policy can be activated".into()); }
    append_event(&tx, policy_id, "activate", actor, "policy activated")
        .map_err(|_| "Activation provenance could not be recorded".to_string())?;
    tx.commit()
        .map_err(|_| "Policy activation could not be committed".to_string())
}

#[allow(dead_code)] // INTENTIONAL-HOLD — see module doc
pub fn retire(db: &mut Connection, policy_id: &str, actor: &str) -> Result<(), String> {
    let tx = db
        .transaction()
        .map_err(|_| "Policy transaction unavailable".to_string())?;
    if tx.execute("update policy_bundle set state='retired',retired_at=datetime('now') where id=?1 and state='active'",[policy_id]).map_err(|_|"Policy could not be retired".to_string())? != 1 {
        return Err("Only an active policy can be retired".into());
    }
    append_event(&tx, policy_id, "retire", actor, "policy retired")
        .map_err(|_| "Retirement provenance could not be recorded".to_string())?;
    tx.commit()
        .map_err(|_| "Policy retirement could not be committed".to_string())
}

fn append_event(
    db: &Connection,
    policy_id: &str,
    action: &str,
    actor: &str,
    details: &str,
) -> rusqlite::Result<()> {
    db.execute("insert into policy_lifecycle_event(id,policy_id,action,actor,details,created_at) values(?1,?2,?3,?4,?5,datetime('now'))",params![event_id(),policy_id,action,actor,details])?;
    Ok(())
}
fn get(db: &Connection, id: &str) -> rusqlite::Result<PolicyRecord> {
    db.query_row("select id,version,digest,state,created_by,created_at,activated_at,retired_at from policy_bundle where id=?1",[id],|r|Ok(PolicyRecord{id:r.get(0)?,version:r.get(1)?,digest:r.get(2)?,state:r.get(3)?,created_by:r.get(4)?,created_at:r.get(5)?,activated_at:r.get(6)?,retired_at:r.get(7)?}))
}
fn make_decision(
    effect: Effect,
    reasons: Vec<&str>,
    version: &str,
    policy_digest: &str,
    request_hash: String,
) -> AuthorizationDecision {
    AuthorizationDecision {
        effect,
        reasons: reasons.into_iter().map(String::from).collect(),
        policy_version: version.into(),
        policy_digest: policy_digest.into(),
        request_hash,
    }
}
fn digest(value: &str) -> String {
    hex::encode(Sha256::digest(value.as_bytes()))
}
fn event_id() -> String {
    format!("policy-event-{}", Uuid::new_v4().simple())
}
pub fn hash_request(request: &OperationRequest) -> String {
    digest(&serde_json::to_string(request).expect("operation request serializes"))
}

#[cfg(test)]
mod tests {
    use super::*;
    use siddham_contracts::{RuntimeOperation, SCHEMA_VERSION};
    fn database() -> Connection {
        let mut db = crate::storage::memory().unwrap();
        crate::identity::ensure_local_bootstrap(&mut db).unwrap();
        ensure_default(&db).unwrap();
        db
    }
    fn request(action: ProtectedAction) -> OperationRequest {
        OperationRequest {
            schema_version: SCHEMA_VERSION.into(),
            request_id: "req-test".into(),
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
    #[test]
    fn active_policy_permits_runtime() {
        let db = database();
        assert_eq!(
            PolicyEngine
                .evaluate(
                    &db,
                    &request(ProtectedAction::RuntimeExecute),
                    "release-authority"
                )
                .effect,
            Effect::Permit
        )
    }
    #[test]
    fn deny_overrides_and_all_actions_are_covered() {
        let db = database();
        for action in [
            ProtectedAction::WorkspaceView,
            ProtectedAction::DatasetRead,
            ProtectedAction::DatasetExport,
            ProtectedAction::ModelPromote,
            ProtectedAction::AgentDelegate,
            ProtectedAction::PolicyEdit,
            ProtectedAction::RuntimeExecute,
            ProtectedAction::HardwareProgram,
            ProtectedAction::ReleaseApprove,
            ProtectedAction::EvidenceExport,
        ] {
            assert!(!PolicyEngine
                .evaluate(&db, &request(action), "release-authority")
                .reasons
                .is_empty())
        }
        assert_eq!(
            PolicyEngine
                .evaluate(
                    &db,
                    &request(ProtectedAction::HardwareProgram),
                    "release-authority"
                )
                .effect,
            Effect::Deny
        )
    }
    #[test]
    fn draft_simulation_does_not_activate_policy() {
        let db = database();
        let draft = create_draft(&db, "test@1", DEFAULT_POLICY, "release-authority").unwrap();
        assert_eq!(
            simulate(
                &db,
                &draft.id,
                &request(ProtectedAction::RuntimeExecute),
                "release-authority",
                "release-authority"
            )
            .unwrap()
            .effect,
            Effect::Permit
        );
        assert_eq!(
            PolicyEngine.active_version(&db).unwrap(),
            DEFAULT_POLICY_VERSION
        )
    }
    #[test]
    fn activation_retires_previous_policy_with_provenance() {
        let mut db = database();
        let draft = create_draft(&db, "test@2", DEFAULT_POLICY, "release-authority").unwrap();
        activate(&mut db, &draft.id, "release-authority").unwrap();
        assert_eq!(PolicyEngine.active_version(&db).unwrap(), "test@2");
        let count: i64 = db
            .query_row(
                "select count(*) from policy_lifecycle_event where policy_id=?1",
                [draft.id],
                |r| r.get(0),
            )
            .unwrap();
        assert_eq!(count, 2)
    }
    #[test]
    fn retiring_the_active_policy_causes_default_deny() {
        let mut db = database();
        retire(&mut db, DEFAULT_POLICY_ID, "release-authority").unwrap();
        let result = PolicyEngine.evaluate(
            &db,
            &request(ProtectedAction::RuntimeExecute),
            "release-authority",
        );
        assert_eq!(result.effect, Effect::Deny);
        assert_eq!(result.policy_version, "none");
    }
}
