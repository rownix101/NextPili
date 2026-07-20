use crate::error::{AppError, ErrorKind};
use crate::heartbeat::HeartbeatSupervisor;
use auth::{AccountRegistry, WbiSigner};
use http::{BiliClient, ClientConfig, NavApi};
use media::MediaService;
use parking_lot::RwLock;
use store::Store;
use std::sync::{Arc, OnceLock};

/// Process-global application state.
pub struct CoreApp {
    pub store: Store,
    pub accounts: RwLock<AccountRegistry>,
    http: RwLock<BiliClient>,
    pub media: MediaService,
    pub wbi: RwLock<WbiSigner>,
    pub heartbeat: HeartbeatSupervisor,
    pub log_level: String,
}

static APP: OnceLock<Arc<CoreApp>> = OnceLock::new();

impl CoreApp {
    pub fn global() -> Result<Arc<CoreApp>, AppError> {
        APP.get()
            .cloned()
            .ok_or_else(|| AppError::new(ErrorKind::Internal, "core not bootstrapped"))
    }

    pub fn try_global() -> Option<Arc<CoreApp>> {
        APP.get().cloned()
    }

    /// Clone of the current HTTP client (cheap; reqwest Client is Arc-backed).
    pub fn http(&self) -> BiliClient {
        self.http.read().clone()
    }

    /// Rebuild HTTP client with a new proxy (None = direct).
    pub fn set_http_proxy(&self, proxy: Option<String>) -> Result<(), AppError> {
        let mut cfg = self.http.read().config().clone();
        cfg.proxy = proxy;
        let client = BiliClient::new(cfg).map_err(AppError::from)?;
        *self.http.write() = client;
        Ok(())
    }

    pub fn bootstrap(config: BootstrapParams) -> Result<Arc<CoreApp>, AppError> {
        if let Some(existing) = APP.get() {
            return Ok(existing.clone());
        }

        init_tracing(&config.log_level);

        let store = Store::open_with_cache(
            &config.data_dir,
            if config.cache_dir.is_empty() {
                None
            } else {
                Some(config.cache_dir.clone().into())
            },
        )
        .map_err(AppError::from)?;
        let accounts = store.load_accounts().map_err(AppError::from)?;

        let mut client_cfg = ClientConfig::default();
        if let Some(proxy) = store.settings().proxy {
            client_cfg.proxy = Some(proxy);
        }
        let http = BiliClient::new(client_cfg).map_err(AppError::from)?;
        let hw_caps = crate::hw_decode::hw_decode_caps();
        let media = MediaService::with_hw_caps(hw_caps);
        let wbi = WbiSigner::new();
        let heartbeat = HeartbeatSupervisor::new();

        let app = Arc::new(CoreApp {
            store,
            accounts: RwLock::new(accounts),
            http: RwLock::new(http),
            media,
            wbi: RwLock::new(wbi),
            heartbeat,
            log_level: config.log_level,
        });

        let _ = APP.set(app.clone());
        tracing::info!(
            data_dir = %config.data_dir,
            buvid3 = %app.store.buvid3(),
            vendor = ?hw_caps.vendor,
            avc = hw_caps.avc,
            hevc = hw_caps.hevc,
            av1 = hw_caps.av1,
            "NextPili core bootstrapped"
        );

        // Best-effort WBI warm-up (ignore network errors at boot).
        let warm_http = app.http();
        let warm_buvid = app.store.buvid3();
        let warm_app = app.clone();
        if let Ok(handle) = tokio::runtime::Handle::try_current() {
            handle.spawn(async move {
                let acc = warm_app.accounts.read().active_main().cloned();
                let mut wbi_local = warm_app.wbi.read().clone();
                match NavApi::refresh_wbi(&warm_http, &mut wbi_local, acc.as_ref(), Some(&warm_buvid)).await {
                    Ok(_) => {
                        *warm_app.wbi.write() = wbi_local;
                    }
                    Err(e) => {
                        tracing::debug!(error = %e, "wbi warm-up skipped");
                    }
                }
            });
        }

        Ok(app)
    }
}

/// Internal bootstrap params (mirrors FFI DTO).
pub struct BootstrapParams {
    pub data_dir: String,
    pub cache_dir: String,
    pub log_level: String,
}

fn init_tracing(level: &str) {
    let filter = tracing_subscriber::EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new(level));
    let _ = tracing_subscriber::fmt()
        .with_env_filter(filter)
        .with_target(false)
        .try_init();
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    #[test]
    fn bootstrap_opens_store_and_device() {
        // Note: process-global OnceLock — only first success in this process sticks.
        let dir = tempdir().unwrap();
        let data = dir.path().join("data");
        let cache = dir.path().join("cache");
        let app = CoreApp::bootstrap(BootstrapParams {
            data_dir: data.to_string_lossy().into(),
            cache_dir: cache.to_string_lossy().into(),
            log_level: "info".into(),
        })
        .unwrap();
        assert!(app.store.paths().data_dir.exists());
        assert!(!app.store.buvid3().is_empty());
    }
}
