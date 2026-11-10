#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod engine;
mod github;
mod models;

use engine::Engine;
use models::{Preferences, Snapshot};
use std::sync::Arc;
use tauri::{Emitter, Manager, State};

#[tauri::command]
fn snapshot(engine: State<'_, Arc<Engine>>) -> Snapshot {
    engine.snapshot()
}

#[tauri::command]
async fn refresh(engine: State<'_, Arc<Engine>>) -> Result<Snapshot, String> {
    let engine = Arc::clone(engine.inner());
    tauri::async_runtime::spawn_blocking(move || engine.refresh())
        .await
        .map_err(|e| e.to_string())?
}

#[tauri::command]
fn install(
    engine: State<'_, Arc<Engine>>,
    key: String,
    selection: String,
) -> Result<Snapshot, String> {
    engine.start(key, selection)
}

#[tauri::command]
fn preferences(engine: State<'_, Arc<Engine>>, value: Preferences) -> Result<Snapshot, String> {
    engine.preferences(value)
}

#[tauri::command]
fn cancel(engine: State<'_, Arc<Engine>>) -> Result<Snapshot, String> {
    engine.cancel()
}

#[tauri::command]
fn pause(engine: State<'_, Arc<Engine>>) -> Result<Snapshot, String> {
    engine.pause()
}

#[tauri::command]
async fn verify_files(engine: State<'_, Arc<Engine>>) -> Result<Snapshot, String> {
    let engine = Arc::clone(engine.inner());
    tauri::async_runtime::spawn_blocking(move || engine.verify_installed())
        .await
        .map_err(|e| e.to_string())?
}

#[tauri::command]
async fn play(app: tauri::AppHandle, engine: State<'_, Arc<Engine>>) -> Result<Snapshot, String> {
    let engine = Arc::clone(engine.inner());
    let result = tauri::async_runtime::spawn_blocking(move || engine.launch())
        .await
        .map_err(|e| e.to_string())??;
    if result.state.preferences.minimize_on_play {
        if let Some(window) = app.get_webview_window("main") {
            let _ = window.minimize();
        }
    }
    Ok(result)
}

#[tauri::command]
fn open_releases() -> Result<(), String> {
    std::process::Command::new("explorer.exe")
        .arg("https://github.com/bazylcossac/game/releases")
        .spawn()
        .map(|_| ())
        .map_err(|e| format!("Nie można otworzyć strony wydań: {e}"))
}

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_single_instance::init(|app,_,_| {
            if let Some(window)=app.get_webview_window("main") { let _=window.unminimize(); let _=window.show(); let _=window.set_focus(); }
        }))
        .setup(|app| {
            let local=std::env::var_os("LOCALAPPDATA").ok_or("Brak katalogu LOCALAPPDATA")?;
            let engine=Engine::new(std::path::PathBuf::from(local).join("CorpWars"))
                .map_err(std::io::Error::other)?;
            app.manage(engine);
            Ok(())
        })
        .on_window_event(|window,event| {
            if let tauri::WindowEvent::CloseRequested { api,.. }=event {
                if let Some(engine)=window.try_state::<Arc<Engine>>() {
                    if engine.snapshot().busy { api.prevent_close(); let _=window.emit("close-blocked","Aktualizacja trwa. Anuluj pobieranie albo poczekaj na zakończenie instalacji, zanim zamkniesz launcher."); }
                }
            }
        })
        .invoke_handler(tauri::generate_handler![snapshot,refresh,install,preferences,cancel,pause,verify_files,play,open_releases])
        .run(tauri::generate_context!())
        .expect("Nie można uruchomić launchera Corp Wars");
}
