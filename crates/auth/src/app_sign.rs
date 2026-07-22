use crate::constants::{APPKEY_ANDROID_HD, APPSEC_ANDROID_HD};
use md5::{Digest, Md5};
use std::collections::BTreeMap;
use std::time::{SystemTime, UNIX_EPOCH};

/// App API signer (appkey + appsec).
#[derive(Debug, Clone)]
pub struct AppSigner {
    pub appkey: String,
    pub appsec: String,
}

impl AppSigner {
    pub fn new(appkey: impl Into<String>, appsec: impl Into<String>) -> Self {
        Self {
            appkey: appkey.into(),
            appsec: appsec.into(),
        }
    }

    /// Default Android HD signer used by TV QR login and HD app paths.
    pub fn android_hd() -> Self {
        Self::new(APPKEY_ANDROID_HD, APPSEC_ANDROID_HD)
    }

    /// Inject `appkey`, `ts` (unix seconds), and `sign` into params.
    ///
    /// Existing `sign` is removed before hashing.
    pub fn sign(&self, params: &mut BTreeMap<String, String>) -> String {
        self.sign_with_ts(params, unix_secs())
    }

    pub fn sign_with_ts(&self, params: &mut BTreeMap<String, String>, ts: u64) -> String {
        params.remove("sign");
        params.insert("appkey".into(), self.appkey.clone());
        params.insert("ts".into(), ts.to_string());

        // PiliPlus / bilibili-API-collect: md5( urlencode(sorted_query) + appsec ).
        // Values such as statistics JSON must be percent-encoded or sign fails.
        let query = encode_sign_query(params);
        let raw = format!("{query}{}", self.appsec);
        let mut hasher = Md5::new();
        hasher.update(raw.as_bytes());
        let sign = hex::encode(hasher.finalize());
        params.insert("sign".into(), sign.clone());
        sign
    }
}

/// Build sorted `key=value&…` with RFC3986 component encoding (PiliPlus `Uri.encodeComponent`).
///
/// Empty values: `key` without `=` (matches PiliPlus `_makeQueryFromParametersDefault`).
fn encode_sign_query(params: &BTreeMap<String, String>) -> String {
    let mut parts = Vec::with_capacity(params.len());
    for (k, v) in params {
        let ek = percent_encode_component(k);
        if v.is_empty() {
            parts.push(ek);
        } else {
            parts.push(format!("{ek}={}", percent_encode_component(v)));
        }
    }
    parts.join("&")
}

/// Percent-encode for URI component: unreserved = ALPHA / DIGIT / "-" / "." / "_" / "~".
fn percent_encode_component(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    for b in s.bytes() {
        match b {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => {
                out.push(b as char);
            }
            _ => out.push_str(&format!("%{b:02X}")),
        }
    }
    out
}

fn unix_secs() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn app_sign_stable_with_fixed_ts() {
        let signer = AppSigner::new("testkey", "testsec");
        let mut params = BTreeMap::new();
        params.insert("foo".into(), "bar".into());
        let sign = signer.sign_with_ts(&mut params, 1);
        assert_eq!(params.get("appkey").map(String::as_str), Some("testkey"));
        assert_eq!(params.get("ts").map(String::as_str), Some("1"));
        assert_eq!(params.get("sign").map(String::as_str), Some(sign.as_str()));

        let mut hasher = Md5::new();
        hasher.update(b"appkey=testkey&foo=bar&ts=1testsec");
        let expected = hex::encode(hasher.finalize());
        assert_eq!(sign, expected);
    }

    #[test]
    fn app_sign_strips_old_sign() {
        let signer = AppSigner::new("k", "s");
        let mut params = BTreeMap::new();
        params.insert("sign".into(), "old".into());
        params.insert("a".into(), "1".into());
        let sign = signer.sign_with_ts(&mut params, 2);
        assert_ne!(sign, "old");
        assert_eq!(params.get("sign").map(String::as_str), Some(sign.as_str()));
    }

    #[test]
    fn android_hd_constants_present() {
        let s = AppSigner::android_hd();
        assert_eq!(s.appkey, APPKEY_ANDROID_HD);
        assert!(!s.appsec.is_empty());
    }

    #[test]
    fn app_sign_encodes_statistics_json() {
        let signer = AppSigner::new("dfca71928277209b", "b5475a8825547a4fc26c7d518eaaa02e");
        let mut params = BTreeMap::new();
        params.insert(
            "statistics".into(),
            r#"{"appId":5,"platform":3,"version":"2.0.1","abtest":""}"#.into(),
        );
        params.insert("tel".into(), "13800138000".into());
        let sign = signer.sign_with_ts(&mut params, 1_700_000_000);

        let encoded_stats = percent_encode_component(
            r#"{"appId":5,"platform":3,"version":"2.0.1","abtest":""}"#,
        );
        let query = format!(
            "appkey=dfca71928277209b&statistics={encoded_stats}&tel=13800138000&ts=1700000000"
        );
        let mut hasher = Md5::new();
        hasher.update(format!("{query}b5475a8825547a4fc26c7d518eaaa02e").as_bytes());
        assert_eq!(sign, hex::encode(hasher.finalize()));
        // Unencoded braces must not appear in the signed query material.
        assert!(encoded_stats.contains("%7B") || encoded_stats.contains("%7b"));
    }

    #[test]
    fn empty_value_omits_equals_in_sign_query() {
        let mut params = BTreeMap::new();
        params.insert("a".into(), String::new());
        params.insert("b".into(), "1".into());
        assert_eq!(encode_sign_query(&params), "a&b=1");
    }
}
