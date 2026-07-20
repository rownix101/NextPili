//! HTTP transport layer for Bilibili APIs.

pub mod client;
pub mod endpoints;
pub mod error;
pub mod middleware;
pub mod response;

pub use client::{BiliClient, ClientConfig, RequestOptions};
pub use endpoints::{
    now_unix, CaptchaParams, FeedApi, HeartbeatParams, LoginApi, LoginSuccess, NavApi, NavInfo,
    PlayUrlParams, PopularFeed, QrPollStatus, QrStart, RecommendFeed, SmsLoginRequest,
    SmsSendRequest, SmsSendResult, VideoApi, PLAYURL_FNVAL_DASH,
};
pub use error::{Error, Result};
pub use middleware::{AuthMode, SignMode};
pub use response::{parse_bili_json, BiliResponse};
