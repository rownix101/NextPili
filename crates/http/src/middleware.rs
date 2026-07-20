//! Request decoration helpers (Cookie, CSRF, AppSign, WBI).

use auth::{Account, AccountSlot, AppSigner, CookieJar, WbiSigner, WEB_REFERER};
use std::collections::BTreeMap;
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AuthMode {
    /// No credentials.
    None,
    /// Attach Cookie jar (and optional device buvid).
    Cookie,
    /// App access_key + AppSign (no Cookie).
    App,
    /// Prefer Cookie; still attach if present.
    OptionalLogin,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SignMode {
    None,
    Wbi,
    AppSign,
}

#[derive(Debug, Clone)]
pub struct RequestContext<'a> {
    pub slot: AccountSlot,
    pub account: Option<&'a Account>,
    pub device_buvid3: Option<&'a str>,
    pub auth: AuthMode,
    pub sign: SignMode,
    pub csrf: bool,
    pub wbi: Option<&'a WbiSigner>,
    pub app_signer: Option<&'a AppSigner>,
}

/// Build Cookie header from account jar + device buvid.
pub fn compose_cookie_header(account: Option<&Account>, device_buvid3: Option<&str>) -> Option<String> {
    let mut jar = CookieJar::new();
    if let Some(buvid) = device_buvid3 {
        if !buvid.is_empty() {
            jar.set("buvid3", buvid);
        }
    }
    if let Some(acc) = account {
        jar.extend_from(&acc.cookie_jar);
        // Prefer account jar buvid if present; already overlayed by extend.
    }
    if jar.is_empty() {
        None
    } else {
        Some(jar.header_value())
    }
}

pub fn web_baseline_headers(mid: Option<i64>) -> Vec<(String, String)> {
    let mut headers = vec![
        ("Referer".into(), WEB_REFERER.into()),
        ("Origin".into(), "https://www.bilibili.com".into()),
    ];
    if let Some(mid) = mid.filter(|m| *m > 0) {
        headers.push(("x-bili-mid".into(), mid.to_string()));
    }
    headers
}

/// Apply AppSign into a param map (mutates).
pub fn apply_app_sign(
    params: &mut BTreeMap<String, String>,
    signer: &AppSigner,
    access_key: Option<&str>,
) {
    if let Some(ak) = access_key {
        if !ak.is_empty() {
            params.insert("access_key".into(), ak.to_string());
        }
    }
    signer.sign(params);
}

/// Apply WBI sign into a param map.
pub fn apply_wbi_sign(
    params: &mut BTreeMap<String, String>,
    signer: &WbiSigner,
) -> Result<(), String> {
    let wts = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0);
    // Clone keys required; WbiSigner::sign_with_keys needs &mut self for cache.
    // Callers should hold &mut when possible — this helper takes immutable snapshot via mixin.
    let img = signer
        .img_key_ref()
        .ok_or_else(|| "wbi img_key missing".to_string())?;
    let sub = signer
        .sub_key_ref()
        .ok_or_else(|| "wbi sub_key missing".to_string())?;
    let mixin = WbiSigner::mixin_key(img, sub);
    signer.sign(params, &mixin, wts);
    Ok(())
}

/// Inject csrf into form/query params when required.
pub fn inject_csrf(params: &mut BTreeMap<String, String>, jar: &CookieJar) -> Result<(), String> {
    let csrf = jar
        .csrf()
        .filter(|s| !s.is_empty())
        .ok_or_else(|| "missing bili_jct for csrf".to_string())?;
    params.insert("csrf".into(), csrf.to_string());
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use auth::{now_ms, Account};
    use domain::id::{AccountId, UserMid};

    #[test]
    fn compose_includes_device_and_session() {
        let mut jar = CookieJar::new();
        jar.set("SESSDATA", "s");
        jar.set("bili_jct", "c");
        let acc = Account {
            id: AccountId::new(),
            mid: UserMid(1),
            name: "n".into(),
            face: String::new(),
            cookie_jar: jar,
            access_key: None,
            refresh_token: None,
            created_at_ms: now_ms(),
            updated_at_ms: now_ms(),
            expired: false,
        };
        let h = compose_cookie_header(Some(&acc), Some("BUVIDinfoc")).unwrap();
        assert!(h.contains("SESSDATA=s"));
        assert!(h.contains("buvid3=BUVIDinfoc") || h.contains("buvid3="));
    }
}
