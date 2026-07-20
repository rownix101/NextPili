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
    /// Proto field 9 (AI / ranking weight). Higher = keep first under density cap.
    #[serde(default)]
    pub weight: i32,
}

/// Result of posting a video danmaku (`/x/v2/dm/post`).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DanmakuPostResult {
    pub dmid: i64,
    pub visible: bool,
}
