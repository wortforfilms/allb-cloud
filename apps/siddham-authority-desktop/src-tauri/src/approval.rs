use crate::{domain::OperationRequest, identity};
use rusqlite::{params, Connection, OptionalExtension};
use serde::Serialize;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ApprovalView {
    pub id: String,
    pub request_id: String,
    pub request_hash: String,
    pub workspace_id: String,
    pub action: String,
    pub resource: String,
    pub requested_by: String,
    pub status: String,
    pub required_quorum: u32,
    pub approvals: u32,
    pub expires_at: String,
    pub created_at: String,
}

pub fn request(
    db: &Connection,
    operation: &OperationRequest,
    request_hash: &str,
    quorum: u32,
) -> Result<ApprovalView, String> {
    if quorum == 0 || quorum > 5 {
        return Err("Approval quorum must be between one and five".into());
    }
    let claimed: Option<String> = db
        .query_row(
            "select request_hash from authority_request where request_id=?1",
            [&operation.request_id],
            |r| r.get(0),
        )
        .optional()
        .map_err(|_| "Request claim unavailable".to_string())?;
    if claimed.as_deref() != Some(request_hash) {
        return Err("Approval must bind to the exact claimed request hash".into());
    }
    let id = format!("approval-{}", Uuid::new_v4().simple());
    db.execute("insert into approval_request(id,request_id,request_hash,workspace_id,action,resource,requested_by,status,required_quorum,expires_at,created_at) values(?1,?2,?3,?4,?5,?6,?7,'pending',?8,datetime('now','+1 hour'),datetime('now'))",params![id,operation.request_id,request_hash,operation.workspace,operation.action.as_str(),operation.resource,operation.principal,quorum]).map_err(|_|"Approval already exists for this request".to_string())?;
    event(
        db,
        &id,
        "approval",
        "request",
        &operation.principal,
        "approval requested",
    )
    .map_err(|_| "Approval provenance could not be recorded".to_string())?;
    get(db, &id)
}

pub fn decide(
    db: &Connection,
    session_id: &str,
    approval_id: &str,
    decision: &str,
    comment: &str,
) -> Result<ApprovalView, String> {
    if !matches!(decision, "approve" | "reject") {
        return Err("Approval decision is invalid".into());
    }
    refresh_expiry(db, approval_id)?;
    let (workspace,maker,status,quorum):(String,String,String,u32)=db.query_row("select workspace_id,requested_by,status,required_quorum from approval_request where id=?1",[approval_id],|r|Ok((r.get(0)?,r.get(1)?,r.get(2)?,r.get(3)?))).map_err(|_|"Approval not found".to_string())?;
    if status != "pending" {
        return Err("Approval is no longer pending".into());
    }
    let context = identity::authenticate(db, session_id, &workspace)?;
    if context.principal_id == maker {
        return Err("Maker cannot approve their own request".into());
    }
    if !matches!(
        context.role.as_str(),
        "security-reviewer" | "release-checker"
    ) {
        return Err("Principal is not an eligible approver".into());
    }
    db.execute("insert into approval_vote(id,approval_id,approver,decision,comment,created_at) values(?1,?2,?3,?4,?5,datetime('now'))",params![format!("vote-{}",Uuid::new_v4().simple()),approval_id,context.principal_id,decision,comment]).map_err(|_|"Approver has already decided this request".to_string())?;
    event(
        db,
        approval_id,
        "approval",
        decision,
        &context.principal_id,
        comment,
    )
    .map_err(|_| "Approval provenance could not be recorded".to_string())?;
    if decision == "reject" {
        db.execute(
            "update approval_request set status='rejected',decided_at=datetime('now') where id=?1",
            [approval_id],
        )
        .map_err(|_| "Approval could not be rejected".to_string())?;
    } else {
        let count: u32 = db
            .query_row(
                "select count(*) from approval_vote where approval_id=?1 and decision='approve'",
                [approval_id],
                |r| r.get(0),
            )
            .map_err(|_| "Approval quorum unavailable".to_string())?;
        if count >= quorum {
            db.execute("update approval_request set status='approved',decided_at=datetime('now') where id=?1",[approval_id]).map_err(|_|"Approval could not be finalized".to_string())?;
        }
    }
    get(db, approval_id)
}

