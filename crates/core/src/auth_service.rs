//! Auth use cases: QR (desktop/tablet), SMS / password login, account list, logout.

use crate::error::{AppError, ErrorKind};
use auth::{now_ms, Account, AccountRegistry, WbiSigner};
use domain::id::{AccountId, UserMid};
use http::{
    BiliClient, LoginSuccess, NavApi, PasswordLoginOutcome, PasswordLoginRequest,
    SafeCenterSmsSendRequest, SafeCenterSmsVerifyRequest, SmsLoginRequest, SmsSendRequest,
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

/// Complete password login (RSA encrypt + App oauth2).
///
/// May return [`PasswordLoginResultDto::need_phone_verify`] for safe-center SMS (PiliPlus flow).
pub async fn login_password(
    http: &BiliClient,
    store: &Store,
    accounts: &RwLock<AccountRegistry>,
    wbi: &RwLock<WbiSigner>,
    req: PasswordLoginDto,
) -> Result<PasswordLoginResultDto, AppError> {
    let username = req.username.trim();
    if username.is_empty() {
        return Err(AppError::new(
            ErrorKind::InvalidArgument,
            "账号不能为空（手机号 / 邮箱）",
        ));
    }
    if req.password.is_empty() {
        return Err(AppError::new(ErrorKind::InvalidArgument, "密码不能为空"));
    }
    if req.token.trim().is_empty()
        || req.gee_challenge.trim().is_empty()
        || req.gee_validate.trim().is_empty()
    {
        return Err(AppError::new(
            ErrorKind::InvalidArgument,
            "请先完成人机验证",
        ));
    }

    let seccode = normalize_seccode(&req.gee_seccode, &req.gee_validate);

    let outcome = http::LoginApi::password_login(
        http,
        &PasswordLoginRequest {
            username,
            password: &req.password,
            recaptcha_token: req.token.trim(),
            gee_challenge: req.gee_challenge.trim(),
            gee_validate: req.gee_validate.trim(),
            gee_seccode: &seccode,
        },
    )
    .await?;

    match outcome {
        PasswordLoginOutcome::Success(success) => {
            let account = finalize_login(http, store, accounts, wbi, success).await?;
            Ok(PasswordLoginResultDto {
                kind: PasswordLoginResultKind::Success,
                message: "登录成功".into(),
                account: Some(account),
                risk: None,
            })
        }
        PasswordLoginOutcome::NeedPhoneVerify {
            message,
            risk_url,
            tmp_token,
            request_id,
            source,
        } => {
            // Prefetch hide_tel for UI (best-effort).
            let mut hide_tel = String::new();
            let mut tel_verify = true;
            match http::LoginApi::safe_center_info(http, &tmp_token).await {
                Ok(info) => {
                    hide_tel = info.hide_tel;
                    tel_verify = info.tel_verify;
                }
                Err(e) => {
                    tracing::warn!(error = %e, "safe_center_info failed");
                }
            }
            if !tel_verify {
                return Err(AppError::new(
                    ErrorKind::RiskControl,
                    "当前账号未绑定可验证手机号，请改用短信或扫码登录",
                ));
            }
            Ok(PasswordLoginResultDto {
                kind: PasswordLoginResultKind::NeedPhoneVerify,
                message,
                account: None,
                risk: Some(PasswordRiskDto {
                    risk_url,
                    tmp_token,
                    request_id,
                    source,
                    hide_tel,
                }),
            })
        }
    }
}

/// Safe-center pre captcha for risk SMS (PiliPlus `preCapture`).
pub async fn login_password_risk_captcha(http: &BiliClient) -> Result<CaptchaDto, AppError> {
    let c = http::LoginApi::safe_center_pre_captcha(http).await?;
    Ok(CaptchaDto {
        token: c.recaptcha_token,
        gt: c.gee_gt,
        challenge: c.gee_challenge,
        captcha_type: "geetest".into(),
    })
}

/// Send safe-center risk SMS after geetest.
pub async fn login_password_risk_send_sms(
    http: &BiliClient,
    req: PasswordRiskSendSmsDto,
) -> Result<PasswordRiskSendSmsResultDto, AppError> {
    if req.tmp_token.trim().is_empty() {
        return Err(AppError::new(
            ErrorKind::InvalidArgument,
            "缺少 tmp_token",
        ));
    }
    if req.gee_validate.trim().is_empty() || req.token.trim().is_empty() {
        return Err(AppError::new(
            ErrorKind::InvalidArgument,
            "请先完成人机验证",
        ));
    }
    let seccode = normalize_seccode(&req.gee_seccode, &req.gee_validate);
    let result = http::LoginApi::safe_center_sms_send(
        http,
        &SafeCenterSmsSendRequest {
            tmp_code: req.tmp_token.trim(),
            gee_challenge: req.gee_challenge.trim(),
            gee_validate: req.gee_validate.trim(),
            gee_seccode: &seccode,
            recaptcha_token: req.token.trim(),
            referer_url: req.risk_url.trim(),
            sms_type: None,
        },
    )
    .await?;
    Ok(PasswordRiskSendSmsResultDto {
        captcha_key: result.captcha_key,
    })
}

/// Verify risk SMS and finish login via oauth2 access_token (PiliPlus flow).
pub async fn login_password_risk_verify(
    http: &BiliClient,
    store: &Store,
    accounts: &RwLock<AccountRegistry>,
    wbi: &RwLock<WbiSigner>,
    req: PasswordRiskVerifyDto,
) -> Result<AccountPublicDto, AppError> {
    if req.code.trim().is_empty() {
        return Err(AppError::new(ErrorKind::InvalidArgument, "请输入短信验证码"));
    }
    if req.tmp_token.trim().is_empty() || req.captcha_key.trim().is_empty() {
        return Err(AppError::new(
            ErrorKind::InvalidArgument,
            "缺少二次验证会话参数",
        ));
    }
    let oauth_code = http::LoginApi::safe_center_sms_verify(
        http,
        &SafeCenterSmsVerifyRequest {
            code: req.code.trim(),
            tmp_code: req.tmp_token.trim(),
            request_id: req.request_id.trim(),
            source: if req.source.trim().is_empty() {
                "risk"
            } else {
                req.source.trim()
            },
            captcha_key: req.captcha_key.trim(),
            referer_url: req.risk_url.trim(),
            r#type: None,
        },
    )
    .await?;

    let buvid = store.buvid3();
    let local_id = if buvid.is_empty() {
        "0".into()
    } else {
        buvid.clone()
    };
    let success =
        http::LoginApi::oauth2_access_token(http, &oauth_code, &local_id, &buvid).await?;
    finalize_login(http, store, accounts, wbi, success).await
}

fn normalize_seccode(gee_seccode: &str, gee_validate: &str) -> String {
    if gee_seccode.contains('|') {
        gee_seccode.to_string()
    } else if gee_seccode.trim().is_empty() {
        format!("{}|jordan", gee_validate.trim())
    } else {
        format!("{}|jordan", gee_seccode.trim())
    }
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

pub use crate::auth_dto::*;
