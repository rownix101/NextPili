use crate::id::DurationMs;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct FeedItem {
    pub aid: i64,
    pub bvid: String,
    pub title: String,
    pub cover: String,
    pub owner_name: String,
    pub duration_ms: DurationMs,
    /// Bilibili `goto` field; after filtering usually `av`.
    pub goto: String,
}

/// Whether a feed item should be kept for the home feed.
pub fn filter_feed_item(goto: &str, blacklisted_gotos: &[&str]) -> bool {
    if goto.is_empty() {
        return false;
    }
    !blacklisted_gotos.contains(&goto)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn filters_ads() {
        assert!(filter_feed_item("av", &["ad", "banner"]));
        assert!(!filter_feed_item("ad", &["ad", "banner"]));
        assert!(!filter_feed_item("", &[]));
    }
}
