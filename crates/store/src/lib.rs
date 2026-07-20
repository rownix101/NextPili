//! Local persistence. Skeleton uses JSON files; SQLite may replace later.

pub mod accounts;
pub mod device;
pub mod error;
pub mod paths;
pub mod settings;

pub use accounts::AccountsStore;
pub use device::{DeviceState, DeviceStore};
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
    accounts: Mutex<AccountsStore>,
    device: Mutex<DeviceStore>,
    device_state: Mutex<DeviceState>,
}

impl Store {
    pub fn open(data_dir: impl Into<PathBuf>) -> Result<Self> {
        Self::open_with_cache(data_dir, None)
    }

    pub fn open_with_cache(
        data_dir: impl Into<PathBuf>,
        cache_dir: Option<PathBuf>,
    ) -> Result<Self> {
        let mut paths = AppPaths::new(data_dir);
        if let Some(cache) = cache_dir {
            paths = paths.with_cache_dir(cache);
        }
        std::fs::create_dir_all(&paths.data_dir).map_err(Error::io)?;
        std::fs::create_dir_all(&paths.cache_dir).map_err(Error::io)?;

        let settings = SettingsStore::load_or_default(paths.settings_file())?;
        let accounts = AccountsStore::new(paths.accounts_file());
        let device = DeviceStore::new(paths.device_file());
        let device_state = device.load_or_create()?;

        Ok(Self {
            inner: Arc::new(StoreInner {
                paths,
                settings: Mutex::new(settings),
                accounts: Mutex::new(accounts),
                device: Mutex::new(device),
                device_state: Mutex::new(device_state),
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

    pub fn load_accounts(&self) -> Result<AccountRegistry> {
        self.inner.accounts.lock().load()
    }

    pub fn save_accounts(&self, registry: &AccountRegistry) -> Result<()> {
        self.inner.accounts.lock().save(registry)
    }

    pub fn device(&self) -> DeviceState {
        self.inner.device_state.lock().clone()
    }

    pub fn buvid3(&self) -> String {
        self.inner.device_state.lock().buvid3.clone()
    }

    pub fn set_device(&self, state: DeviceState) -> Result<()> {
        self.inner.device.lock().save(&state)?;
        *self.inner.device_state.lock() = state;
        Ok(())
    }
}
