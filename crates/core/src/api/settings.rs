//! Settings-facing FFI API (preferred qn, proxy).

use crate::app::CoreApp;
use crate::error::{AppError, ErrorKind};

/// Protocol / playback settings (Rust store).
#[derive(Debug, Clone)]
pub struct SettingsDto {
    /// Preferred video quality (Bilibili qn). `0` is invalid; default is 80 (1080P).
    pub preferred_qn: u32,
    /// Optional HTTP(S) proxy URL, e.g. `http://127.0.0.1:7890`.
    pub proxy: Option<String>,
    /// UI language preference (optional).
    pub locale: Option<String>,
}

/// Read current settings from store.
#[flutter_rust_bridge::frb(sync)]
pub fn get_settings() -> Result<SettingsDto, AppError> {
    let app = CoreApp::global()?;
    Ok(map_settings(app.store.settings()))
}

/// Patch settings.
///
/// - `preferred_qn`: `None` keeps previous; `Some(0)` rejects; otherwise persists.
/// - `proxy`: `None` keeps previous; `Some("")` clears; non-empty sets and rebuilds HTTP client.
/// - `locale`: `None` keeps previous; `Some("")` clears; otherwise sets.
#[flutter_rust_bridge::frb(sync)]
pub fn update_settings(
    preferred_qn: Option<u32>,
    proxy: Option<String>,
    locale: Option<String>,
) -> Result<SettingsDto, AppError> {
    let app = CoreApp::global()?;

    if let Some(0) = preferred_qn {
        return Err(AppError::new(
            ErrorKind::InvalidArgument,
            "preferred_qn must be > 0",
        ));
    }

    let mut proxy_changed = false;
    let mut new_proxy: Option<Option<String>> = None;

    if let Some(raw) = proxy {
        let trimmed = raw.trim().to_string();
        if trimmed.is_empty() {
            new_proxy = Some(None);
            proxy_changed = true;
        } else {
            validate_proxy_url(&trimmed)?;
            new_proxy = Some(Some(trimmed));
            proxy_changed = true;
        }
    }

    let settings = app
        .store
        .update_settings(|s| {
            if let Some(qn) = preferred_qn {
                s.preferred_qn = qn;
            }
            if let Some(p) = new_proxy.clone() {
                s.proxy = p;
            }
            if let Some(loc) = locale {
                let t = loc.trim().to_string();
                s.locale = if t.is_empty() { None } else { Some(t) };
            }
        })
        .map_err(AppError::from)?;

    if proxy_changed {
        app.set_http_proxy(settings.proxy.clone())?;
        tracing::info!(proxy = ?settings.proxy, "http proxy updated");
    }

    Ok(map_settings(settings))
}

fn map_settings(s: store::Settings) -> SettingsDto {
    SettingsDto {
        preferred_qn: s.preferred_qn,
        proxy: s.proxy,
        locale: s.locale,
    }
}

fn validate_proxy_url(url: &str) -> Result<(), AppError> {
    let lower = url.to_ascii_lowercase();
    if !(lower.starts_with("http://")
        || lower.starts_with("https://")
        || lower.starts_with("socks5://")
        || lower.starts_with("socks5h://"))
    {
        return Err(AppError::new(
            ErrorKind::InvalidArgument,
            "代理地址须以 http://、https:// 或 socks5:// 开头",
        ));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_bad_proxy_scheme() {
        assert!(validate_proxy_url("ftp://x").is_err());
        assert!(validate_proxy_url("http://127.0.0.1:7890").is_ok());
        assert!(validate_proxy_url("socks5://127.0.0.1:1080").is_ok());
    }
}
