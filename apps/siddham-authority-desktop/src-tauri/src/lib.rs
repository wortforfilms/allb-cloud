mod approval;
mod commands;
mod domain;
mod evidence;
mod executor;
mod identity;
mod policy;
mod storage;

use std::sync::Mutex;
use tauri::Manager;

pub struct Runtime {
    pub db: Mutex<rusqlite::Connection>,
    pub policy: policy::PolicyEngine,
    pub local_session_id: String,
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .setup(|app| {
            let directory = app.path().app_data_dir()?;
            std::fs::create_dir_all(&directory)?;
            let mut db = storage::open(directory.join("authority.db"))?;
            let local_session_id = identity::ensure_local_bootstrap(&mut db)?;
            policy::ensure_default(&db)?;
            executor::ensure_defaults(&db)?;
            app.manage(Runtime {
                db: Mutex::new(db),
                policy: policy::PolicyEngine::default(),
                local_session_id,
            });
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            commands::execute_governed,
            commands::runtime_capabilities,
            commands::list_evidence,
            commands::system_status,
            commands::verify_evidence_chain,
            commands::identity_context,
            commands::list_federation_providers,
            commands::revoke_current_session,
            commands::revoke_current_device,
            commands::list_approvals,
            commands::submit_approval_decision,
            commands::cancel_approval,
            commands::handler_registry,
            commands::cancel_execution
        ])
        .run(tauri::generate_context!())
        .expect("run Siddham Authority Desktop");
}
