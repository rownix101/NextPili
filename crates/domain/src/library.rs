use crate::id::DurationMs;
use serde::{Deserialize, Serialize};

/// One row from watch history (web cursor API).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct HistoryItem {
    pub aid: i64,
    pub bvid: String,
    pub cid: i64,
    pub title: String,
    pub cover: String,
    pub owner_name: String,
    pub duration_ms: DurationMs,
    /// Watched progress in milliseconds.
    pub progress_ms: i64,
    /// View time Unix **milliseconds**.
    pub view_at_ms: i64,
    /// `archive` / `pgc` / `live` / …
    pub business: String,
    pub kid: i64,
    pub show_title: String,
}

/// Cursor page of history.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct HistoryPage {
    pub items: Vec<HistoryItem>,
    pub next_max: i64,
    pub next_view_at: i64,
    pub next_business: String,
    pub has_more: bool,
}

/// One item in watch-later (稍后再看).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ToViewItem {
    pub aid: i64,
    pub bvid: String,
    pub cid: i64,
    pub title: String,
    pub cover: String,
    pub owner_name: String,
    pub duration_ms: DurationMs,
    pub progress_ms: i64,
    /// Added-at Unix **milliseconds**.
    pub add_at_ms: i64,
}

/// Paginated watch-later list.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ToViewPage {
    pub items: Vec<ToViewItem>,
    pub count: i32,
    pub pn: i32,
    pub has_more: bool,
}

/// Favorite folder metadata.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct FavFolder {
    pub id: i64,
    pub title: String,
    pub media_count: i32,
    pub cover: String,
    /// Bit0 = 0 default folder, 1 custom; bit1 private, …
    pub attr: i32,
    /// When listed with `rid` (aid), whether that resource is already in this folder.
    #[serde(default)]
    pub in_folder: bool,
}

/// Created folders for a user.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct FavFolderList {
    pub folders: Vec<FavFolder>,
    pub count: i32,
}

/// One media in a favorite folder.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct FavResourceItem {
    pub aid: i64,
    pub bvid: String,
    pub title: String,
    pub cover: String,
    pub owner_name: String,
    pub duration_ms: DurationMs,
    /// Favorited-at Unix **milliseconds**.
    pub fav_time_ms: i64,
}

/// Paginated folder contents.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct FavResourcePage {
    pub items: Vec<FavResourceItem>,
    pub media_id: i64,
    pub pn: i32,
    pub has_more: bool,
}

/// Whether a history business type can open the video detail path.
pub fn history_is_playable(business: &str) -> bool {
    matches!(business, "archive" | "pgc" | "")
}
