//! Authentication primitives: accounts, slots, cookies, WBI, AppSign, buvid.
//!
//! Does **not** perform HTTP; callers inject network where needed.

pub mod account;
pub mod app_sign;
pub mod buvid;
pub mod cookie;
pub mod slot;
pub mod wbi;

pub use account::{Account, AccountRegistry};
pub use app_sign::AppSigner;
pub use buvid::generate_buvid3;
pub use cookie::CookieJar;
pub use slot::AccountSlot;
pub use wbi::WbiSigner;
