use crate::error::Result;
use domain::id::Cid;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

pub type StreamId = String;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum MediaFormat {
    Dash,
    Segment,
    Unknown,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Stream {
    pub id: StreamId,
    pub codec: String,
    pub bandwidth: u32,
    pub width: Option<u32>,
    pub height: Option<u32>,
    pub fps: Option<u32>,
    pub quality_label: String,
    pub qn: Option<u32>,
    pub language: Option<String>,
    pub role: Option<String>,
    pub url: String,
    pub backup_urls: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SubtitleTrack {
    pub id: String,
    pub lang: String,
    pub label: String,
    pub url: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct MediaSource {
    pub cid: Cid,
    pub format: MediaFormat,
    pub video_streams: Vec<Stream>,
    pub audio_streams: Vec<Stream>,
    pub default_video: StreamId,
    pub default_audio: StreamId,
    pub duration_ms: i64,
    pub headers: HashMap<String, String>,
    pub subtitles: Vec<SubtitleTrack>,
}

/// Playurl normalization entrypoint (stub until P3).
#[derive(Debug, Default, Clone)]
pub struct MediaService;

impl MediaService {
    pub fn new() -> Self {
        Self
    }

    /// Parse raw playurl JSON into [`MediaSource`].
    pub fn parse_playurl_json(&self, _cid: Cid, _raw: &str) -> Result<MediaSource> {
        Err(crate::error::Error::Invalid(
            "playurl parser not implemented (P3)".into(),
        ))
    }
}
