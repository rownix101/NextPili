//! FLV/MP4 segment (durl) playurl → MediaSource.

use crate::error::{Error, Result};
use crate::source::{MediaFormat, MediaSource, Stream};
use domain::id::Cid;
use std::collections::HashMap;

use super::labels::quality_label;
use super::raw::DurlRaw;

pub(super) fn build_durl(
    cid: Cid,
    durl: Vec<DurlRaw>,
    duration_ms: i64,
    headers: HashMap<String, String>,
    quality: u32,
    qn_desc: &HashMap<u32, String>,
) -> Result<MediaSource> {
    let mut video_streams = Vec::new();
    for (i, seg) in durl.into_iter().enumerate() {
        let url = if !seg.url.is_empty() {
            seg.url
        } else {
            continue;
        };
        let label = qn_desc
            .get(&quality)
            .cloned()
            .unwrap_or_else(|| quality_label(quality));
        video_streams.push(Stream {
            id: format!("seg-{i}"),
            codec: String::new(),
            bandwidth: 0,
            width: None,
            height: None,
            fps: None,
            quality_label: label,
            qn: if quality > 0 { Some(quality) } else { None },
            language: None,
            role: None,
            url,
            backup_urls: seg.backup_url.unwrap_or_default(),
        });
    }
    if video_streams.is_empty() {
        return Err(Error::Invalid("durl empty".into()));
    }
    let default_video = video_streams[0].id.clone();
    Ok(MediaSource {
        cid,
        format: MediaFormat::Segment,
        video_streams,
        audio_streams: Vec::new(),
        default_video,
        default_audio: String::new(),
        duration_ms,
        headers,
        subtitles: Vec::new(),
        requested_qn: if quality > 0 { Some(quality) } else { None },
    })
}
