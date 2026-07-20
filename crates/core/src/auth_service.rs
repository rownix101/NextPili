//! Auth use cases: QR (desktop/tablet), SMS login, account list, logout.

use crate::error::{AppError, ErrorKind};
use auth::{now_ms, Account, AccountRegistry, AccountSlot, WbiSigner};
use domain::id::{AccountId, UserMid};
use http::{
    BiliClient, LoginSuccess, NavApi, SmsLoginRequest, SmsSendRequest,
};
use parking_lot::RwLock;
use store::Store;
use uuid::Uuid;

/// Start TV/HD QR login; returns URL + auth_code for the UI.
pub async fn login_qr_start(http: &BiliClient, local_id: &str) -> Result<QrStartDto, AppError> {
    let start = http::LoginApi::qr_start(http, local_id).await?;
    Ok(QrStartDto {
        url: start.url,
        auth_code: start.auth_code,
    })
}

/// Persist login success: nav refresh, insert account, save store.
pub async fn finalize_login(
    http: &BiliClient,
    store: &Store,
    accounts: &RwLock<AccountRegistry>,
    wbi: &RwLock<WbiSigner>,
    success: LoginSuccess,
) -> Result<AccountPublicDto, AppError> {
    let buvid3 = store.buvid3();
    let mut jar = success.cookie_jar;
    if jar.get("buvid3").is_none() {
        jar.set("buvid3", &buvid3);
    }

    let now = now_ms();
    let mut account = Account {
        id: AccountId::new(),
        mid: UserMid(success.mid.max(0)),
        name: String::new(),
        face: String::new(),
        cookie_jar: jar,
        access_key: success.access_key,
        refresh_token: success.refresh_token,
        created_at_ms: now,
        updated_at_ms: now,
        expired: false,
    };

    // Clone signer so we never hold parking_lot guards across `.await`.
    let mut wbi_local = wbi.read().clone();
    match NavApi::refresh_wbi(http, &mut wbi_local, Some(&account), Some(&buvid3)).await {
        Ok(nav) => {
            if nav.mid > 0 {
                account.mid = UserMid(nav.mid);
            }
            if !nav.uname.is_empty() {
                account.name = nav.uname;
            }
            if !nav.face.is_empty() {
                account.face = nav.face;
            }
        }
        Err(e) => {
            tracing::warn!(error = %e, "nav after login failed; keeping token/cookies");
        }
    }
    *wbi.write() = wbi_local;

    if account.name.is_empty() {
        account.name = format!("用户{}", account.mid.get());
    }

    let public = account.to_public();
    {
        let mut reg = accounts.write();
        reg.insert_and_fill_empty_slots(account);
        store.save_accounts(&reg)?;
    }
    Ok(AccountPublicDto::from_domain(&public))
}

pub async fn finalize_qr_login(
    http: &BiliClient,
    store: &Store,
    accounts: &RwLock<AccountRegistry>,
    wbi: &RwLock<WbiSigner>,
    success: LoginSuccess,
) -> Result<QrPollDto, AppError> {
    let account = finalize_login(http, store, accounts, wbi, success).await?;
    Ok(QrPollDto {
        status: QrStatusKind::Confirmed,
        message: "登录成功".into(),
        account: Some(account),
    })
}

/// Fetch geetest captcha params for SMS.
pub async fn login_captcha(http: &BiliClient) -> Result<CaptchaDto, AppError> {
    let c = http::LoginApi::captcha(http).await?;
    Ok(CaptchaDto {
        token: c.token,
        gt: c.gt,
        challenge: c.challenge,
        captcha_type: c.captcha_type,
    })
}

/// Create a new SMS login session id (uuid without dashes).
pub fn new_login_session_id() -> String {
    Uuid::new_v4().simple().to_string()
}


