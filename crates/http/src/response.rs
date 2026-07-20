use crate::error::{Error, Result};
use domain::map_bili_code;
use serde::de::DeserializeOwned;
use serde::{Deserialize, Serialize};
use serde_json::Value;

/// Generic Bilibili JSON envelope.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BiliResponse<T = Value> {
    pub code: i32,
    #[serde(default)]
    pub message: String,
    #[serde(default)]
    pub msg: Option<String>,
    #[serde(default)]
    pub ttl: Option<i32>,
    /// Payload for most endpoints (serde treats Option as optional).
    pub data: Option<T>,
    /// Some PGC endpoints put payload in `result` instead of `data`.
    pub result: Option<T>,
}

impl<T> BiliResponse<T> {
    pub fn message_text(&self) -> &str {
        if !self.message.is_empty() && self.message != "0" {
            return &self.message;
        }
        self.msg.as_deref().unwrap_or(&self.message)
    }

    pub fn into_data(self) -> Result<T> {
        map_bili_code(self.code, self.message_text()).map_err(Error::from)?;
        self.data
            .or(self.result)
            .ok_or_else(|| Error::Parse("missing data/result in bili response".into()))
    }

    pub fn into_data_opt(self) -> Result<Option<T>> {
        map_bili_code(self.code, self.message_text()).map_err(Error::from)?;
        Ok(self.data.or(self.result))
    }

    pub fn ensure_ok(&self) -> Result<()> {
        map_bili_code(self.code, self.message_text()).map_err(Error::from)
    }
}

/// Parse raw JSON text into [`BiliResponse`].
pub fn parse_bili_json<T: DeserializeOwned>(text: &str) -> Result<BiliResponse<T>> {
    serde_json::from_str(text).map_err(|e| Error::Parse(e.to_string()))
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn success_data() {
        let raw = r#"{"code":0,"message":"0","data":{"mid":1}}"#;
        let resp: BiliResponse<Value> = parse_bili_json(raw).unwrap();
        let data = resp.into_data().unwrap();
        assert_eq!(data["mid"], 1);
    }

    #[test]
    fn maps_unauth() {
        let raw = r#"{"code":-101,"message":"账号未登录","data":null}"#;
        let resp: BiliResponse<Value> = parse_bili_json(raw).unwrap();
        let err = resp.into_data().unwrap_err();
        assert!(matches!(err, Error::Domain(domain::Error::Unauthenticated)));
    }

    #[test]
    fn result_fallback() {
        let v = json!({"code":0,"message":"0","result":{"ok":true}});
        let resp: BiliResponse<Value> = serde_json::from_value(v).unwrap();
        let data = resp.into_data().unwrap();
        assert_eq!(data["ok"], true);
    }
}
