use serde::{Deserialize, Serialize};

/// Public member (UP) profile shown on a space page.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct MemberProfile {
    pub mid: i64,
    pub name: String,
    pub face: String,
    pub sign: String,
    pub level: i32,
    pub fans: i64,
    /// Number of users this member follows (`card.attention`).
    pub following: i64,
    /// Total likes received across the member's works (`like_num`).
    pub likes: i64,
    pub archive_count: i64,
    /// Whether the signed-in viewer follows this member.
    pub following_state: bool,
    pub official_title: String,
    pub official_type: i32,
    pub vip_status: bool,
    pub vip_label: String,
}

/// One UP contribution row from the App space cursor endpoint.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct MemberVideo {
    pub aid: i64,
    pub bvid: String,
    pub cid: i64,
    pub title: String,
    pub cover: String,
    pub duration_ms: i64,
    pub play: i64,
    pub danmaku: i64,
    pub ctime_ms: i64,
    pub author: String,
}

/// Paginated UP contribution list.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct MemberVideoPage {
    pub items: Vec<MemberVideo>,
    /// Pass back as `aid` to request the next page. `0` when there is no more.
    pub next_aid: i64,
    pub has_more: bool,
    pub total: i64,
}
