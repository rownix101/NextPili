//! Password login and safe-center risk verify.

use super::types::*;
use crate::client::{BiliClient, RequestOptions};
use crate::error::{Error, Result};
use crate::response::parse_bili_json;
use auth::{encrypt_password, MOBI_APP_ANDROID_HD, PASS_BASE, PLATFORM_ANDROID};
use serde_json::Value;
use std::collections::BTreeMap;

use super::LoginApi;

impl LoginApi {
    pub async fn password_key(client: &BiliClient) -> Result<PasswordKey> {
        let url = BiliClient::resolve_url(PASS_BASE, "/x/passport-login/web/key");
        let resp = client
            .get_bili::<PasswordKeyData>(&url, BTreeMap::new(), RequestOptions::default())
            .await?;
        let data = resp.into_data()?;
        if data.hash.is_empty() || data.key.is_empty() {
            return Err(Error::Parse("password key incomplete".into()));
        }
        Ok(PasswordKey {
            hash: data.hash,
            key: data.key,
        })
    }

    /// App password login: RSA(hash+password) + optional geetest + AppSign.
    ///
    /// On risk (`status == 2`) returns [`PasswordLoginOutcome::NeedPhoneVerify`].
    pub async fn password_login(
        client: &BiliClient,
        req: &PasswordLoginRequest<'_>,
    ) -> Result<PasswordLoginOutcome> {
        let key = Self::password_key(client).await?;
        let encrypted = encrypt_password(&key.key, &key.hash, req.password)
            .map_err(|e| Error::Auth(e.to_string()))?;

        let url = BiliClient::resolve_url(PASS_BASE, "/x/passport-login/oauth2/login");
        let mut params = BTreeMap::new();
        params.insert("username".into(), req.username.to_string());
        params.insert("password".into(), encrypted);
        params.insert("keep".into(), "0".into());
        params.insert("mobi_app".into(), MOBI_APP_ANDROID_HD.into());
        params.insert("platform".into(), PLATFORM_ANDROID.into());
        params.insert("device".into(), "phone".into());
        params.insert("channel".into(), "bili".into());
        params.insert("permission".into(), "ALL".into());
        params.insert("subid".into(), "1".into());
        // PiliPlus field names for geetest on oauth2 login.
        if !req.recaptcha_token.is_empty() {
            params.insert("recaptcha_token".into(), req.recaptcha_token.to_string());
            params.insert("gee_challenge".into(), req.gee_challenge.to_string());
            params.insert("gee_validate".into(), req.gee_validate.to_string());
            params.insert("gee_seccode".into(), req.gee_seccode.to_string());
            // Web-style aliases kept for some passport builds.
            params.insert("token".into(), req.recaptcha_token.to_string());
            params.insert("challenge".into(), req.gee_challenge.to_string());
            params.insert("validate".into(), req.gee_validate.to_string());
            params.insert("seccode".into(), req.gee_seccode.to_string());
        }

        let mut opts = RequestOptions::app_sign();
        opts.prefer_app_ua = true;
        let (text, headers) = client.post_form_raw(&url, params, opts).await?;
        let resp = parse_bili_json::<Value>(&text)?;
        resp.ensure_ok()?;
        let data: LoginData = serde_json::from_value(
            resp.data
                .ok_or_else(|| Error::Parse("password login missing data".into()))?,
        )
        .map_err(|e| Error::Parse(e.to_string()))?;

        let status = data.status.unwrap_or(0);
        if status == 2 {
            let risk_url = data.url.clone().unwrap_or_default();
            let parsed = url::Url::parse(&risk_url).ok();
            let q = |k: &str| {
                parsed
                    .as_ref()
                    .and_then(|u| u.query_pairs().find(|(n, _)| n == k).map(|(_, v)| v.into_owned()))
                    .unwrap_or_default()
            };
            let tmp_token = q("tmp_token");
            let request_id = q("request_id");
            let source = {
                let s = q("source");
                if s.is_empty() {
                    "risk".into()
                } else {
                    s
                }
            };
            if tmp_token.is_empty() || risk_url.is_empty() {
                return Err(Error::Auth(
                    "密码登录需二次验证，但未返回可用的 risk url / tmp_token".into(),
                ));
            }
            let message = data
                .message
                .clone()
                .filter(|s| !s.is_empty())
                .unwrap_or_else(|| "本次登录环境存在风险, 需使用手机号进行验证".into());
            return Ok(PasswordLoginOutcome::NeedPhoneVerify {
                message,
                risk_url,
                tmp_token,
                request_id,
                source,
            });
        }
        if status != 0 {
            let msg = data
                .message
                .as_deref()
                .filter(|s| !s.is_empty())
                .unwrap_or("需要额外验证，请改用短信或扫码登录");
            return Err(Error::Auth(format!(
                "密码登录失败 (status={status}): {msg}"
            )));
        }

        Ok(PasswordLoginOutcome::Success(parse_login_success(
            data,
            Some(&headers),
        )?))
    }