pub fn cancel(db: &Connection, approval_id: &str, actor: &str) -> Result<ApprovalView, String> {
    let changed=db.execute("update approval_request set status='cancelled',cancelled_at=datetime('now') where id=?1 and requested_by=?2 and status='pending'",params![approval_id,actor]).map_err(|_|"Approval could not be cancelled".to_string())?;
    if changed != 1 {
        return Err("Only the maker can cancel a pending approval".into());
    }
    event(
        db,
        approval_id,
        "approval",
        "cancel",
        actor,
        "cancelled by maker",
    )
    .map_err(|_| "Cancellation provenance could not be recorded".to_string())?;
    get(db, approval_id)
}

pub fn consume(
    db: &mut Connection,
    approval_id: &str,
    request_id: &str,
    request_hash: &str,
) -> Result<(), String> {
    refresh_expiry(db, approval_id)?;
    let tx = db
        .transaction()
        .map_err(|_| "Approval transaction unavailable".to_string())?;
    let valid:bool=tx.query_row("select exists(select 1 from approval_request where id=?1 and request_id=?2 and request_hash=?3 and status='approved' and datetime(expires_at)>datetime('now'))",params![approval_id,request_id,request_hash],|r|r.get(0)).map_err(|_|"Approval validation unavailable".to_string())?;
    if !valid {
        return Err("Approval is not valid for this exact request".into());
    }
    tx.execute("insert into approval_consumption(approval_id,request_id,request_hash,consumed_at) values(?1,?2,?3,datetime('now'))",params![approval_id,request_id,request_hash]).map_err(|_|"Approval has already been consumed".to_string())?;
    tx.execute(
        "update approval_request set status='consumed' where id=?1 and status='approved'",
        [approval_id],
    )
    .map_err(|_| "Approval could not be consumed".to_string())?;
    tx.commit()
        .map_err(|_| "Approval consumption could not be committed".to_string())
}

pub fn list(db: &Connection, workspace: &str) -> Result<Vec<ApprovalView>, String> {
    let mut stmt = db
        .prepare("select id from approval_request where workspace_id=?1 order by created_at desc")
        .map_err(|_| "Approval inbox unavailable".to_string())?;
    let ids: Vec<String> = stmt
        .query_map([workspace], |r| r.get(0))
        .map_err(|_| "Approval inbox unavailable".to_string())?
        .collect::<rusqlite::Result<_>>()
        .map_err(|_| "Approval inbox unavailable".to_string())?;
    ids.into_iter().map(|id| get(db, &id)).collect()
}

pub fn grant_delegation(
    db: &Connection,
    grantor: &str,
    delegate: &str,
    workspace: &str,
    action: &str,
    hours: u32,
) -> Result<String, String> {
    if grantor == delegate || hours == 0 || hours > 24 {
        return Err("Delegation scope or duration is invalid".into());
    }
    let both:i64=db.query_row("select count(*) from workspace_membership where workspace_id=?1 and principal_id in (?2,?3) and status='active'",params![workspace,grantor,delegate],|r|r.get(0)).map_err(|_|"Delegation membership unavailable".to_string())?;
    if both != 2 {
        return Err("Both principals must be active workspace members".into());
    }
    let id = format!("delegation-{}", Uuid::new_v4().simple());
    db.execute("insert into authority_delegation(id,grantor,delegate,workspace_id,action,status,expires_at,created_at) values(?1,?2,?3,?4,?5,'active',datetime('now',?6),datetime('now'))",params![id,grantor,delegate,workspace,action,format!("+{hours} hours")]).map_err(|_|"Delegation could not be created".to_string())?;
    event(
        db,
        &id,
        "delegation",
        "grant",
        grantor,
        "scoped delegation created",
    )
    .map_err(|_| "Delegation provenance could not be recorded".to_string())?;
    Ok(id)
}

