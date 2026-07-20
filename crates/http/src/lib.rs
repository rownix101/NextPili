//! HTTP transport layer for Bilibili APIs.

pub mod client;
pub mod endpoints;
pub mod error;
pub mod middleware;
pub mod response;

pub use client::{BiliClient, ClientConfig, RequestOptions};
pub use endpoints::{
    CaptchaParams, FeedApi, LoginApi, LoginSuccess, NavApi, NavInfo, PopularFeed, QrPollStatus,
    QrStart, RecommendFeed, SmsLoginRequest, SmsSendRequest, SmsSendResult, VideoApi,
};
pub use error::{Error, Result};
pub use middleware::{AuthMode, SignMode};
pub use response::{parse_bili_json, BiliResponse};
