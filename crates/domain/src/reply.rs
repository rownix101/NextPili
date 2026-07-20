use crate::id::UserMid;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Reply {
    pub rpid: i64,
    pub mid: UserMid,
    pub content: String,
    pub ctime_ms: i64,
    pub like: i64,
    pub children_count: i32,
}
