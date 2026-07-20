use crate::id::UserMid;
use serde::{Deserialize, Serialize};

/// One top-level (or nested) reply item for UI lists.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Reply {
    pub rpid: i64,
    pub mid: UserMid,
    pub uname: String,
    pub avatar: String,
    pub content: String,
    /// Unix time in **milliseconds**.
    pub ctime_ms: i64,
    pub like: i64,
    pub children_count: i32,
}

/// Paginated reply list (main floor).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ReplyPage {
    pub replies: Vec<Reply>,
    /// Opaque offset for next page (`pagination_str` / `next_offset`); empty if end.
    pub next_offset: String,
    pub is_end: bool,
    /// Total count when known (may be 0 if API omitted).
    pub all_count: i64,
}

/// Result of posting a comment (`/x/v2/reply/add`).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ReplyAddResult {
    pub rpid: i64,
    pub success_toast: String,
    /// Full reply when API returns it; otherwise synthesize in core.
    pub reply: Option<Reply>,
}
