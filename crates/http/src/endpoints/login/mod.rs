//! Passport login endpoints (QR + SMS + password).

mod password;
mod qr;
mod sms;
mod types;

pub use types::{
    CaptchaParams, LoginSuccess, PasswordKey, PasswordLoginOutcome, PasswordLoginRequest,
    QrPollStatus, QrStart, SafeCenterCaptcha, SafeCenterInfo, SafeCenterSmsSendRequest,
    SafeCenterSmsVerifyRequest, SmsLoginRequest, SmsNeedCaptcha, SmsSendOutcome, SmsSendRequest,
    SmsSendResult,
};

/// Passport login endpoints (QR + SMS + password).
pub struct LoginApi;

#[cfg(test)]
mod tests {
    use super::types::{parse_login_success, LoginData};
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