pub fn delegation_valid(
    db: &Connection,
    id: &str,
    delegate: &str,
    workspace: &str,
    action: &str,
) -> Result<bool, String> {
    db.query_row("select exists(select 1 from authority_delegation where id=?1 and delegate=?2 and workspace_id=?3 and action=?4 and status='active' and datetime(expires_at)>datetime('now'))",params![id,delegate,workspace,action],|r|r.get(0)).map_err(|_|"Delegation validation unavailable".to_string())
}
pub fn revoke_delegation(db: &Connection, id: &str, grantor: &str) -> Result<(), String> {
    if db.execute("update authority_delegation set status='revoked',revoked_at=datetime('now') where id=?1 and grantor=?2 and status='active'",params![id,grantor]).map_err(|_|"Delegation could not be revoked".to_string())?!=1{return Err("Active delegation not found".into());}
    event(
        db,
        id,
        "delegation",
        "revoke",
        grantor,
        "delegation revoked",
    )
    .map_err(|_| "Delegation provenance could not be recorded".to_string())
}

pub fn request_emergency(
    db: &Connection,
    principal: &str,
    workspace: &str,
    action: &str,
    justification: &str,
) -> Result<String, String> {
    if justification.trim().len() < 12 {
        return Err("Emergency justification is too short".into());
    }
    let id = format!("emergency-{}", Uuid::new_v4().simple());
    db.execute("insert into emergency_access(id,principal_id,workspace_id,action,justification,status,expires_at,created_at) values(?1,?2,?3,?4,?5,'pending',datetime('now','+1 hour'),datetime('now'))",params![id,principal,workspace,action,justification]).map_err(|_|"Emergency request could not be created".to_string())?;
    event(db, &id, "emergency", "request", principal, justification)
        .map_err(|_| "Emergency provenance could not be recorded".to_string())?;
    Ok(id)
}
pub fn review_emergency(
    db: &Connection,
    id: &str,
    reviewer: &str,
    approve: bool,
) -> Result<(), String> {
    let maker: String = db
        .query_row(
            "select principal_id from emergency_access where id=?1 and status='pending'",
            [id],
            |r| r.get(0),
        )
        .map_err(|_| "Pending emergency request not found".to_string())?;
    if maker == reviewer {
        return Err("Emergency requester cannot self-review".into());
    }
    let status = if approve { "approved" } else { "rejected" };
    db.execute("update emergency_access set status=?1,reviewed_by=?2,reviewed_at=datetime('now') where id=?3 and status='pending'",params![status,reviewer,id]).map_err(|_|"Emergency request could not be reviewed".to_string())?;
    event(
        db,
        id,
        "emergency",
        status,
        reviewer,
        "independent emergency review",
    )
    .map_err(|_| "Emergency provenance could not be recorded".to_string())
}
pub fn emergency_valid(
    db: &Connection,
    id: &str,
    principal: &str,
    workspace: &str,
    action: &str,
) -> Result<bool, String> {
    db.query_row("select exists(select 1 from emergency_access where id=?1 and principal_id=?2 and workspace_id=?3 and action=?4 and status='approved' and datetime(expires_at)>datetime('now'))",params![id,principal,workspace,action],|r|r.get(0)).map_err(|_|"Emergency access validation unavailable".to_string())
}
pub fn revoke_emergency(db: &Connection, id: &str, reviewer: &str) -> Result<(), String> {
    if db.execute("update emergency_access set status='revoked',revoked_at=datetime('now') where id=?1 and reviewed_by=?2 and status='approved'",params![id,reviewer]).map_err(|_|"Emergency access could not be revoked".to_string())?!=1{return Err("Approved emergency access not found".into());}
    event(
        db,
        id,
        "emergency",
        "revoke",
        reviewer,
        "emergency access revoked",
    )
    .map_err(|_| "Emergency revocation provenance could not be recorded".to_string())
}

