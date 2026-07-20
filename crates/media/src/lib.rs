//! Media source parsing and pure selection helpers.
//!
//! Does **not** link any video player.

pub mod danmaku;
pub mod error;
pub mod playurl;
pub mod source;
pub mod subtitle;

pub use danmaku::{
    limit_danmaku, normalize_danmaku, parse_dm_seg_so, segment_index_for_progress,
    DANMAKU_SEGMENT_MS,
};
pub use error::{Error, Result};
pub use playurl::{
    audio_label, audio_role, parse_playurl_data, parse_playurl_data_with_caps, parse_playurl_json,
    parse_playurl_json_with_caps, quality_label, AUDIO_QN_192K, AUDIO_ROLE_DOLBY, AUDIO_ROLE_HIRES,
    AUDIO_ROLE_STANDARD,
};
pub use source::{MediaFormat, MediaService, MediaSource, Stream, StreamId, SubtitleTrack};
pub use subtitle::{bilibili_json_to_vtt, parse_player_v2_subtitles};
