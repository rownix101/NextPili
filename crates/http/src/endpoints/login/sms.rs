//! SMS captcha + login endpoints.

use super::types::*;
use crate::client::{BiliClient, RequestOptions};
use crate::error::{Error, Result};
use crate::response::parse_bili_json;
use auth::{MOBI_APP_ANDROID_HD, PASS_BASE, PLATFORM_ANDROID};
use serde_json::Value;
use std::collections::BTreeMap;

use super::LoginApi;

const SMS_STATISTICS: &str = r#"{"appId":5,"platform":3,"version":"2.0.1","abtest":""}"#;
const SMS_BUILD: &str = "2001100";

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

    /// App SMS send (`cid` = dialing code). May return [`SmsSendOutcome::NeedCaptcha`].
    pub async fn sms_send(
        client: &BiliClient,
        req: &SmsSendRequest<'_>,
    ) -> Result<SmsSendOutcome> {
        let url = BiliClient::resolve_url(PASS_BASE, "/x/passport-login/sms/send");
        let mut params = BTreeMap::new();
        params.insert("cid".into(), req.cid.to_string());
        params.insert("tel".into(), req.tel.to_string());
        params.insert("login_session_id".into(), req.login_session_id.to_string());
        params.insert("channel".into(), "master".into());
        params.insert("buvid".into(), req.buvid.to_string());
        params.insert("local_id".into(), req.local_id.to_string());
        params.insert("mobi_app".into(), MOBI_APP_ANDROID_HD.into());
        params.insert("platform".into(), PLATFORM_ANDROID.into());
        params.insert("build".into(), SMS_BUILD.into());
        params.insert("c_locale".into(), "zh_CN".into());
        params.insert("s_locale".into(), "zh_CN".into());
        params.insert("disable_rcmd".into(), "0".into());
        params.insert("statistics".into(), SMS_STATISTICS.into());

        if !req.recaptcha_token.is_empty() {
            params.insert("recaptcha_token".into(), req.recaptcha_token.to_string());
        }
        if !req.gee_challenge.is_empty() {
            params.insert("gee_challenge".into(), req.gee_challenge.to_string());
        }
        if !req.gee_validate.is_empty() {
            params.insert("gee_validate".into(), req.gee_validate.to_string());
        }
        if !req.gee_seccode.is_empty() {
            params.insert("gee_seccode".into(), req.gee_seccode.to_string());
        }

        let mut opts = RequestOptions::app_sign();
        opts.prefer_app_ua = true;
        let (text, _headers) = client.post_form_raw(&url, params, opts).await?;
        let resp = parse_bili_json::<Value>(&text)?;

        if resp.code == 0 {
            let data = resp
                .data
                .clone()
                .ok_or_else(|| Error::Parse("sms send missing data".into()))?;
            let recaptcha_url = data
                .get("recaptcha_url")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string();
            if !recaptcha_url.is_empty() {
                return Ok(SmsSendOutcome::NeedCaptcha {
                    message: resp.message_text().to_string(),
                    bili_code: resp.code,
                    captcha: parse_need_captcha(&data, Some(&recaptcha_url))?,
                });
            }
            let captcha_key = data
                .get("captcha_key")
                .and_then(|v| v.as_str())
                .unwrap_or("")
                .to_string();
            if captcha_key.is_empty() {
                return Err(Error::Parse("sms send missing captcha_key".into()));
            }
            return Ok(SmsSendOutcome::Sent(SmsSendResult { captcha_key }));
        }

        if resp.code == -105 {
            let message = resp.message_text().to_string();
            let bili_code = resp.code;
            let data = resp.data.unwrap_or(Value::Null);
            let captcha = match parse_need_captcha(&data, None) {
                Ok(c) => c,
                Err(_) => SmsNeedCaptcha {
                    recaptcha_token: String::new(),
                    gee_gt: String::new(),
                    gee_challenge: String::new(),
                    recaptcha_url: data
                        .get("recaptcha_url")
                        .and_then(|v| v.as_str())
                        .unwrap_or("")
                        .to_string(),
                },
            };
            return Ok(SmsSendOutcome::NeedCaptcha {
                message,
                bili_code,
                captcha,
            });
        }

        resp.ensure_ok()?;
        Err(Error::Parse("sms send unexpected response".into()))
    }

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
        params.insert("mobi_app".into(), MOBI_APP_ANDROID_HD.into());
        params.insert("platform".into(), PLATFORM_ANDROID.into());
        params.insert("build".into(), SMS_BUILD.into());
        params.insert("c_locale".into(), "zh_CN".into());
        params.insert("s_locale".into(), "zh_CN".into());
        params.insert("disable_rcmd".into(), "0".into());

        let mut opts = RequestOptions::app_sign();
        opts.prefer_app_ua = true;
        let (text, headers) = client.post_form_raw(&url, params, opts).await?;
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

