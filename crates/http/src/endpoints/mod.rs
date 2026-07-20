//! Endpoint modules (login, video, feed, …).

pub mod danmaku;
pub mod feed;
pub mod login;
pub mod nav;
pub mod reply;
pub mod search;
pub mod video;

pub use danmaku::DanmakuApi;
pub use feed::{FeedApi, PopularFeed, RecommendFeed};
pub use login::{
    CaptchaParams, LoginApi, LoginSuccess, PasswordKey, PasswordLoginOutcome, PasswordLoginRequest,
    QrPollStatus, QrStart, SafeCenterCaptcha, SafeCenterInfo, SafeCenterSmsSendRequest,
    SafeCenterSmsVerifyRequest, SmsLoginRequest, SmsSendRequest, SmsSendResult,
};
pub use nav::{NavApi, NavInfo};
pub use reply::{ReplyApi, REPLY_MODE_HOT, REPLY_MODE_TIME, REPLY_TYPE_VIDEO};
pub use search::{SearchApi, SearchSuggest, SearchVideoPage};
pub use video::{now_unix, HeartbeatParams, PlayUrlParams, VideoApi, PLAYURL_FNVAL_DASH};
