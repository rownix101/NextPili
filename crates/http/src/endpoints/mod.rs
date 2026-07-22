//! Endpoint modules (login, video, feed, …).

pub mod danmaku;
pub mod dynamics;
pub mod engagement;
pub mod feed;
pub mod live;
pub mod login;
pub mod nav;
pub mod pgc;
pub mod reply;
pub mod search;
pub mod user;
pub mod video;

pub use danmaku::DanmakuApi;
pub use dynamics::DynamicsApi;
pub use engagement::EngagementApi;
pub use feed::{FeedApi, PopularFeed, RankingFeed, RecommendFeed};
pub use live::LiveApi;
pub use login::{
    CaptchaParams, LoginApi, LoginSuccess, PasswordKey, PasswordLoginOutcome, PasswordLoginRequest,
    QrPollStatus, QrStart, SafeCenterCaptcha, SafeCenterInfo, SafeCenterSmsSendRequest,
    SafeCenterSmsVerifyRequest, SmsLoginRequest, SmsNeedCaptcha, SmsSendOutcome, SmsSendRequest,
    SmsSendResult,
};
pub use nav::{NavApi, NavInfo};
pub use pgc::{PgcApi, PgcPlayUrlParams};
pub use reply::{ReplyApi, REPLY_MODE_HOT, REPLY_MODE_TIME, REPLY_TYPE_VIDEO};
pub use search::{SearchApi, SearchSuggest, SearchVideoPage};
pub use user::UserApi;
pub use video::{now_unix, HeartbeatParams, PlayUrlParams, VideoApi, PLAYURL_FNVAL_DASH};
