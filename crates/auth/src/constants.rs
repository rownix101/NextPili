//! Centralized Bilibili client constants (no secrets beyond publicly known appsec).

/// Android HD appkey (community-public; used for TV/HD QR login).
pub const APPKEY_ANDROID_HD: &str = "dfca71928277209b";

/// Android HD appsec paired with [`APPKEY_ANDROID_HD`].
pub const APPSEC_ANDROID_HD: &str = "b5475a8825547a4fc26c7d518eaaa02e";

/// Common TV appkey (alternative to HD for some passport paths).
pub const APPKEY_ANDROID_TV: &str = "4409e2ce8ffd12b8";

/// TV appsec paired with [`APPKEY_ANDROID_TV`].
pub const APPSEC_ANDROID_TV: &str = "59b43e04ad6965f34319062b478f83dd";

pub const MOBI_APP_ANDROID_HD: &str = "android_hd";
pub const PLATFORM_ANDROID: &str = "android";

/// Default Referer for Web APIs.
pub const WEB_REFERER: &str = "https://www.bilibili.com";

pub const API_BASE: &str = "https://api.bilibili.com";
pub const APP_BASE: &str = "https://app.bilibili.com";
pub const PASS_BASE: &str = "https://passport.bilibili.com";
pub const WWW_BASE: &str = "https://www.bilibili.com";
/// Live API host (`api.live.bilibili.com`).
pub const LIVE_BASE: &str = "https://api.live.bilibili.com";
/// Search site host (hotword / suggest).
pub const SEARCH_BASE: &str = "https://s.search.bilibili.com";

/// Web browser-like user agent.
pub const UA_WEB: &str = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36 NextPili/0.1";

/// Android HD style user agent for AppSign requests.
pub const UA_ANDROID_HD: &str =
    "Mozilla/5.0 BiliDroid/1.46.2 (bbcallen@gmail.com) os/android model/NextPili mobi_app/android_hd build/1460200 channel/master innerVer/1460210 osVer/12 network/2";
