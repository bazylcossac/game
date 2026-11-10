use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct Release {
    pub key: String,
    pub release_id: u64,
    pub asset_id: u64,
    pub tag: String,
    pub version: String,
    pub title: String,
    pub notes: String,
    pub published_at: String,
    pub sha256: String,
    pub size: u64,
    pub testing: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct Preferences {
    pub selection: String,
    pub auto_update: bool,
    pub minimize_on_play: bool,
}

impl Default for Preferences {
    fn default() -> Self {
        Self {
            selection: "stable".into(),
            auto_update: true,
            minimize_on_play: true,
        }
    }
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct DiskState {
    pub installed: Option<Release>,
    pub preferences: Preferences,
    pub releases: Vec<Release>,
    pub checked_at: Option<u64>,
    pub etag: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Transaction {
    pub release: Release,
    pub selection: String,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Progress {
    pub phase: String,
    pub downloaded: u64,
    pub total: u64,
    pub message: String,
    pub target: Option<Release>,
}

impl Default for Progress {
    fn default() -> Self {
        Self {
            phase: "idle".into(),
            downloaded: 0,
            total: 0,
            message: String::new(),
            target: None,
        }
    }
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Snapshot {
    pub state: DiskState,
    pub progress: Progress,
    pub healthy: bool,
    pub busy: bool,
    pub paused: bool,
    pub game_running: bool,
    pub install_path: String,
    pub error: Option<String>,
    pub online: bool,
    pub launcher_version: String,
}
