use md5::{Digest, Md5};
use std::collections::BTreeMap;

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

    /// Sign params: add `appkey` if missing, sort, concat with appsec, md5.
    pub fn sign(&self, params: &mut BTreeMap<String, String>) -> String {
        params
            .entry("appkey".into())
            .or_insert_with(|| self.appkey.clone());

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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn app_sign_stable() {
        let signer = AppSigner::new("testkey", "testsec");
        let mut params = BTreeMap::new();
        params.insert("ts".into(), "1".into());
        params.insert("foo".into(), "bar".into());
        let sign = signer.sign(&mut params);
        // Recompute
        let mut again = BTreeMap::new();
        again.insert("ts".into(), "1".into());
        again.insert("foo".into(), "bar".into());
        let sign2 = signer.sign(&mut again);
        assert_eq!(sign, sign2);
        assert_eq!(params.get("sign").map(String::as_str), Some(sign.as_str()));
    }
}
