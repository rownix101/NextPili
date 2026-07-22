//! HTTP transport layer for Bilibili APIs.

pub mod client;
pub mod endpoints;
pub mod error;
pub mod middleware;
pub mod response;
pub mod serde_util;

pub use client::{BiliClient, ClientConfig, RequestOptions};
pub use endpoints::{
    now_unix, CaptchaParams, DanmakuApi, DynamicsApi, EngagementApi, FeedApi, HeartbeatParams,
    LiveApi, LoginApi, LoginSuccess, NavApi, NavInfo, PasswordKey, PasswordLoginOutcome,
    PasswordLoginRequest, PgcApi, PgcPlayUrlParams, PlayUrlParams, PopularFeed, QrPollStatus,
    QrStart, RankingFeed, RecommendFeed, ReplyApi, SafeCenterCaptcha, SafeCenterInfo,
    SafeCenterSmsSendRequest,
    SafeCenterSmsVerifyRequest, SearchApi, SearchSuggest, SearchVideoPage, SmsLoginRequest,
    SmsNeedCaptcha, SmsSendOutcome, SmsSendRequest, SmsSendResult, UserApi, VideoApi,
    PLAYURL_FNVAL_DASH, REPLY_MODE_HOT, REPLY_MODE_TIME, REPLY_TYPE_VIDEO,
};
pub use error::{Error, Result};
pub use middleware::{AuthMode, SignMode};
pub use response::{parse_bili_json, BiliResponse};
