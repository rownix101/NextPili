//! Account model, cookie jar, WBI / AppSign / buvid (no HTTP transport).

pub mod account;
pub mod app_sign;
pub mod buvid;
pub mod constants;
pub mod cookie;
pub mod password;
pub mod slot;
pub mod wbi;

pub use account::{now_ms, Account, AccountRegistry, AccountRegistrySnapshot};
pub use app_sign::AppSigner;
pub use buvid::generate_buvid3;
pub use constants::{
    API_BASE, APPKEY_ANDROID_HD, APPSEC_ANDROID_HD, APP_BASE, LIVE_BASE, MOBI_APP_ANDROID_HD,
    PASS_BASE, PLATFORM_ANDROID, SEARCH_BASE, UA_ANDROID_HD, UA_WEB, WEB_REFERER, WWW_BASE,
};
pub use cookie::CookieJar;
pub use password::{encrypt_password, PasswordCryptoError};
pub use slot::AccountSlot;
pub use wbi::WbiSigner;
