use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DanmakuItem {
    pub id: i64,
    pub progress_ms: i64,
    pub mode: i32,
    pub fontsize: i32,
    pub color: u32,
    pub text: String,
    pub mid_hash: String,
}

/// Result of posting a video danmaku (`/x/v2/dm/post`).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DanmakuPostResult {
    pub dmid: i64,
    pub visible: bool,
}
