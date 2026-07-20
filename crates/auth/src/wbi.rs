use md5::{Digest, Md5};
use std::collections::BTreeMap;

/// Character filter for WBI encoding (Bilibili mixin).
const MIXIN_KEY_ENC_TAB: [usize; 64] = [
    46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35, 27, 43, 5, 49, 33, 9, 42, 19, 29,
    28, 14, 39, 12, 38, 41, 13, 37, 48, 7, 16, 24, 55, 40, 61, 26, 17, 0, 1, 60, 51, 30, 4, 22, 25,
    54, 21, 56, 59, 6, 63, 57, 62, 11, 36, 20, 34, 44, 52,
];

/// WBI request signer with daily mixin key cache.
#[derive(Debug, Clone, Default)]
pub struct WbiSigner {
    /// Cached (day_index, mixin_key)
    cache: Option<(u32, String)>,
    img_key: Option<String>,
    sub_key: Option<String>,
}

impl WbiSigner {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn set_keys(&mut self, img_key: impl Into<String>, sub_key: impl Into<String>) {
        self.img_key = Some(img_key.into());
        self.sub_key = Some(sub_key.into());
        self.cache = None;
    }

    pub fn img_key_ref(&self) -> Option<&str> {
        self.img_key.as_deref()
    }

    pub fn sub_key_ref(&self) -> Option<&str> {
        self.sub_key.as_deref()
    }

    pub fn has_keys(&self) -> bool {
        self.img_key.is_some() && self.sub_key.is_some()
    }

    /// Extract key token from a wbi img/sub URL (`.../bfs/wbi/{key}.png`).
    pub fn key_from_url(url: &str) -> Option<String> {
        let file = url.rsplit('/').next()?;
        let key = file.split('.').next()?;
        if key.is_empty() {
            None
        } else {
            Some(key.to_string())
        }
    }

    pub fn set_keys_from_urls(&mut self, img_url: &str, sub_url: &str) -> Result<(), &'static str> {
        let img = Self::key_from_url(img_url).ok_or("invalid wbi img_url")?;
        let sub = Self::key_from_url(sub_url).ok_or("invalid wbi sub_url")?;
        self.set_keys(img, sub);
        Ok(())
    }

    pub fn mixin_key(img_key: &str, sub_key: &str) -> String {
        let raw = format!("{img_key}{sub_key}");
        let bytes: Vec<u8> = raw.bytes().collect();
        let mut out = String::new();
        for &idx in MIXIN_KEY_ENC_TAB.iter().take(32) {
            if let Some(&b) = bytes.get(idx) {
                out.push(b as char);
            }
        }
        out
    }

    fn filtered_value(value: &str) -> String {
        value
            .chars()
            .filter(|c| !matches!(c, '!' | '\'' | '(' | ')' | '*'))
            .collect()
    }

    /// Sign params in-place: inject `wts` / `w_rid`.
    pub fn sign(&self, params: &mut BTreeMap<String, String>, mixin_key: &str, wts: i64) {
        params.insert("wts".into(), wts.to_string());
        // BTreeMap is already sorted by key.
        let query = params
            .iter()
            .filter(|(k, _)| k.as_str() != "w_rid")
            .map(|(k, v)| format!("{k}={}", Self::filtered_value(v)))
            .collect::<Vec<_>>()
            .join("&");
        let raw = format!("{query}{mixin_key}");
        let mut hasher = Md5::new();
        hasher.update(raw.as_bytes());
        let rid = hex::encode(hasher.finalize());
        params.insert("w_rid".into(), rid);
    }

    pub fn sign_with_keys(
        &mut self,
        params: &mut BTreeMap<String, String>,
        wts: i64,
    ) -> Result<(), &'static str> {
        let img = self.img_key.as_deref().ok_or("missing img_key")?;
        let sub = self.sub_key.as_deref().ok_or("missing sub_key")?;
        let day = (wts / 86_400) as u32;
        let mixin = match &self.cache {
            Some((d, key)) if *d == day => key.clone(),
            _ => {
                let key = Self::mixin_key(img, sub);
                self.cache = Some((day, key.clone()));
                key
            }
        };
        self.sign(params, &mixin, wts);
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn mixin_key_length() {
        let key = WbiSigner::mixin_key("imgxxxxxxxx", "subyyyyyyyy");
        assert!(!key.is_empty());
        assert!(key.len() <= 32);
    }

    #[test]
    fn key_from_url_ok() {
        let k = WbiSigner::key_from_url(
            "https://i0.hdslb.com/bfs/wbi/7cd084941338484aae1ad9425b84077c.png",
        )
        .unwrap();
        assert_eq!(k, "7cd084941338484aae1ad9425b84077c");
    }

    #[test]
    fn sign_injects_w_rid() {
        let mut signer = WbiSigner::new();
        signer.set_keys(
            "7cd084941338484aae1ad9425b84077c",
            "4932caff0ff746eab6f01bf08b70ac45",
        );
        let mut params = BTreeMap::new();
        params.insert("foo".into(), "bar".into());
        signer.sign_with_keys(&mut params, 1_700_000_000).unwrap();
        assert!(params.contains_key("wts"));
        assert_eq!(params.get("w_rid").map(|s| s.len()), Some(32));
    }
}
