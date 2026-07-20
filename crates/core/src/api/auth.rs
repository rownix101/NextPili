//! Auth-facing FFI API (QR for desktop/tablet, SMS, password, account list).

use crate::app::CoreApp;
use crate::auth_service;
use crate::error::AppError;

pub use crate::auth_service::{
    AccountPublicDto, CaptchaDto, PasswordLoginDto, PasswordLoginResultDto, PasswordLoginResultKind,
    PasswordRiskDto, PasswordRiskSendSmsDto, PasswordRiskSendSmsResultDto, PasswordRiskVerifyDto,
    QrPollDto, QrStartDto, QrStatusKind, SlotDto, SmsLoginDto, SmsSendDto, SmsSendDtoResult,
};

/// Start TV/HD QR login. Prefer only on desktop / tablet UI surfaces.
///
/// `local_id` may be empty (defaults to device buvid / "0").
pub async fn login_qr_start(local_id: Option<String>) -> Result<QrStartDto, AppError> {
    let app = CoreApp::global()?;
    let lid = resolve_local_id(&app, local_id);
    auth_service::login_qr_start(&app.http(), &lid).await
}

/// Poll QR login once. Caller should interval ~1.5–2s until confirmed/expired.
pub async fn login_qr_poll(
    auth_code: String,
    local_id: Option<String>,
) -> Result<QrPollDto, AppError> {
    let app = CoreApp::global()?;
    let lid = resolve_local_id(&app, local_id);

    let http = app.http();
    let status = http::LoginApi::qr_poll(&http, &auth_code, &lid).await?;

    use http::QrPollStatus;
    match status {
        QrPollStatus::Pending => Ok(QrPollDto {
            status: auth_service::QrStatusKind::Pending,
            message: "等待扫码".into(),
            account: None,
        }),
        QrPollStatus::Scanned => Ok(QrPollDto {
            status: auth_service::QrStatusKind::Scanned,
            message: "已扫码，请在手机上确认".into(),
            account: None,
        }),
        QrPollStatus::Expired => Ok(QrPollDto {
            status: auth_service::QrStatusKind::Expired,
            message: "二维码已失效".into(),
            account: None,
        }),
        QrPollStatus::Other { code, message } => Ok(QrPollDto {
            status: auth_service::QrStatusKind::Error,
            message: format!("登录失败 ({code}): {message}"),
            account: None,
        }),
        QrPollStatus::Confirmed(success) => {
            auth_service::finalize_qr_login(&http, &app.store, &app.accounts, &app.wbi, success)
                .await
        }
    }
}

/// Fetch geetest parameters for SMS login.
pub async fn login_captcha() -> Result<CaptchaDto, AppError> {
    let app = CoreApp::global()?;
    auth_service::login_captcha(&app.http()).await
}

/// Generate a fresh SMS login session id (uuid without dashes).
#[flutter_rust_bridge::frb(sync)]
pub fn new_login_session_id() -> String {
    auth_service::new_login_session_id()
}

/// Send SMS verification code after captcha is solved.
pub async fn login_sms_send(req: SmsSendDto) -> Result<SmsSendDtoResult, AppError> {
    let app = CoreApp::global()?;
    auth_service::login_sms_send(&app.http(), &app.store, req).await
}

/// Complete SMS login.
pub async fn login_sms(req: SmsLoginDto) -> Result<AccountPublicDto, AppError> {
    let app = CoreApp::global()?;
    auth_service::login_sms(&app.http(), &app.store, &app.accounts, &app.wbi, req).await
}

/// Complete password login (RSA + App oauth2; requires geetest).
///
/// On risk, returns `kind = need_phone_verify` with safe-center params (PiliPlus flow).
pub async fn login_password(req: PasswordLoginDto) -> Result<PasswordLoginResultDto, AppError> {
    let app = CoreApp::global()?;
    auth_service::login_password(&app.http(), &app.store, &app.accounts, &app.wbi, req).await
}

/// Safe-center pre captcha for password risk SMS.
pub async fn login_password_risk_captcha() -> Result<CaptchaDto, AppError> {
    let app = CoreApp::global()?;
    auth_service::login_password_risk_captcha(&app.http()).await
}

/// Send safe-center risk SMS after geetest.
pub async fn login_password_risk_send_sms(
    req: PasswordRiskSendSmsDto,
) -> Result<PasswordRiskSendSmsResultDto, AppError> {
    let app = CoreApp::global()?;
    auth_service::login_password_risk_send_sms(&app.http(), req).await
}

/// Verify risk SMS and finish password login.
pub async fn login_password_risk_verify(
    req: PasswordRiskVerifyDto,
) -> Result<AccountPublicDto, AppError> {
    let app = CoreApp::global()?;
    auth_service::login_password_risk_verify(
        &app.http(),
        &app.store,
        &app.accounts,
        &app.wbi,
        req,
    )
    .await
}

/// List known accounts (no secrets).
#[flutter_rust_bridge::frb(sync)]
pub fn list_accounts() -> Result<Vec<AccountPublicDto>, AppError> {
    let app = CoreApp::global()?;
    let accounts = app.accounts.read();
    Ok(auth_service::list_accounts(&accounts))
}

/// Remove an account. If `account_id` is null, removes active main.
#[flutter_rust_bridge::frb(sync)]
pub fn logout(account_id: Option<String>) -> Result<(), AppError> {
    let app = CoreApp::global()?;
    let mut accounts = app.accounts.write();
    auth_service::logout(&app.store, &mut accounts, account_id.as_deref())
}

/// Bind an account to a routing slot.
#[flutter_rust_bridge::frb(sync)]
pub fn set_account_slot(slot: SlotDto, account_id: Option<String>) -> Result<(), AppError> {
    let app = CoreApp::global()?;
    let mut accounts = app.accounts.write();
    auth_service::set_account_slot(&app.store, &mut accounts, slot, account_id)
}

/// Device buvid3 (always available after bootstrap).
#[flutter_rust_bridge::frb(sync)]
pub fn device_buvid3() -> Result<String, AppError> {
    let app = CoreApp::global()?;
    Ok(app.store.buvid3())
}

fn resolve_local_id(app: &CoreApp, local_id: Option<String>) -> String {
    match local_id {
        Some(s) if !s.is_empty() => s,
        _ => {
            let b = app.store.buvid3();
            if b.is_empty() {
                "0".into()
            } else {
                b
            }
        }
    }
}
