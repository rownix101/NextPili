//! QR TV/HD login endpoints.

use super::types::*;
use crate::client::{BiliClient, RequestOptions};
use crate::error::{Error, Result};
use auth::{MOBI_APP_ANDROID_HD, PASS_BASE, PLATFORM_ANDROID};
use serde_json::Value;
use std::collections::BTreeMap;

use super::LoginApi;

impl LoginApi {
    pub async fn qr_start(client: &BiliClient, local_id: &str) -> Result<QrStart> {
        let url = BiliClient::resolve_url(PASS_BASE, "/x/passport-tv-login/qrcode/auth_code");
        let mut params = BTreeMap::new();
        params.insert("local_id".into(), local_id.to_string());
        params.insert("platform".into(), PLATFORM_ANDROID.into());
        params.insert("mobi_app".into(), MOBI_APP_ANDROID_HD.into());

        let resp = client
            .post_form_bili::<AuthCodeData>(&url, params, RequestOptions::app_sign())
            .await?;
        let data = resp.into_data()?;
        Ok(QrStart {
            url: data.url,
            auth_code: data.auth_code,
        })
    }

    pub async fn qr_poll(
        client: &BiliClient,
        auth_code: &str,
        local_id: &str,
    ) -> Result<QrPollStatus> {
        let url = BiliClient::resolve_url(PASS_BASE, "/x/passport-tv-login/qrcode/poll");
        let mut params = BTreeMap::new();
        params.insert("auth_code".into(), auth_code.to_string());
        params.insert("local_id".into(), local_id.to_string());
        params.insert("platform".into(), PLATFORM_ANDROID.into());
        params.insert("mobi_app".into(), MOBI_APP_ANDROID_HD.into());

        let resp = client
            .post_form_bili::<Value>(&url, params, RequestOptions::app_sign())
            .await?;

        match resp.code {
            0 => {
                let data: LoginData = serde_json::from_value(
                    resp.data
                        .clone()
                        .ok_or_else(|| Error::Parse("poll success missing data".into()))?,
                )
                .map_err(|e| Error::Parse(e.to_string()))?;
                Ok(QrPollStatus::Confirmed(parse_login_success(data, None)?))
            }
            86039 => Ok(QrPollStatus::Pending),
            86090 => Ok(QrPollStatus::Scanned),
            86038 => Ok(QrPollStatus::Expired),
            code => Ok(QrPollStatus::Other {
                code,
                message: resp.message_text().to_string(),
            }),
        }
    }
}
