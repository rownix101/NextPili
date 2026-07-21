//! Login domain types and wire serde.

use crate::error::{Error, Result};
use auth::CookieJar;
use reqwest::header::HeaderMap;
use serde::Deserialize;

/// QR code session started via TV/HD passport API.
#[derive(Debug, Clone)]
pub struct QrStart {
    pub url: String,
    pub auth_code: String,
}

/// Result of one poll tick.
#[derive(Debug, Clone)]
pub enum QrPollStatus {
    /// Waiting for scan (86039).
    Pending,
    /// Scanned, waiting for confirm (86090).
    Scanned,
    /// QR expired (86038).
    Expired,
    /// Login success.
    Confirmed(LoginSuccess),
    /// Other business code.
    Other { code: i32, message: String },
}

/// Shared success payload after QR / SMS login.
#[derive(Debug, Clone)]
pub struct LoginSuccess {
    pub mid: i64,
    pub access_key: Option<String>,
    pub refresh_token: Option<String>,
    pub cookie_jar: CookieJar,
    pub expires_in: Option<i64>,
}

/// Captcha / geetest parameters for SMS (or password) login.
#[derive(Debug, Clone)]
pub struct CaptchaParams {
    pub token: String,
    pub gt: String,
    pub challenge: String,
    pub captcha_type: String,
}

/// Result of sending an SMS code.
#[derive(Debug, Clone)]
pub struct SmsSendResult {
    pub captcha_key: String,
}

/// RSA key material from `/x/passport-login/web/key`.
#[derive(Debug, Clone)]
pub struct PasswordKey {
    pub hash: String,
    pub key: String,
}

/// Password login result (success or safe-center phone verify).
#[derive(Debug, Clone)]
pub enum PasswordLoginOutcome {
    Success(LoginSuccess),
    /// `data.status == 2` — need bound phone SMS via safe center.
    NeedPhoneVerify {
        message: String,
        risk_url: String,
        tmp_token: String,
        request_id: String,
        source: String,
    },
}

/// Safe-center account snapshot for risk verify UI.
#[derive(Debug, Clone)]
pub struct SafeCenterInfo {
    pub hide_tel: String,
    pub hide_mail: String,
    pub tel_verify: bool,
    pub mail_verify: bool,
}

/// Captcha pre-check for safe-center SMS.
#[derive(Debug, Clone)]
pub struct SafeCenterCaptcha {
    pub recaptcha_token: String,
    pub gee_gt: String,
    pub gee_challenge: String,
}

#[derive(Debug, Deserialize)]
pub(crate) struct AuthCodeData {
    pub(crate) url: String,
    pub(crate) auth_code: String,
}

#[derive(Debug, Deserialize)]
pub(crate) struct CaptchaData {
    #[serde(default)]
    pub(crate) token: String,
    #[serde(default)]
    pub(crate) r#type: String,
    #[serde(default)]
    pub(crate) geetest: Option<GeetestData>,
}

#[derive(Debug, Deserialize)]
pub(crate) struct GeetestData {
    #[serde(default)]
    pub(crate) gt: String,
    #[serde(default)]
    pub(crate) challenge: String,
}

#[derive(Debug, Deserialize)]
pub(crate) struct SmsSendData {
    #[serde(default)]
    pub(crate) captcha_key: String,
}

#[derive(Debug, Deserialize)]
pub(crate) struct PollTokenInfo {
    #[serde(default)]
    pub(crate) mid: i64,
    #[serde(default)]
    pub(crate) access_token: Option<String>,
    #[serde(default)]
    pub(crate) refresh_token: Option<String>,
    #[serde(default)]
    pub(crate) expires_in: Option<i64>,
}

#[derive(Debug, Deserialize)]
pub(crate) struct PollCookieItem {
    pub(crate) name: String,
    pub(crate) value: String,
}

#[derive(Debug, Deserialize)]
pub(crate) struct PollCookieInfo {
    #[serde(default)]
    pub(crate) cookies: Vec<PollCookieItem>,
}

#[derive(Debug, Deserialize)]
pub(crate) struct LoginData {
    #[serde(default)]
    pub(crate) mid: Option<i64>,
    #[serde(default)]
    pub(crate) access_token: Option<String>,
    #[serde(default)]
    pub(crate) refresh_token: Option<String>,
    #[serde(default)]
    pub(crate) expires_in: Option<i64>,
    #[serde(default)]
    pub(crate) token_info: Option<PollTokenInfo>,
    #[serde(default)]
    pub(crate) cookie_info: Option<PollCookieInfo>,
    /// 0 = success; non-zero often means extra verify (phone/email).
    #[serde(default)]
    pub(crate) status: Option<i32>,
    #[serde(default)]
    pub(crate) message: Option<String>,
    #[serde(default)]
    pub(crate) url: Option<String>,
}

