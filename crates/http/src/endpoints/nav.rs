use crate::client::{BiliClient, RequestOptions};
use crate::error::Result;
use crate::response::BiliResponse;
use auth::{API_BASE, Account, WbiSigner};
use serde::Deserialize;
use serde_json::Value;

#[derive(Debug, Clone)]
pub struct NavInfo {
    pub is_login: bool,
    pub mid: i64,
    pub uname: String,
    pub face: String,
    pub money: f64,
    pub img_url: Option<String>,
    pub sub_url: Option<String>,
    pub raw: Value,
}

#[derive(Debug, Default, Deserialize)]
struct NavData {
    #[serde(default, rename = "isLogin")]
    is_login: bool,
    #[serde(default)]
    mid: i64,
    #[serde(default)]
    uname: String,
    #[serde(default)]
    face: String,
    #[serde(default)]
    money: f64,
    #[serde(default)]
    wbi_img: Option<WbiImg>,
}

#[derive(Debug, Deserialize)]
struct WbiImg {
    #[serde(default)]
    img_url: String,
    #[serde(default)]
    sub_url: String,
}

/// Extract `data` from a nav response.
///
/// Bilibili returns `code = -101` (`账号未登录`) for anonymous callers even
/// though the payload still contains the WBI keys and `isLogin: false`.
/// Treat that as a valid guest nav instead of an auth failure.
fn parse_nav_payload(resp: BiliResponse<Value>) -> Result<Value> {
    match resp.code {
        0 | -101 => Ok(resp.data.or(resp.result).unwrap_or(Value::Null)),
        _ => {
            resp.ensure_ok()?;
            unreachable!("ensure_ok returns Err for any non-zero, non-guest code")
        }
    }
}

/// Nav endpoint: user info + WBI keys.
pub struct NavApi;

impl NavApi {
    pub async fn fetch(
        client: &BiliClient,
        account: Option<&Account>,
        device_buvid3: Option<&str>,
    ) -> Result<NavInfo> {
        let url = BiliClient::resolve_url(API_BASE, "/x/web-interface/nav");
        let opts = if let Some(acc) = account {
            RequestOptions::web_cookie(acc, device_buvid3)
        } else {
            RequestOptions {
                device_buvid3,
                auth: crate::middleware::AuthMode::OptionalLogin,
                ..RequestOptions::default()
            }
        };

        let resp = client
            .get_bili::<Value>(&url, Default::default(), opts)
            .await?;
        let raw = parse_nav_payload(resp)?;
        let data: NavData = if raw.is_null() {
            NavData::default()
        } else {
            serde_json::from_value(raw.clone())
                .map_err(|e| crate::error::Error::Parse(e.to_string()))?
        };

        Ok(NavInfo {
            is_login: data.is_login || data.mid > 0,
            mid: data.mid,
            uname: data.uname,
            face: data.face,
            money: data.money,
            img_url: data.wbi_img.as_ref().map(|w| w.img_url.clone()),
            sub_url: data.wbi_img.as_ref().map(|w| w.sub_url.clone()),
            raw,
        })
    }

    /// Fetch nav and update WBI signer keys when present.
    pub async fn refresh_wbi(
        client: &BiliClient,
        wbi: &mut WbiSigner,
        account: Option<&Account>,
        device_buvid3: Option<&str>,
    ) -> Result<NavInfo> {
        let info = Self::fetch(client, account, device_buvid3).await?;
        if let (Some(img), Some(sub)) = (&info.img_url, &info.sub_url)
            && let Err(e) = wbi.set_keys_from_urls(img, sub)
        {
            tracing::warn!(error = e, "failed to parse wbi keys from nav");
        }
        Ok(info)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn raw_json(value: Value) -> String {
        value.to_string()
    }

    #[test]
    fn guest_nav_keeps_wbi_payload() {
        let raw = raw_json(json!({
            "code": -101,
            "message": "账号未登录",
            "data": {
                "isLogin": false,
                "wbi_img": {
                    "img_url": "https://i0.hdslb.com/bfs/wbi/img.png",
                    "sub_url": "https://i0.hdslb.com/bfs/wbi/sub.png"
                }
            }
        }));
        let resp: BiliResponse<Value> = serde_json::from_str(&raw).unwrap();
        let value = parse_nav_payload(resp).unwrap();
        let data: NavData = serde_json::from_value(value).unwrap();
        assert!(!data.is_login);
        assert_eq!(
            data.wbi_img.as_ref().unwrap().img_url,
            "https://i0.hdslb.com/bfs/wbi/img.png"
        );
    }

    #[test]
    fn guest_nav_without_data_is_empty() {
        let raw = raw_json(json!({"code": -101, "message": "账号未登录", "data": null}));
        let resp: BiliResponse<Value> = serde_json::from_str(&raw).unwrap();
        let raw = parse_nav_payload(resp).unwrap();
        let data: NavData = if raw.is_null() {
            NavData::default()
        } else {
            serde_json::from_value(raw).unwrap()
        };
        assert!(!data.is_login);
    }

    #[test]
    fn nav_api_error_is_preserved() {
        let raw = raw_json(json!({"code": -400, "message": "请求错误", "data": null}));
        let resp: BiliResponse<Value> = serde_json::from_str(&raw).unwrap();
        assert!(parse_nav_payload(resp).is_err());
    }
}
