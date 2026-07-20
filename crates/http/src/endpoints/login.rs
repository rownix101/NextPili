use crate::client::{BiliClient, RequestOptions};
use crate::error::{Error, Result};
use crate::response::parse_bili_json;
use auth::{
    encrypt_password, CookieJar, MOBI_APP_ANDROID_HD, PASS_BASE, PLATFORM_ANDROID,
};
use reqwest::header::HeaderMap;
use serde::Deserialize;
use serde_json::Value;
use std::collections::BTreeMap;

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
struct AuthCodeData {
    url: String,
    auth_code: String,
}

#[derive(Debug, Deserialize)]
struct CaptchaData {
    #[serde(default)]
    token: String,
    #[serde(default)]
    r#type: String,
    #[serde(default)]
    geetest: Option<GeetestData>,
}

#[derive(Debug, Deserialize)]
struct GeetestData {
    #[serde(default)]
    gt: String,
    #[serde(default)]
    challenge: String,
}

#[derive(Debug, Deserialize)]
struct SmsSendData {
    #[serde(default)]
    captcha_key: String,
}

#[derive(Debug, Deserialize)]
struct PollTokenInfo {
    #[serde(default)]
    mid: i64,
    #[serde(default)]
    access_token: Option<String>,
    #[serde(default)]
    refresh_token: Option<String>,
    #[serde(default)]
    expires_in: Option<i64>,
}

#[derive(Debug, Deserialize)]
struct PollCookieItem {
    name: String,
    value: String,
}

#[derive(Debug, Deserialize)]
struct PollCookieInfo {
    #[serde(default)]
    cookies: Vec<PollCookieItem>,
}

#[derive(Debug, Deserialize)]
struct LoginData {
    #[serde(default)]
    mid: Option<i64>,
    #[serde(default)]
    access_token: Option<String>,
    #[serde(default)]
    refresh_token: Option<String>,
    #[serde(default)]
    expires_in: Option<i64>,
    #[serde(default)]
    token_info: Option<PollTokenInfo>,
    #[serde(default)]
    cookie_info: Option<PollCookieInfo>,
    /// 0 = success; non-zero often means extra verify (phone/email).
    #[serde(default)]
    status: Option<i32>,
    #[serde(default)]
    message: Option<String>,
    #[serde(default)]
    url: Option<String>,
}

#[derive(Debug, Deserialize)]
struct PasswordKeyData {
    #[serde(default)]
    hash: String,
    #[serde(default)]
    key: String,
}

#[derive(Debug, Deserialize)]
struct SafeCenterAccountInfo {
    #[serde(default)]
    hide_tel: String,
    #[serde(default)]
    hide_mail: String,
    #[serde(default)]
    tel_verify: bool,
    #[serde(default)]
    mail_verify: bool,
}

#[derive(Debug, Deserialize)]
struct SafeCenterInfoData {
    #[serde(default)]
    account_info: Option<SafeCenterAccountInfo>,
}

#[derive(Debug, Deserialize)]
struct SafeCenterPreCaptchaData {
    #[serde(default)]
    recaptcha_token: String,
    #[serde(default)]
    gee_gt: String,
    #[serde(default)]
    gee_challenge: String,
}

#[derive(Debug, Deserialize)]
struct SafeCenterSmsSendData {
    #[serde(default)]
    captcha_key: String,
}

#[derive(Debug, Deserialize)]
struct SafeCenterSmsVerifyData {
    #[serde(default)]
    code: String,
}

/// Passport login endpoints (QR + SMS + password).
pub struct LoginApi;

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

    /// Fetch geetest captcha parameters for SMS login.
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
    /// `cid` is the passport country **id** (中国大陆 = 1), not the dialing code 86.
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

    /// Fetch RSA public key + salt hash for password login.
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

#[derive(Debug, Clone)]
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

fn parse_login_success(data: LoginData, headers: Option<&HeaderMap>) -> Result<LoginSuccess> {
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

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn parse_success_cookies() {
        let data: LoginData = serde_json::from_value(json!({
            "mid": 123,
            "access_token": "ak",
            "refresh_token": "rt",
            "expires_in": 100,
            "cookie_info": {
                "cookies": [
                    {"name": "SESSDATA", "value": "s"},
                    {"name": "bili_jct", "value": "c"},
                    {"name": "DedeUserID", "value": "123"}
                ]
            }
        }))
        .unwrap();
        let ok = parse_login_success(data, None).unwrap();
        assert_eq!(ok.mid, 123);
        assert_eq!(ok.access_key.as_deref(), Some("ak"));
        assert_eq!(ok.cookie_jar.sessdata(), Some("s"));
    }
}
