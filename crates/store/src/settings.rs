use crate::error::{Error, Result};
use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Settings {
    /// Preferred video qn.
    pub preferred_qn: u32,
    /// Optional HTTP(S) proxy URL.
    pub proxy: Option<String>,
    /// UI language preference (may later sync from Flutter).
    pub locale: Option<String>,
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            preferred_qn: 80,
            proxy: None,
            locale: None,
        }
    }
}

#[derive(Debug)]
pub struct SettingsStore {
    path: PathBuf,
    settings: Settings,
}

impl SettingsStore {
    pub fn load_or_default(path: impl Into<PathBuf>) -> Result<Self> {
        let path = path.into();
        let settings = if path.exists() {
            let raw = std::fs::read_to_string(&path).map_err(Error::io)?;
            serde_json::from_str(&raw).map_err(Error::ser)?
        } else {
            Settings::default()
        };
        Ok(Self { path, settings })
    }

    pub fn get(&self) -> &Settings {
        &self.settings
    }

    pub fn get_mut(&mut self) -> &mut Settings {
        &mut self.settings
    }

    pub fn save(&self) -> Result<()> {
        if let Some(parent) = self.path.parent() {
            std::fs::create_dir_all(parent).map_err(Error::io)?;
        }
        let raw = serde_json::to_string_pretty(&self.settings).map_err(Error::ser)?;
        std::fs::write(&self.path, raw).map_err(Error::io)?;
        Ok(())
    }

    pub fn path(&self) -> &Path {
        &self.path
    }
}
