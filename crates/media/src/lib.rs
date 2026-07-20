//! Media source parsing and pure selection helpers.
//!
//! Does **not** link any video player.

pub mod danmaku;
pub mod error;
pub mod playurl;
pub mod source;

pub use danmaku::{
    limit_danmaku, normalize_danmaku, parse_dm_seg_so, segment_index_for_progress,
    DANMAKU_SEGMENT_MS,
};
pub use error::{Error, Result};
pub use playurl::{parse_playurl_data, parse_playurl_json, quality_label};
pub use source::{MediaFormat, MediaService, MediaSource, Stream, StreamId, SubtitleTrack};
