//! Viewer ↔ archive relationship (like / coin / fav / follow).

use serde::{Deserialize, Serialize};

/// Current user's engagement state for one archive (and its UP).
///
/// Values come from `GET /x/web-interface/archive/relation` after login.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, Default)]
pub struct ArchiveRelation {
    pub liked: bool,
    pub disliked: bool,
    /// Coins already cast on this archive (0..=2).
    pub coin: i32,
    pub favorited: bool,
    /// Whether the viewer follows the UP (`attention`).
    pub following: bool,
}

/// Pick default favorite folder id (`attr` bit0 == 0 → default).
///
/// Falls back to the first folder when no default bit is found.
pub fn default_fav_folder_id(folders: &[(i64, i32)]) -> Option<i64> {
    folders
        .iter()
        .find(|(_, attr)| attr & 1 == 0)
        .or_else(|| folders.first())
        .map(|(id, _)| *id)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn picks_default_folder_by_attr_bit0() {
        let folders = [(11, 1), (22, 0), (33, 3)];
        assert_eq!(default_fav_folder_id(&folders), Some(22));
    }

    #[test]
    fn falls_back_to_first_folder() {
        let folders = [(11, 1), (33, 3)];
        assert_eq!(default_fav_folder_id(&folders), Some(11));
    }

    #[test]
    fn empty_folders() {
        assert_eq!(default_fav_folder_id(&[]), None);
    }
}
