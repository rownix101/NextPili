//! PGC (bangumi / movie / chinese anime) domain models.

use crate::id::DurationMs;
use serde::{Deserialize, Serialize};

/// One card in a PGC rank / index list.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PgcRankItem {
    pub season_id: i64,
    pub title: String,
    pub cover: String,
    /// Short badge, e.g. 会员 / 限免.
    pub badge: String,
    /// Rank index description, e.g. 更新至第 12 话.
    pub index_show: String,
    /// Score string or empty.
    pub rating: String,
    pub order: i32,
}

/// Rank page for a season type.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PgcRankPage {
    pub items: Vec<PgcRankItem>,
    pub season_type: i32,
    pub note: String,
}

/// One episode in a season.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PgcEpisode {
    pub ep_id: i64,
    pub aid: i64,
    pub bvid: String,
    pub cid: i64,
    /// Short index label, e.g. `1` / `SP`.
    pub title: String,
    /// Full episode title.
    pub long_title: String,
    pub cover: String,
    pub duration_ms: DurationMs,
    pub badge: String,
}

/// Season detail for the watch page.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PgcSeason {
    pub season_id: i64,
    pub season_title: String,
    pub title: String,
    pub cover: String,
    pub evaluate: String,
    /// Server type: 1 番剧 · 2 电影 · 3 纪录片 · 4 国创 · 5 电视剧 · 7 综艺 …
    pub season_type: i32,
    pub type_name: String,
    pub rating_score: String,
    pub episodes: Vec<PgcEpisode>,
    /// Suggested first ep (new_ep or first playable).
    pub default_ep_id: i64,
}

/// Season type display helpers.
pub fn pgc_season_type_label(season_type: i32) -> &'static str {
    match season_type {
        1 => "番剧",
        2 => "电影",
        3 => "纪录片",
        4 => "国创",
        5 => "电视剧",
        7 => "综艺",
        _ => "影视",
    }
}

/// Common web rank season types for MVP tabs.
pub const PGC_RANK_TYPES: &[(i32, &str)] = &[
    (1, "番剧"),
    (4, "国创"),
    (2, "电影"),
    (5, "电视剧"),
    (3, "纪录片"),
    (7, "综艺"),
];

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn type_labels() {
        assert_eq!(pgc_season_type_label(1), "番剧");
        assert_eq!(pgc_season_type_label(4), "国创");
    }
}
