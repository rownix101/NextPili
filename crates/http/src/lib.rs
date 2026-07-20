//! HTTP transport layer for Bilibili APIs.

pub mod client;
pub mod endpoints;
pub mod error;
pub mod middleware;
pub mod response;

pub use client::{BiliClient, ClientConfig, RequestOptions};
pub use endpoints::{
    now_unix, CaptchaParams, DanmakuApi, FeedApi, HeartbeatParams, LoginApi, LoginSuccess, NavApi,
    NavInfo, PasswordKey, PasswordLoginOutcome, PasswordLoginRequest, PlayUrlParams, PopularFeed,
    QrPollStatus, QrStart, RecommendFeed, ReplyApi, SafeCenterCaptcha, SafeCenterInfo,
    SafeCenterSmsSendRequest, SafeCenterSmsVerifyRequest, SmsLoginRequest, SmsSendRequest,
    SmsSendResult, VideoApi, PLAYURL_FNVAL_DASH, REPLY_MODE_HOT, REPLY_MODE_TIME, REPLY_TYPE_VIDEO,
};
pub use error::{Error, Result};
pub use middleware::{AuthMode, SignMode};
pub use response::{parse_bili_json, BiliResponse};
