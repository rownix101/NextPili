use crate::id::{AccountId, UserMid};
use serde::{Deserialize, Serialize};

/// Public account surface safe to show in UI / cross FFI later.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AccountPublic {
    pub id: AccountId,
    pub mid: UserMid,
    pub name: String,
    pub avatar_url: String,
    pub is_login: bool,
}
