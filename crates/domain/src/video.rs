use crate::id::{Cid, DurationMs, UserMid};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Owner {
    pub mid: UserMid,
    pub name: String,
    pub face: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct VideoStat {
    pub view: i64,
    pub danmaku: i64,
    pub reply: i64,
    pub favorite: i64,
    pub coin: i64,
    pub share: i64,
    pub like: i64,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct VideoPage {
    pub cid: Cid,
    pub page: i32,
    pub part: String,
    pub duration_ms: DurationMs,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct VideoDetail {
    pub aid: i64,
    pub bvid: String,
    pub title: String,
    pub cover: String,
    pub desc: String,
    pub owner: Owner,
    pub pages: Vec<VideoPage>,
    pub stat: VideoStat,
    pub duration_ms: DurationMs,
}