    /// Safe center: account verify options for `tmp_code` (= risk `tmp_token`).
    pub async fn safe_center_info(client: &BiliClient, tmp_code: &str) -> Result<SafeCenterInfo> {
        let url = BiliClient::resolve_url(PASS_BASE, "/x/safecenter/user/info");
        let mut params = BTreeMap::new();
        params.insert("tmp_code".into(), tmp_code.to_string());
        let resp = client
            .get_bili::<SafeCenterInfoData>(&url, params, RequestOptions::default())
            .await?;
        let data = resp.into_data()?;
        let info = data
            .account_info
            .ok_or_else(|| Error::Parse("safe center missing account_info".into()))?;
        Ok(SafeCenterInfo {
            hide_tel: info.hide_tel,
            hide_mail: info.hide_mail,
            tel_verify: info.tel_verify,
            mail_verify: info.mail_verify,
        })
    }

    /// Safe center pre-captcha (gee_gt / challenge / recaptcha_token).
    pub async fn safe_center_pre_captcha(client: &BiliClient) -> Result<SafeCenterCaptcha> {
        let url = BiliClient::resolve_url(PASS_BASE, "/x/safecenter/captcha/pre");
        let resp = client
            .post_form_bili::<SafeCenterPreCaptchaData>(
                &url,
                BTreeMap::new(),
                RequestOptions::default(),
            )
            .await?;
        let data = resp.into_data()?;
        if data.recaptcha_token.is_empty()
            || data.gee_gt.is_empty()
            || data.gee_challenge.is_empty()
        {
            return Err(Error::Parse("safe center pre captcha incomplete".into()));
        }
        Ok(SafeCenterCaptcha {
            recaptcha_token: data.recaptcha_token,
            gee_gt: data.gee_gt,
            gee_challenge: data.gee_challenge,
        })
    }

    /// Send safe-center SMS for login phone check.
    pub async fn safe_center_sms_send(
        client: &BiliClient,
        req: &SafeCenterSmsSendRequest<'_>,
    ) -> Result<SmsSendResult> {
        let url = BiliClient::resolve_url(PASS_BASE, "/x/safecenter/common/sms/send");
        let mut params = BTreeMap::new();
        params.insert("disable_rcmd".into(), "0".into());
        params.insert(
            "sms_type".into(),
            req.sms_type.unwrap_or("loginTelCheck").into(),
        );
        params.insert("tmp_code".into(), req.tmp_code.into());
        params.insert("gee_challenge".into(), req.gee_challenge.into());
        params.insert("gee_seccode".into(), req.gee_seccode.into());
        params.insert("gee_validate".into(), req.gee_validate.into());
        params.insert("recaptcha_token".into(), req.recaptcha_token.into());

        let mut opts = RequestOptions::app_sign();
        if !req.referer_url.is_empty() {
            opts = opts.with_referer(req.referer_url);
        }
        let resp = client
            .post_form_bili::<SafeCenterSmsSendData>(&url, params, opts)
            .await?;
        let data = resp.into_data()?;
        if data.captcha_key.is_empty() {
            return Err(Error::Parse("safe center sms missing captcha_key".into()));
        }
        Ok(SmsSendResult {
            captcha_key: data.captcha_key,
        })
    }

    /// Verify safe-center SMS; returns oauth `code` for access_token exchange.
    pub async fn safe_center_sms_verify(
        client: &BiliClient,
        req: &SafeCenterSmsVerifyRequest<'_>,
    ) -> Result<String> {
        let url = BiliClient::resolve_url(PASS_BASE, "/x/safecenter/login/tel/verify");
        let mut params = BTreeMap::new();
        params.insert("type".into(), req.r#type.unwrap_or("loginTelCheck").into());
        params.insert("code".into(), req.code.into());
        params.insert("tmp_code".into(), req.tmp_code.into());
        params.insert("request_id".into(), req.request_id.into());
        params.insert("source".into(), req.source.into());
        params.insert("captcha_key".into(), req.captcha_key.into());

        let mut opts = RequestOptions::app_sign();
        if !req.referer_url.is_empty() {
            opts = opts.with_referer(req.referer_url);
        }
        let resp = client
            .post_form_bili::<SafeCenterSmsVerifyData>(&url, params, opts)
            .await?;
        let data = resp.into_data()?;
        if data.code.is_empty() {
            return Err(Error::Parse("safe center verify missing oauth code".into()));
        }
        Ok(data.code)
    }

    /// Exchange authorization code for access_token + cookies.
    pub async fn oauth2_access_token(
        client: &BiliClient,
        code: &str,
        local_id: &str,
        buvid: &str,
    ) -> Result<LoginSuccess> {
        let url = BiliClient::resolve_url(PASS_BASE, "/x/passport-login/oauth2/access_token");
        let mut params = BTreeMap::new();
        params.insert("code".into(), code.into());
        params.insert("grant_type".into(), "authorization_code".into());
        params.insert("disable_rcmd".into(), "0".into());
        params.insert("local_id".into(), local_id.into());
        params.insert("buvid".into(), buvid.into());
        params.insert("mobi_app".into(), MOBI_APP_ANDROID_HD.into());
        params.insert("platform".into(), PLATFORM_ANDROID.into());

        let mut opts = RequestOptions::app_sign();
        opts.prefer_app_ua = true;
        let (text, headers) = client.post_form_raw(&url, params, opts).await?;
        let resp = parse_bili_json::<Value>(&text)?;
        resp.ensure_ok()?;
        let data: LoginData = serde_json::from_value(
            resp.data
                .ok_or_else(|| Error::Parse("oauth2 access_token missing data".into()))?,
        )
        .map_err(|e| Error::Parse(e.to_string()))?;
        parse_login_success(data, Some(&headers))
    }
}
