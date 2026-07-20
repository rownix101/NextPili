use crate::error::{Error, Result};
use auth::generate_buvid3;
use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};

/// Device-scoped identifiers (not bound to a login account).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DeviceState {
    pub buvid3: String,
    /// Optional future fields (buvid4, local_id, …).
    #[serde(default)]
    pub buvid4: Option<String>,
}

impl DeviceState {
    pub fn generate() -> Self {
        Self {
            buvid3: generate_buvid3(),
            buvid4: None,
        }
    }
}

#[derive(Debug)]
pub struct DeviceStore {
    path: PathBuf,
}

impl DeviceStore {
    pub fn new(path: impl Into<PathBuf>) -> Self {
        Self { path: path.into() }
    }

    pub fn path(&self) -> &Path {
        &self.path
    }

    /// Load existing device state or create + persist a new one.
    pub fn load_or_create(&self) -> Result<DeviceState> {
        if self.path.exists() {
            let raw = std::fs::read_to_string(&self.path).map_err(Error::io)?;
            let state: DeviceState = serde_json::from_str(&raw).map_err(Error::ser)?;
            if state.buvid3.is_empty() {
                let state = DeviceState::generate();
                self.save(&state)?;
                return Ok(state);
            }
            return Ok(state);
        }
        let state = DeviceState::generate();
        self.save(&state)?;
        Ok(state)
    }

    pub fn save(&self, state: &DeviceState) -> Result<()> {
        if let Some(parent) = self.path.parent() {
            std::fs::create_dir_all(parent).map_err(Error::io)?;
        }
        let raw = serde_json::to_string_pretty(state).map_err(Error::ser)?;
        let tmp = self.path.with_extension("json.tmp");
        std::fs::write(&tmp, raw).map_err(Error::io)?;
        std::fs::rename(&tmp, &self.path).map_err(Error::io)?;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    #[test]
    fn creates_stable_buvid() {
        let dir = tempdir().unwrap();
        let path = dir.path().join("device.json");
        let store = DeviceStore::new(&path);
        let a = store.load_or_create().unwrap();
        let b = store.load_or_create().unwrap();
        assert_eq!(a.buvid3, b.buvid3);
        assert!(a.buvid3.ends_with("infoc"));
    }
}