/// Send SMS code after captcha is solved.
pub async fn login_sms_send(
    http: &BiliClient,
    store: &Store,
    req: SmsSendDto,
) -> Result<SmsSendDtoResult, AppError> {
    validate_tel(&req.tel)?;
    if req.gee_validate.trim().is_empty() || req.gee_seccode.trim().is_empty() {
        return Err(AppError::new(
            ErrorKind::InvalidArgument,
            "请先完成人机验证",
        ));
    }
    let buvid = store.buvid3();
    let local_id = if req.local_id.as_deref().unwrap_or("").is_empty() {
        buvid.clone()
    } else {
        req.local_id.unwrap()
    };
    let session = if req.login_session_id.trim().is_empty() {
        new_login_session_id()
    } else {
        req.login_session_id
    };

    let seccode = if req.gee_seccode.contains('|') {
        req.gee_seccode
    } else {
        format!("{}|jordan", req.gee_seccode)
    };

    let result = http::LoginApi::sms_send(
        http,
        &SmsSendRequest {
            cid: req.cid,
            tel: &req.tel,
            login_session_id: &session,
            recaptcha_token: &req.token,
            gee_challenge: &req.gee_challenge,
            gee_validate: &req.gee_validate,
            gee_seccode: &seccode,
            buvid: &buvid,
            local_id: &local_id,
        },
    )
    .await?;

    Ok(SmsSendDtoResult {
        captcha_key: result.captcha_key,
        login_session_id: session,
    })
}

/// Complete SMS login with verification code.
pub async fn login_sms(
    http: &BiliClient,
    store: &Store,
    accounts: &RwLock<AccountRegistry>,
    wbi: &RwLock<WbiSigner>,
    req: SmsLoginDto,
) -> Result<AccountPublicDto, AppError> {
    validate_tel(&req.tel)?;
    if req.code.trim().is_empty() {
        return Err(AppError::new(ErrorKind::InvalidArgument, "请输入短信验证码"));
    }
    if req.captcha_key.trim().is_empty() {
        return Err(AppError::new(
            ErrorKind::InvalidArgument,
            "缺少 captcha_key，请先发送短信验证码",
        ));
    }
    if req.login_session_id.trim().is_empty() {
        return Err(AppError::new(
            ErrorKind::InvalidArgument,
            "缺少 login_session_id",
        ));
    }

    let success = http::LoginApi::sms_login(
        http,
        &SmsLoginRequest {
            cid: req.cid,
            tel: &req.tel,
            login_session_id: &req.login_session_id,
            code: &req.code,
            captcha_key: &req.captcha_key,
        },
    )
    .await?;

    finalize_login(http, store, accounts, wbi, success).await
}

fn validate_tel(tel: &str) -> Result<(), AppError> {
    let t = tel.trim();
    if t.is_empty() {
        return Err(AppError::new(ErrorKind::InvalidArgument, "手机号不能为空"));
    }
    if !t.chars().all(|c| c.is_ascii_digit()) {
        return Err(AppError::new(
            ErrorKind::InvalidArgument,
            "手机号仅支持数字",
        ));
    }
    if t.len() < 6 || t.len() > 15 {
        return Err(AppError::new(
            ErrorKind::InvalidArgument,
            "手机号长度不正确",
        ));
    }
    Ok(())
}

pub fn list_accounts(accounts: &AccountRegistry) -> Vec<AccountPublicDto> {
    accounts
        .list_public()
        .iter()
        .map(AccountPublicDto::from_domain)
        .collect()
}

pub fn logout(
    store: &Store,
    accounts: &mut AccountRegistry,
    account_id: Option<&str>,
) -> Result<(), AppError> {
    match account_id {
        Some(id) => {
            accounts.remove(id);
        }
        None => {
            if let Some(main) = accounts.active_main().map(|a| a.id.as_str().to_string()) {
                accounts.remove(&main);
            }
        }
    }
    store.save_accounts(accounts)?;
    Ok(())
}

pub fn set_account_slot(
    store: &Store,
    accounts: &mut AccountRegistry,
    slot: SlotDto,
    account_id: Option<String>,
) -> Result<(), AppError> {
    if let Some(ref id) = account_id
        && accounts.get(id).is_none()
    {
        return Err(AppError::new(
            ErrorKind::InvalidArgument,
            format!("账号不存在: {id}"),
        ));
    }
    accounts.set_slot(slot.into(), account_id.as_deref());
    store.save_accounts(accounts)?;
    Ok(())
}

// --- FFI DTOs ---

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
    /// Passport country id (中国大陆 = 1).
    pub cid: i32,
    pub tel: String,
    pub token: String,
    pub gee_challenge: String,
    pub gee_validate: String,
    pub gee_seccode: String,
    pub login_session_id: String,
    pub local_id: Option<String>,
}

#[derive(Debug, Clone)]
pub struct SmsSendDtoResult {
    pub captcha_key: String,
    pub login_session_id: String,
}

#[derive(Debug, Clone)]
pub struct SmsLoginDto {
    pub cid: i32,
    pub tel: String,
    pub code: String,
    pub captcha_key: String,
    pub login_session_id: String,
}
