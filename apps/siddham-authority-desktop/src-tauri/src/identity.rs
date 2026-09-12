use rusqlite::{params, Connection, OptionalExtension};
use serde::Serialize;

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct AuthenticatedContext {
    pub session_id: String,
    pub principal_id: String,
    pub principal_name: String,
    pub device_id: String,
    pub workspace_id: String,
    pub workspace_name: String,
    pub organization_id: String,
    pub role: String,
    pub assurance: String,
    pub expires_at: String,
}

#[derive(Debug, Clone, Serialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct FederationProviderStatus {
    pub id: String,
    pub organization_id: String,
    pub protocol: String,
    pub issuer: String,
    pub status: String,
}

pub fn ensure_local_bootstrap(db: &mut Connection) -> rusqlite::Result<String> {
    let session_id = format!("session-{}", uuid::Uuid::new_v4().simple());
    let tx = db.transaction()?;
    tx.execute("insert or ignore into organization values('org-siddham','Siddham Semiconductor','active',datetime('now'))", [])?;
    tx.execute("insert or ignore into principal values('release-authority','human','Local Release Authority','active',datetime('now'),null)", [])?;
    tx.execute("insert or ignore into device values('device-local-authority','release-authority','This device','sha256:local-development-device','active',0,datetime('now'),null)", [])?;
    tx.execute("insert or ignore into workspace values('siddham-core-rd','org-siddham','Siddham Core R&D','active',datetime('now'))", [])?;
    tx.execute("insert or ignore into workspace values('prototype-lab','org-siddham','Prototype Lab','active',datetime('now'))", [])?;
    tx.execute("insert or ignore into workspace values('investor-room','org-siddham','Investor Room','active',datetime('now'))", [])?;
    tx.execute("insert or ignore into workspace_membership values('siddham-core-rd','release-authority','release-authority','active',datetime('now'))", [])?;
    tx.execute(
        "insert into authority_session(id,principal_id,device_id,assurance,recovery_generation,issued_at,expires_at,revoked_at) values(?1,'release-authority','device-local-authority','AAL3',0,datetime('now'),datetime('now','+8 hours'),null)",
        [&session_id],
    )?;
    tx.commit()?;
    Ok(session_id)
}

pub fn authenticate(
    db: &Connection,
    session_id: &str,
    workspace_id: &str,
) -> Result<AuthenticatedContext, String> {
    let context = db
        .query_row(
            "select s.id,p.id,p.display_name,d.id,w.id,w.display_name,o.id,m.role,s.assurance,s.expires_at
             from authority_session s
             join principal p on p.id=s.principal_id
             join device d on d.id=s.device_id and d.principal_id=p.id
             join workspace_membership m on m.principal_id=p.id
             join workspace w on w.id=m.workspace_id
             join organization o on o.id=w.organization_id
             where s.id=?1 and w.id=?2 and s.revoked_at is null and datetime(s.expires_at)>datetime('now')
               and s.recovery_generation=d.recovery_generation and p.status='active' and d.status='active'
               and m.status='active' and w.status='active' and o.status='active'",
            params![session_id, workspace_id],
            |row| Ok(AuthenticatedContext {
                session_id: row.get(0)?, principal_id: row.get(1)?, principal_name: row.get(2)?,
                device_id: row.get(3)?, workspace_id: row.get(4)?, workspace_name: row.get(5)?,
                organization_id: row.get(6)?, role: row.get(7)?, assurance: row.get(8)?, expires_at: row.get(9)?,
            }),
        )
        .optional()
        .map_err(|_| "Identity authority could not verify the session".to_string())?;
    context.ok_or_else(|| {
        "Session is invalid, expired, revoked, or not a member of this workspace".to_string()
    })
}

pub fn revoke_session(db: &Connection, session_id: &str) -> rusqlite::Result<bool> {
    Ok(db.execute("update authority_session set revoked_at=datetime('now') where id=?1 and revoked_at is null", [session_id])? == 1)
}

pub fn revoke_device(db: &Connection, device_id: &str) -> rusqlite::Result<bool> {
    let changed = db.execute("update device set status='revoked',revoked_at=datetime('now'),recovery_generation=recovery_generation+1 where id=?1 and status!='revoked'", [device_id])?;
    db.execute("update authority_session set revoked_at=datetime('now') where device_id=?1 and revoked_at is null", [device_id])?;
    Ok(changed == 1)
}

pub fn federation_providers(db: &Connection) -> rusqlite::Result<Vec<FederationProviderStatus>> {
    let mut statement = db.prepare(
        "select id,organization_id,protocol,issuer,status from federation_provider order by id",
    )?;
    let rows = statement.query_map([], |row| {
        Ok(FederationProviderStatus {
            id: row.get(0)?,
            organization_id: row.get(1)?,
            protocol: row.get(2)?,
            issuer: row.get(3)?,
            status: row.get(4)?,
        })
    })?;
    rows.collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn database() -> (Connection, String) {
        let mut db = crate::storage::memory().unwrap();
        let session_id = ensure_local_bootstrap(&mut db).unwrap();
        (db, session_id)
    }

    #[test]
    fn workspace_membership_is_not_substitutable() {
        let (db, session_id) = database();
        assert!(authenticate(&db, &session_id, "siddham-core-rd").is_ok());
        assert!(authenticate(&db, &session_id, "prototype-lab").is_err());
    }

    #[test]
    fn expired_and_revoked_sessions_fail_closed() {
        let (db, session_id) = database();
        db.execute(
            "update authority_session set expires_at=datetime('now','-1 second') where id=?1",
            [&session_id],
        )
        .unwrap();
        assert!(authenticate(&db, &session_id, "siddham-core-rd").is_err());
        db.execute("update authority_session set expires_at=datetime('now','+1 hour'),revoked_at=null where id=?1", [&session_id]).unwrap();
        assert!(revoke_session(&db, &session_id).unwrap());
        assert!(authenticate(&db, &session_id, "siddham-core-rd").is_err());
    }

    #[test]
    fn device_revocation_invalidates_its_sessions() {
        let (db, session_id) = database();
        assert!(revoke_device(&db, "device-local-authority").unwrap());
        assert!(authenticate(&db, &session_id, "siddham-core-rd").is_err());
    }

    #[test]
    fn federation_is_empty_until_real_configuration_exists() {
        let (db, _) = database();
        assert!(federation_providers(&db).unwrap().is_empty());
    }
}
