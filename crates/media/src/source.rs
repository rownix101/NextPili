use crate::error::Result;
use crate::playurl;
use domain::id::Cid;
use domain::HwDecodeCaps;
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
    /// qn requested / preferred when building this source.
    pub requested_qn: Option<u32>,
}

/// Playurl normalization entrypoint.
#[derive(Debug, Clone)]
pub struct MediaService {
    hw_caps: HwDecodeCaps,
}

impl Default for MediaService {
    fn default() -> Self {
        Self::new()
    }
}

impl MediaService {
    pub fn new() -> Self {
        Self {
            hw_caps: HwDecodeCaps::default(),
        }
    }

    pub fn with_hw_caps(hw_caps: HwDecodeCaps) -> Self {
        Self { hw_caps }
    }

    pub fn hw_caps(&self) -> HwDecodeCaps {
        self.hw_caps
    }

    /// Parse raw playurl JSON (full body or `data` object) into [`MediaSource`].
    pub fn parse_playurl_json(
        &self,
        cid: Cid,
        raw: &str,
        preferred_qn: Option<u32>,
    ) -> Result<MediaSource> {
        playurl::parse_playurl_json_with_caps(cid, raw, preferred_qn, self.hw_caps)
    }

    /// Parse already-decoded playurl `data` value.
    pub fn parse_playurl_data(
        &self,
        cid: Cid,
        data: &serde_json::Value,
        preferred_qn: Option<u32>,
    ) -> Result<MediaSource> {
        playurl::parse_playurl_data_with_caps(cid, data, preferred_qn, self.hw_caps)
    }
}
