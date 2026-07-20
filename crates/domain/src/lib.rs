//! Pure domain layer: models, identifiers, errors, policies.
//!
//! **No IO** — no HTTP, filesystem, or database dependencies.

pub mod account;
pub mod danmaku;
pub mod engagement;
pub mod error;
pub mod feed;
pub mod id;
pub mod library;
pub mod quality;
pub mod reply;
pub mod search;
pub mod video;

pub use account::AccountPublic;
pub use danmaku::DanmakuItem;
pub use engagement::{default_fav_folder_id, ArchiveRelation};
pub use error::{map_bili_code, Error, Result};
pub use feed::FeedItem;
pub use id::{AccountId, Cid, DurationMs, QualityQn, UserMid, VideoId};
pub use library::{
    history_is_playable, FavFolder, FavFolderList, FavResourceItem, FavResourcePage, HistoryItem,
    HistoryPage, ToViewItem, ToViewPage,
};
pub use quality::{pick_audio_track, pick_quality, AudioTrack};
pub use reply::{Reply, ReplyPage};
pub use search::{parse_duration_label, strip_search_highlight, SearchVideoItem};
pub use video::{Owner, VideoDetail, VideoPage, VideoStat};
