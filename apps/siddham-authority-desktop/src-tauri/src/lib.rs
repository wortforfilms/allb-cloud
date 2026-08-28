mod commands;
mod domain;
mod evidence;
mod policy;
mod storage;

use std::sync::Mutex;
use tauri::Manager;

pub struct Runtime {
    pub db: Mutex<rusqlite::Connection>,
    pub policy: policy::PolicyEngine,
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .setup(|app| {
            let directory = app.path().app_data_dir()?;
            std::fs::create_dir_all(&directory)?;
            let db = storage::open(directory.join("authority.db"))?;
            app.manage(Runtime {
                db: Mutex::new(db),
                policy: policy::PolicyEngine::default(),
            });
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            commands::execute_governed,
            commands::runtime_capabilities,
            commands::list_evidence,
            commands::system_status,
            commands::verify_evidence_chain
        ])
        .run(tauri::generate_context!())
        .expect("run Siddham Authority Desktop");
}
