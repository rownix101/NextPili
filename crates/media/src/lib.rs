//! Media source parsing and pure selection helpers.
//!
//! Does **not** link any video player.

pub mod danmaku;
pub mod error;
pub mod playurl;
pub mod source;

pub use danmaku::normalize_danmaku;
pub use error::{Error, Result};
pub use playurl::{parse_playurl_data, parse_playurl_json, quality_label};
pub use source::{MediaFormat, MediaService, MediaSource, Stream, StreamId, SubtitleTrack};
