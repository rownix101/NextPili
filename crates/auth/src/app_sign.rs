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

        let query = params
            .iter()
            .map(|(k, v)| format!("{k}={v}"))
            .collect::<Vec<_>>()
            .join("&");
        let raw = format!("{query}{}", self.appsec);
        let mut hasher = Md5::new();
        hasher.update(raw.as_bytes());
        let sign = hex::encode(hasher.finalize());
        params.insert("sign".into(), sign.clone());
        sign
    }
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

        // Recompute expected: appkey=testkey&foo=bar&ts=1 + testsec
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
}
