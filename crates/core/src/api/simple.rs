use crate::app::{BootstrapParams, CoreApp};
use crate::error::AppError;
use crate::{API_MAJOR, API_MINOR, API_PATCH, CORE_VERSION};

/// FFI API version payload.
#[derive(Debug, Clone)]
pub struct ApiVersion {
    pub major: u32,
    pub minor: u32,
    pub patch: u32,
    /// Core package version / build id.
    pub core: String,
}

/// Runtime bootstrap configuration from Flutter.
#[derive(Debug, Clone)]
pub struct BootstrapConfig {
    pub data_dir: String,
    pub cache_dir: String,
    pub log_level: String,
}

/// FRB runtime initialization (called from Dart `RustLib.init()`).
#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Setup backtrace / logging helpers used by flutter_rust_bridge.
    flutter_rust_bridge::setup_default_user_utils();
}

/// Health check for FRB / native library linkage.
#[flutter_rust_bridge::frb(sync)]
pub fn ping() -> String {
    "pong".to_string()
}

/// Return FFI compatibility version.
#[flutter_rust_bridge::frb(sync)]
pub fn api_version() -> ApiVersion {
    ApiVersion {
        major: API_MAJOR,
        minor: API_MINOR,
        patch: API_PATCH,
        core: CORE_VERSION.to_string(),
    }
}

/// Initialize process-global core (store, http client, accounts).
pub fn bootstrap(config: BootstrapConfig) -> Result<(), AppError> {
    CoreApp::bootstrap(BootstrapParams {
        data_dir: config.data_dir,
        cache_dir: config.cache_dir,
        log_level: if config.log_level.is_empty() {
            "info".into()
        } else {
            config.log_level
        },
    })?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ping_pong() {
        assert_eq!(ping(), "pong");
    }

    #[test]
    fn version_shape() {
        let v = api_version();
        assert_eq!(v.major, 0);
        assert_eq!(v.minor, 4);
        assert!(!v.core.is_empty());
    }
}
