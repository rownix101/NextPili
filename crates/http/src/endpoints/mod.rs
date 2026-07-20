//! Endpoint modules (login, video, feed, …).

pub mod feed;
pub mod login;
pub mod nav;
pub mod video;

pub use feed::{FeedApi, PopularFeed, RecommendFeed};
pub use login::{
    CaptchaParams, LoginApi, LoginSuccess, QrPollStatus, QrStart, SmsLoginRequest, SmsSendRequest,
    SmsSendResult,
};
pub use nav::{NavApi, NavInfo};
pub use video::VideoApi;