fn refresh_expiry(db: &Connection, id: &str) -> Result<(), String> {
    db.execute("update approval_request set status='expired',decided_at=datetime('now') where id=?1 and status in ('pending','approved') and datetime(expires_at)<=datetime('now')",[id]).map_err(|_|"Approval expiry could not be evaluated".to_string())?;
    Ok(())
}
fn get(db: &Connection, id: &str) -> Result<ApprovalView, String> {
    db.query_row("select a.id,a.request_id,a.request_hash,a.workspace_id,a.action,a.resource,a.requested_by,a.status,a.required_quorum,(select count(*) from approval_vote v where v.approval_id=a.id and v.decision='approve'),a.expires_at,a.created_at from approval_request a where a.id=?1",[id],|r|Ok(ApprovalView{id:r.get(0)?,request_id:r.get(1)?,request_hash:r.get(2)?,workspace_id:r.get(3)?,action:r.get(4)?,resource:r.get(5)?,requested_by:r.get(6)?,status:r.get(7)?,required_quorum:r.get(8)?,approvals:r.get(9)?,expires_at:r.get(10)?,created_at:r.get(11)?})).map_err(|_|"Approval not found".to_string())
}
fn event(
    db: &Connection,
    subject: &str,
    kind: &str,
    action: &str,
    actor: &str,
    details: &str,
) -> rusqlite::Result<()> {
    db.execute("insert into approval_lifecycle_event(id,subject_id,subject_kind,action,actor,details,created_at) values(?1,?2,?3,?4,?5,?6,datetime('now'))",params![format!("approval-event-{}",Uuid::new_v4().simple()),subject,kind,action,actor,details])?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{
        commands,
        domain::{AssuranceLevel, ProtectedAction},
        policy,
    };
    use siddham_contracts::SCHEMA_VERSION;
    fn setup() -> (Connection, String, String, OperationRequest) {
        let mut db = crate::storage::memory().unwrap();
        let maker = identity::ensure_local_bootstrap(&mut db).unwrap();
        policy::ensure_default(&db).unwrap();
        db.execute("insert into principal values('security-checker','human','Security Checker','active',datetime('now'),null)",[]).unwrap();
        db.execute("insert into device values('device-checker','security-checker','Checker device','sha256:checker','active',0,datetime('now'),null)",[]).unwrap();
        db.execute("insert into workspace_membership values('siddham-core-rd','security-checker','security-reviewer','active',datetime('now'))",[]).unwrap();
        let checker = format!("session-{}", Uuid::new_v4().simple());
        db.execute("insert into authority_session values(?1,'security-checker','device-checker','AAL3',0,datetime('now'),datetime('now','+8 hours'),null)",[&checker]).unwrap();
        let op = OperationRequest {
            schema_version: SCHEMA_VERSION.into(),
            request_id: "req-approval".into(),
            principal: "release-authority".into(),
            action: ProtectedAction::DatasetExport,
            resource: "restricted-ip".into(),
            workspace: "siddham-core-rd".into(),
            assurance: AssuranceLevel::AAL3,
            operation: None,
        };
        let hash = policy::hash_request(&op);
        commands::claim_request(&db, &maker, &op.request_id, &hash).unwrap();
        (db, maker, checker, op)
    }
    #[test]
    fn maker_checker_approval_is_bound_and_consumed_once() {
        let (mut db, _maker, checker, op) = setup();
        let hash = policy::hash_request(&op);
        let approval = request(&db, &op, &hash, 1).unwrap();
        let decided = decide(
            &db,
            &checker,
            &approval.id,
            "approve",
            "independent review complete",
        )
        .unwrap();
        assert_eq!(decided.status, "approved");
        consume(&mut db, &approval.id, &op.request_id, &hash).unwrap();
        assert!(consume(&mut db, &approval.id, &op.request_id, &hash).is_err());
    }
    #[test]
    fn maker_cannot_self_approve_and_rejection_is_terminal() {
        let (db, maker, checker, op) = setup();
        let approval = request(&db, &op, &policy::hash_request(&op), 1).unwrap();
        assert!(decide(&db, &maker, &approval.id, "approve", "self approval").is_err());
        assert_eq!(
            decide(&db, &checker, &approval.id, "reject", "risk unacceptable")
                .unwrap()
                .status,
            "rejected"
        );
        assert!(decide(&db, &checker, &approval.id, "approve", "changed mind").is_err());
    }
    #[test]
    fn maker_can_cancel_only_while_pending() {
        let (db, _maker, _checker, op) = setup();
        let first = request(&db, &op, &policy::hash_request(&op), 1).unwrap();
        assert_eq!(
            cancel(&db, &first.id, "release-authority").unwrap().status,
            "cancelled"
        );
        assert!(cancel(&db, &first.id, "release-authority").is_err());
    }
    #[test]
    fn mismatched_or_expired_approval_fails_closed() {
        let (mut db, _maker, checker, op) = setup();
        let hash = policy::hash_request(&op);
        let approval = request(&db, &op, &hash, 1).unwrap();
        decide(&db, &checker, &approval.id, "approve", "review complete").unwrap();
        assert!(consume(&mut db, &approval.id, &op.request_id, "wrong").is_err());
        db.execute(
            "update approval_request set expires_at=datetime('now','-1 second') where id=?1",
            [&approval.id],
        )
        .unwrap();
        assert!(consume(&mut db, &approval.id, &op.request_id, &hash).is_err());
    }
    #[test]
    fn delegation_is_scoped_expiring_and_revocable() {
        let (db, _, _, _) = setup();
        let id = grant_delegation(
            &db,
            "release-authority",
            "security-checker",
            "siddham-core-rd",
            "evidence:export",
            1,
        )
        .unwrap();
        assert!(delegation_valid(
            &db,
            &id,
            "security-checker",
            "siddham-core-rd",
            "evidence:export"
        )
        .unwrap());
        assert!(!delegation_valid(
            &db,
            &id,
            "security-checker",
            "siddham-core-rd",
            "policy:edit"
        )
        .unwrap());
        revoke_delegation(&db, &id, "release-authority").unwrap();
        assert!(!delegation_valid(
            &db,
            &id,
            "security-checker",
            "siddham-core-rd",
            "evidence:export"
        )
        .unwrap());
    }
    #[test]
    fn emergency_access_requires_independent_review() {
        let (db, _, _, _) = setup();
        let id = request_emergency(
            &db,
            "release-authority",
            "siddham-core-rd",
            "policy:edit",
            "restore authority after incident",
        )
        .unwrap();
        assert!(review_emergency(&db, &id, "release-authority", true).is_err());
        review_emergency(&db, &id, "security-checker", true).unwrap();
        let status: String = db
            .query_row(
                "select status from emergency_access where id=?1",
                [&id],
                |r| r.get(0),
            )
            .unwrap();
        assert_eq!(status, "approved");
        assert!(emergency_valid(
            &db,
            &id,
            "release-authority",
            "siddham-core-rd",
            "policy:edit"
        )
        .unwrap());
        revoke_emergency(&db, &id, "security-checker").unwrap();
        assert!(!emergency_valid(
            &db,
            &id,
            "release-authority",
            "siddham-core-rd",
            "policy:edit"
        )
        .unwrap());
    }

    #[test]
    fn quorum_requires_distinct_eligible_approvers() {
        let (db, _maker, checker, op) = setup();
        db.execute("insert into principal values('release-checker','human','Release Checker','active',datetime('now'),null)",[]).unwrap();
        db.execute("insert into device values('device-release-checker','release-checker','Release checker device','sha256:release-checker','active',0,datetime('now'),null)",[]).unwrap();
        db.execute("insert into workspace_membership values('siddham-core-rd','release-checker','release-checker','active',datetime('now'))",[]).unwrap();
        let second = format!("session-{}", Uuid::new_v4().simple());
        db.execute("insert into authority_session values(?1,'release-checker','device-release-checker','AAL3',0,datetime('now'),datetime('now','+8 hours'),null)",[&second]).unwrap();
        let approval = request(&db, &op, &policy::hash_request(&op), 2).unwrap();
        assert_eq!(
            decide(
                &db,
                &checker,
                &approval.id,
                "approve",
                "security review complete"
            )
            .unwrap()
            .status,
            "pending"
        );
        let final_state = decide(
            &db,
            &second,
            &approval.id,
            "approve",
            "release review complete",
        )
        .unwrap();
        assert_eq!(final_state.status, "approved");
        assert_eq!(final_state.approvals, 2);
    }
}