fn parse_need_captcha(data: &Value, recaptcha_url_hint: Option<&str>) -> Result<SmsNeedCaptcha> {
    let recaptcha_url = recaptcha_url_hint
        .map(str::to_string)
        .or_else(|| {
            data.get("recaptcha_url")
                .and_then(|v| v.as_str())
                .map(str::to_string)
        })
        .unwrap_or_default();

    if !recaptcha_url.is_empty() {
        if let Ok(uri) = url::Url::parse(&recaptcha_url) {
            let q = |k: &str| {
                uri.query_pairs()
                    .find(|(n, _)| n == k)
                    .map(|(_, v)| v.into_owned())
                    .unwrap_or_default()
            };
            let token = q("recaptcha_token");
            let gt = q("gee_gt");
            let challenge = q("gee_challenge");
            if !token.is_empty() && !gt.is_empty() && !challenge.is_empty() {
                return Ok(SmsNeedCaptcha {
                    recaptcha_token: token,
                    gee_gt: gt,
                    gee_challenge: challenge,
                    recaptcha_url,
                });
            }
        }
    }

    let token = data
        .get("recaptcha_token")
        .or_else(|| data.get("token"))
        .and_then(|v| v.as_str())
        .unwrap_or("")
        .to_string();
    let gt = data
        .get("gee_gt")
        .or_else(|| data.get("gt"))
        .and_then(|v| v.as_str())
        .unwrap_or("")
        .to_string();
    let challenge = data
        .get("gee_challenge")
        .or_else(|| data.get("challenge"))
        .and_then(|v| v.as_str())
        .unwrap_or("")
        .to_string();

    if token.is_empty() || gt.is_empty() || challenge.is_empty() {
        return Err(Error::Parse(
            "sms captcha challenge incomplete (need recaptcha_url or preCapture)".into(),
        ));
    }
    Ok(SmsNeedCaptcha {
        recaptcha_token: token,
        gee_gt: gt,
        gee_challenge: challenge,
        recaptcha_url,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn parse_need_captcha_from_url() {
        let data = json!({
            "recaptcha_url": "https://passport.bilibili.com/x/passport-login/captcha?recaptcha_token=tok&gee_gt=gt1&gee_challenge=ch1"
        });
        let c = parse_need_captcha(&data, None).unwrap();
        assert_eq!(c.recaptcha_token, "tok");
        assert_eq!(c.gee_gt, "gt1");
        assert_eq!(c.gee_challenge, "ch1");
    }

    #[test]
    fn parse_need_captcha_from_flat() {
        let data = json!({
            "recaptcha_token": "t",
            "gee_gt": "g",
            "gee_challenge": "c"
        });
        let c = parse_need_captcha(&data, None).unwrap();
        assert_eq!(c.recaptcha_token, "t");
        assert_eq!(c.gee_gt, "g");
        assert_eq!(c.gee_challenge, "c");
    }
}