#[derive(Debug, Deserialize)]
pub(crate) struct PasswordKeyData {
    #[serde(default)]
    pub(crate) hash: String,
    #[serde(default)]
    pub(crate) key: String,
}

#[derive(Debug, Deserialize)]
pub(crate) struct SafeCenterAccountInfo {
    #[serde(default)]
    pub(crate) hide_tel: String,
    #[serde(default)]
    pub(crate) hide_mail: String,
    #[serde(default)]
    pub(crate) tel_verify: bool,
    #[serde(default)]
    pub(crate) mail_verify: bool,
}

#[derive(Debug, Deserialize)]
pub(crate) struct SafeCenterInfoData {
    #[serde(default)]
    pub(crate) account_info: Option<SafeCenterAccountInfo>,
}

#[derive(Debug, Deserialize)]
pub(crate) struct SafeCenterPreCaptchaData {
    #[serde(default)]
    pub(crate) recaptcha_token: String,
    #[serde(default)]
    pub(crate) gee_gt: String,
    #[serde(default)]
    pub(crate) gee_challenge: String,
}

#[derive(Debug, Deserialize)]
pub(crate) struct SafeCenterSmsSendData {
    #[serde(default)]
    pub(crate) captcha_key: String,
}

#[derive(Debug, Deserialize)]
pub(crate) struct SafeCenterSmsVerifyData {
    #[serde(default)]
    pub(crate) code: String,
}


pub struct SmsSendRequest<'a> {
    pub cid: i32,
    pub tel: &'a str,
    pub login_session_id: &'a str,
    pub recaptcha_token: &'a str,
    pub gee_challenge: &'a str,
    pub gee_validate: &'a str,
    pub gee_seccode: &'a str,
    pub buvid: &'a str,
    pub local_id: &'a str,
}

#[derive(Debug, Clone)]
pub struct SmsLoginRequest<'a> {
    pub cid: i32,
    pub tel: &'a str,
    pub login_session_id: &'a str,
    pub code: &'a str,
    pub captcha_key: &'a str,
}

#[derive(Debug, Clone)]
pub struct PasswordLoginRequest<'a> {
    pub username: &'a str,
    pub password: &'a str,
    /// From captcha API `token` (optional if server allows login without geetest).
    pub recaptcha_token: &'a str,
    pub gee_challenge: &'a str,
    pub gee_validate: &'a str,
    pub gee_seccode: &'a str,
}

#[derive(Debug, Clone)]
pub struct SafeCenterSmsSendRequest<'a> {
    pub tmp_code: &'a str,
    pub gee_challenge: &'a str,
    pub gee_validate: &'a str,
    pub gee_seccode: &'a str,
    pub recaptcha_token: &'a str,
    pub referer_url: &'a str,
    pub sms_type: Option<&'a str>,
}

#[derive(Debug, Clone)]
pub struct SafeCenterSmsVerifyRequest<'a> {
    pub code: &'a str,
    pub tmp_code: &'a str,
    pub request_id: &'a str,
    pub source: &'a str,
    pub captcha_key: &'a str,
    pub referer_url: &'a str,
    pub r#type: Option<&'a str>,
}

pub(crate) fn parse_login_success(data: LoginData, headers: Option<&HeaderMap>) -> Result<LoginSuccess> {
    let mut cookie_jar = CookieJar::new();
    if let Some(info) = &data.cookie_info {
        for c in &info.cookies {
            cookie_jar.set(c.name.clone(), c.value.clone());
        }
    }
    if let Some(headers) = headers {
        for val in headers.get_all(reqwest::header::SET_COOKIE) {
            if let Ok(s) = val.to_str() {
                cookie_jar.apply_set_cookie(s);
            }
        }
    }

    let token = data.token_info;
    let mid = data
        .mid
        .or_else(|| token.as_ref().map(|t| t.mid))
        .or_else(|| {
            cookie_jar
                .dede_user_id()
                .and_then(|s| s.parse::<i64>().ok())
        })
        .unwrap_or(0);

    let access_key = data
        .access_token
        .or_else(|| token.as_ref().and_then(|t| t.access_token.clone()));
    let refresh_token = data
        .refresh_token
        .or_else(|| token.as_ref().and_then(|t| t.refresh_token.clone()));
    let expires_in = data
        .expires_in
        .or_else(|| token.as_ref().and_then(|t| t.expires_in));

    if !cookie_jar.has_login_session() && access_key.is_none() {
        return Err(Error::Parse(
            "login success missing cookie and access_key".into(),
        ));
    }

    Ok(LoginSuccess {
        mid,
        access_key,
        refresh_token,
        cookie_jar,
        expires_in,
    })
}


