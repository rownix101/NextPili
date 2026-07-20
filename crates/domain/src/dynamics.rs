//! Follow-dynamics feed models (read-only).

use crate::id::DurationMs;
use serde::{Deserialize, Serialize};

/// One card in the polymer follow feed.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DynamicItem {
    /// Dynamic id (`id_str`).
    pub id: String,
    /// Server type tag, e.g. `DYNAMIC_TYPE_AV`.
    pub type_tag: String,
    pub author_mid: i64,
    pub author_name: String,
    pub author_face: String,
    /// Publish time in **milliseconds**.
    pub pub_ts_ms: i64,
    /// Plain text from `module_dynamic.desc` / opus summary.
    pub text: String,
    /// Major title (archive / article / live …).
    pub title: String,
    /// Major cover URL (normalized https when possible).
    pub cover: String,
    /// Linked archive aid when present.
    pub aid: i64,
    /// Linked archive bvid when present.
    pub bvid: String,
    pub duration_ms: DurationMs,
    pub like_count: i64,
    pub comment_count: i64,
    pub repost_count: i64,
}

/// Cursor page of dynamics.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DynamicPage {
    pub items: Vec<DynamicItem>,
    /// Pass as `offset` on the next call (empty = first page).
    pub next_offset: String,
    pub has_more: bool,
    pub update_baseline: String,
    pub update_num: i32,
}

/// Whether the item is a playable UGC archive card.
pub fn dynamic_is_archive(type_tag: &str) -> bool {
    matches!(
        type_tag,
        "DYNAMIC_TYPE_AV" | "DYNAMIC_TYPE_UGC_SEASON"
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn archive_tags() {
        assert!(dynamic_is_archive("DYNAMIC_TYPE_AV"));
        assert!(dynamic_is_archive("DYNAMIC_TYPE_UGC_SEASON"));
        assert!(!dynamic_is_archive("DYNAMIC_TYPE_WORD"));
    }
}
