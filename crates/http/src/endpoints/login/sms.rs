//! SMS captcha + login endpoints.

use super::types::*;
use crate::client::{BiliClient, RequestOptions};
use crate::error::{Error, Result};
use crate::response::parse_bili_json;
use auth::PASS_BASE;
use serde_json::Value;
use std::collections::BTreeMap;

use super::LoginApi;

impl LoginApi {
    pub async fn captcha(client: &BiliClient) -> Result<CaptchaParams> {
        let url = BiliClient::resolve_url(PASS_BASE, "/x/passport-login/captcha?source=main_web");
        let resp = client
            .get_bili::<CaptchaData>(&url, BTreeMap::new(), RequestOptions::default())
            .await?;
        let data = resp.into_data()?;
        let gee = data
            .geetest
            .ok_or_else(|| Error::Parse("captcha missing geetest".into()))?;
        if data.token.is_empty() || gee.gt.is_empty() || gee.challenge.is_empty() {
            return Err(Error::Parse("captcha fields incomplete".into()));
        }
        Ok(CaptchaParams {
            token: data.token,
            gt: gee.gt,
            challenge: gee.challenge,
            captcha_type: if data.r#type.is_empty() {
                "geetest".into()
            } else {
                data.r#type
            },
        })
    }

    /// Send SMS verification code (App passport API + AppSign).
    ///
    /// `cid` is the international dialing code (中国大陆 = 86), matching PiliPlus.
    pub async fn sms_send(
        client: &BiliClient,
        req: &SmsSendRequest<'_>,
    ) -> Result<SmsSendResult> {
        let url = BiliClient::resolve_url(PASS_BASE, "/x/passport-login/sms/send");
        let mut params = BTreeMap::new();
        params.insert("cid".into(), req.cid.to_string());
        params.insert("tel".into(), req.tel.to_string());
        params.insert("login_session_id".into(), req.login_session_id.to_string());
        params.insert("recaptcha_token".into(), req.recaptcha_token.to_string());
        params.insert("gee_challenge".into(), req.gee_challenge.to_string());
        params.insert("gee_validate".into(), req.gee_validate.to_string());
        params.insert("gee_seccode".into(), req.gee_seccode.to_string());
        params.insert("channel".into(), "bili".into());
        params.insert("buvid".into(), req.buvid.to_string());
        params.insert("local_id".into(), req.local_id.to_string());
        params.insert(
            "statistics".into(),
            r#"{"appId":1,"platform":3,"version":"7.27.0","abtest":""}"#.into(),
        );

        let mut opts = RequestOptions::app_sign();
        opts.prefer_app_ua = true;
        let resp = client
            .post_form_bili::<SmsSendData>(&url, params, opts)
            .await?;
        let data = resp.into_data()?;
        if data.captcha_key.is_empty() {
            return Err(Error::Parse("sms send missing captcha_key".into()));
        }
        Ok(SmsSendResult {
            captcha_key: data.captcha_key,
        })
    }

    /// Complete SMS login (App passport API + AppSign).
    pub async fn sms_login(
        client: &BiliClient,
        req: &SmsLoginRequest<'_>,
    ) -> Result<LoginSuccess> {
        let url = BiliClient::resolve_url(PASS_BASE, "/x/passport-login/login/sms");
        let mut params = BTreeMap::new();
        params.insert("cid".into(), req.cid.to_string());
        params.insert("tel".into(), req.tel.to_string());
        params.insert("login_session_id".into(), req.login_session_id.to_string());
        params.insert("code".into(), req.code.to_string());
        params.insert("captcha_key".into(), req.captcha_key.to_string());

        // Need Set-Cookie as well as body cookie_info.
        let (text, headers) = client
            .post_form_raw(&url, params, RequestOptions::app_sign())
            .await?;
        let resp = parse_bili_json::<Value>(&text)?;
        resp.ensure_ok()?;
        let data: LoginData = serde_json::from_value(
            resp.data
                .ok_or_else(|| Error::Parse("sms login missing data".into()))?,
        )
        .map_err(|e| Error::Parse(e.to_string()))?;
        parse_login_success(data, Some(&headers))
    }

}
