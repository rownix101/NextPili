//! Public FFI API surface (hand-written; FRB generates bindings from these).

pub mod auth;
pub mod simple;

pub use auth::{
    device_buvid3, list_accounts, login_captcha, login_qr_poll, login_qr_start, login_sms,
    login_sms_send, logout, new_login_session_id, set_account_slot, AccountPublicDto, CaptchaDto,
    QrPollDto, QrStartDto, QrStatusKind, SlotDto, SmsLoginDto, SmsSendDto, SmsSendDtoResult,
};
pub use simple::{api_version, bootstrap, ping, ApiVersion, BootstrapConfig};
