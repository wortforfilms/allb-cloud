use rusqlite::Connection;
use std::path::PathBuf;

const MIGRATION_001: &str = include_str!("../migrations/001_initial.sql");
const MIGRATION_002: &str = include_str!("../migrations/002_outbox.sql");
const MIGRATION_003: &str = include_str!("../migrations/003_evidence_v2.sql");
const MIGRATION_004: &str = include_str!("../migrations/004_execution_evidence.sql");
const MIGRATION_005: &str = include_str!("../migrations/005_identity_tenancy.sql");
const MIGRATION_006: &str = include_str!("../migrations/006_authority_policy.sql");
const MIGRATION_007: &str = include_str!("../migrations/007_approvals.sql");
const MIGRATION_008: &str = include_str!("../migrations/008_execution_registry.sql");

pub fn open(path: PathBuf) -> rusqlite::Result<Connection> {
    let mut db = Connection::open(path)?;
    configure(&db)?;
    migrate(&mut db)?;
    Ok(db)
}

#[cfg(test)]
pub fn memory() -> rusqlite::Result<Connection> {
    let mut db = Connection::open_in_memory()?;
    configure(&db)?;
    migrate(&mut db)?;
    Ok(db)
}

fn configure(db: &Connection) -> rusqlite::Result<()> {
    db.execute_batch("pragma journal_mode=WAL; pragma foreign_keys=ON; pragma busy_timeout=5000; pragma synchronous=FULL;")
}

fn migrate(db: &mut Connection) -> rusqlite::Result<()> {
    db.execute_batch("create table if not exists schema_migration(version integer primary key, applied_at text not null);")?;
    for (version, sql) in [
        (1, MIGRATION_001),
        (2, MIGRATION_002),
        (3, MIGRATION_003),
        (4, MIGRATION_004),
        (5, MIGRATION_005),
        (6, MIGRATION_006),
        (7, MIGRATION_007),
        (8, MIGRATION_008),
    ] {
        let applied: bool = db.query_row(
            "select exists(select 1 from schema_migration where version=?)",
            [version],
            |r| r.get(0),
        )?;
        if !applied {
            let tx = db.transaction()?;
            tx.execute_batch(sql)?;
            tx.execute(
                "insert into schema_migration(version,applied_at) values(?,datetime('now'))",
                [version],
            )?;
            tx.commit()?;
        }
    }
    Ok(())
}
