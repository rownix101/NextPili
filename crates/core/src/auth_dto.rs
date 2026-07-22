//! Auth FFI DTOs shared by auth_service and FRB API surface.

use auth::AccountSlot;

#[derive(Debug, Clone)]
pub struct QrStartDto {
    pub url: String,
    pub auth_code: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum QrStatusKind {
    Pending,
    Scanned,
    Confirmed,
    Expired,
    Error,
}

#[derive(Debug, Clone)]
pub struct QrPollDto {
    pub status: QrStatusKind,
    pub message: String,
    pub account: Option<AccountPublicDto>,
}

#[derive(Debug, Clone)]
pub struct AccountPublicDto {
    pub id: String,
    pub mid: i64,
    pub name: String,
    pub avatar_url: String,
    pub is_login: bool,
}

impl AccountPublicDto {
    pub fn from_domain(a: &domain::AccountPublic) -> Self {
        Self {
            id: a.id.as_str().to_string(),
            mid: a.mid.get(),
            name: a.name.clone(),
            avatar_url: a.avatar_url.clone(),
            is_login: a.is_login,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SlotDto {
    Main,
    Heartbeat,
    Recommend,
    Video,
}

impl From<SlotDto> for AccountSlot {
    fn from(value: SlotDto) -> Self {
        match value {
            SlotDto::Main => AccountSlot::Main,
            SlotDto::Heartbeat => AccountSlot::Heartbeat,
            SlotDto::Recommend => AccountSlot::Recommend,
            SlotDto::Video => AccountSlot::Video,
        }
    }
}

#[derive(Debug, Clone)]
pub struct CaptchaDto {
    pub token: String,
    pub gt: String,
    pub challenge: String,
    pub captcha_type: String,
}

#[derive(Debug, Clone)]
pub struct SmsSendDto {
    /// International dialing code (中国大陆 = 86). App SMS `cid`.
    pub cid: i32,
    pub tel: String,
    pub token: String,
    pub gee_challenge: String,
    pub gee_validate: String,
    pub gee_seccode: String,
    pub login_session_id: String,
    pub local_id: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SmsSendResultKind {
    Sent,
    NeedCaptcha,
}

#[derive(Debug, Clone)]
pub struct SmsSendDtoResult {
    pub kind: SmsSendResultKind,
    pub captcha_key: String,
    pub login_session_id: String,
    pub message: String,
    pub captcha: Option<CaptchaDto>,
}

#[derive(Debug, Clone)]
pub struct SmsLoginDto {
    pub cid: i32,
    pub tel: String,
    pub code: String,
    pub captcha_key: String,
    pub login_session_id: String,
}

#[derive(Debug, Clone)]
pub struct PasswordLoginDto {
    /// Phone number or email.
    pub username: String,
    pub password: String,
    /// Captcha API `token`.
    pub token: String,
    pub gee_challenge: String,
    pub gee_validate: String,
    pub gee_seccode: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PasswordLoginResultKind {
    Success,
    NeedPhoneVerify,
}

#[derive(Debug, Clone)]
pub struct PasswordRiskDto {
    pub risk_url: String,
    pub tmp_token: String,
    pub request_id: String,
    pub source: String,
    pub hide_tel: String,
}

#[derive(Debug, Clone)]
pub struct PasswordLoginResultDto {
    pub kind: PasswordLoginResultKind,
    pub message: String,
    pub account: Option<AccountPublicDto>,
    pub risk: Option<PasswordRiskDto>,
}

#[derive(Debug, Clone)]
pub struct PasswordRiskSendSmsDto {
    pub tmp_token: String,
    pub risk_url: String,
    pub token: String,
    pub gee_challenge: String,
    pub gee_validate: String,
    pub gee_seccode: String,
}

#[derive(Debug, Clone)]
pub struct PasswordRiskSendSmsResultDto {
    pub captcha_key: String,
}

#[derive(Debug, Clone)]
pub struct PasswordRiskVerifyDto {
    pub code: String,
    pub tmp_token: String,
    pub request_id: String,
    pub source: String,
    pub captcha_key: String,
    pub risk_url: String,
}
