use crate::client::{BiliClient, RequestOptions};
use crate::error::Result;
use auth::{Account, API_BASE, WbiSigner};
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

#[derive(Debug, Deserialize)]
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
        let raw = resp.into_data()?;
        let data: NavData = serde_json::from_value(raw.clone())
            .map_err(|e| crate::error::Error::Parse(e.to_string()))?;

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
