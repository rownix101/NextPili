//! Pure domain layer: models, identifiers, errors, policies.
//!
//! **No IO** — no HTTP, filesystem, or database dependencies.

pub mod account;
pub mod codec;
pub mod danmaku;
pub mod dynamics;
pub mod engagement;
pub mod error;
pub mod feed;
pub mod id;
pub mod library;
pub mod live;
pub mod pgc;
pub mod quality;
pub mod reply;
pub mod search;
pub mod video;

pub use account::AccountPublic;
pub use codec::{
    classify_video_codec, pick_best_codec_stream, video_codec_score, GpuVendor, HwDecodeCaps,
    VideoCodecKind,
};
pub use danmaku::{DanmakuItem, DanmakuPostResult};
pub use dynamics::{dynamic_is_archive, DynamicItem, DynamicPage};
pub use engagement::{default_fav_folder_id, ArchiveRelation};
pub use error::{map_bili_code, Error, Result};
pub use feed::FeedItem;
pub use id::{AccountId, Cid, DurationMs, QualityQn, UserMid, VideoId};
pub use library::{
    history_is_playable, FavFolder, FavFolderList, FavResourceItem, FavResourcePage, HistoryItem,
    HistoryPage, ToViewItem, ToViewPage,
};
pub use live::{
    live_quality_label, live_stream_preference_score, pick_live_stream, pick_live_stream_with_caps,
    LiveDanmakuItem, LivePlaySource, LiveRecommendPage, LiveRoomCard, LiveRoomInfo,
    LiveStreamOption,
};
pub use pgc::{
    pgc_season_type_label, PgcEpisode, PgcRankItem, PgcRankPage, PgcSeason, PGC_RANK_TYPES,
};
pub use quality::{pick_audio_track, pick_quality, AudioTrack};
pub use reply::{Reply, ReplyAddResult, ReplyPage};
pub use search::{parse_duration_label, strip_search_highlight, SearchVideoItem};
pub use video::{Owner, VideoDetail, VideoPage, VideoStat};
