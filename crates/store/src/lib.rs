//! Local persistence. Skeleton uses JSON files; SQLite may replace later.

pub mod error;
pub mod paths;
pub mod settings;

pub use error::{Error, Result};
pub use paths::AppPaths;
pub use settings::{Settings, SettingsStore};

use auth::AccountRegistry;
use parking_lot::Mutex;
use std::path::PathBuf;
use std::sync::Arc;

/// Process-wide store handle.
#[derive(Clone)]
pub struct Store {
    inner: Arc<StoreInner>,
}

struct StoreInner {
    paths: AppPaths,
    settings: Mutex<SettingsStore>,
    /// Placeholder for accounts persistence (P1).
    _accounts_path: PathBuf,
}

impl Store {
    pub fn open(data_dir: impl Into<PathBuf>) -> Result<Self> {
        let paths = AppPaths::new(data_dir);
        std::fs::create_dir_all(&paths.data_dir).map_err(Error::io)?;
        std::fs::create_dir_all(&paths.cache_dir).map_err(Error::io)?;

        let settings = SettingsStore::load_or_default(paths.settings_file())?;
        Ok(Self {
            inner: Arc::new(StoreInner {
                _accounts_path: paths.accounts_file(),
                paths,
                settings: Mutex::new(settings),
            }),
        })
    }

    pub fn paths(&self) -> &AppPaths {
        &self.inner.paths
    }

    pub fn settings(&self) -> Settings {
        self.inner.settings.lock().get().clone()
    }

    pub fn update_settings<F>(&self, f: F) -> Result<Settings>
    where
        F: FnOnce(&mut Settings),
    {
        let mut guard = self.inner.settings.lock();
        f(guard.get_mut());
        guard.save()?;
        Ok(guard.get().clone())
    }

    /// P1: load accounts from disk. Empty registry for now.
    pub fn load_accounts(&self) -> Result<AccountRegistry> {
        Ok(AccountRegistry::new())
    }
}
