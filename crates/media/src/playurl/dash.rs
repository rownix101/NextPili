//! DASH playurl → MediaSource.

use crate::error::{Error, Result};
use crate::source::{MediaFormat, MediaSource, Stream, SubtitleTrack};
use domain::id::Cid;
use domain::HwDecodeCaps;
use std::collections::HashMap;

use super::labels::{audio_label, audio_role, quality_label};
use super::raw::{DashRaw, DashStreamRaw};
use super::select::{dedupe_audio_streams, pick_default_audio, pick_default_video, sort_video_streams_for_caps};
use super::util::{first_url, merge_backups, parse_fps};

pub(super) fn build_dash(
    cid: Cid,
    dash: DashRaw,
    duration_ms: i64,
    headers: HashMap<String, String>,
    preferred_qn: Option<u32>,
    qn_desc: &HashMap<u32, String>,
    hw_caps: HwDecodeCaps,
) -> Result<MediaSource> {
    let mut video_streams: Vec<Stream> = Vec::new();
    for (i, v) in dash.video.into_iter().enumerate() {
        let url = first_url(&v.base_url, &v.base_url_camel, &v.backup_url, &v.backup_url_camel);
        if url.is_empty() {
            continue;
        }
        let qn = if v.id > 0 { Some(v.id) } else { None };
        let label = qn
            .and_then(|q| qn_desc.get(&q).cloned())
            .or_else(|| qn.map(quality_label))
            .unwrap_or_else(|| format!("video-{i}"));
        let fps = parse_fps(v.frame_rate.as_deref());
        video_streams.push(Stream {
            id: format!("v-{}-{}", qn.unwrap_or(0), i),
            codec: v.codecs.unwrap_or_default(),
            bandwidth: v.bandwidth.unwrap_or(0),
            width: v.width,
            height: v.height,
            fps,
            quality_label: label,
            qn,
            language: None,
            role: None,
            url,
            backup_urls: merge_backups(&v.backup_url, &v.backup_url_camel),
        });
    }

    let mut audio_streams: Vec<Stream> = Vec::new();
    let mut push_audio = |a: DashStreamRaw, index: usize| {
        let url = first_url(&a.base_url, &a.base_url_camel, &a.backup_url, &a.backup_url_camel);
        if url.is_empty() {
            return;
        }
        let bw = a.bandwidth.unwrap_or(0);
        let role = audio_role(a.id);
        audio_streams.push(Stream {
            id: format!("a-{}-{}", a.id, index),
            codec: a.codecs.unwrap_or_default(),
            bandwidth: bw,
            width: None,
            height: None,
            fps: None,
            quality_label: audio_label(a.id, bw),
            // Reuse qn for DASH audio id so UI can group / prefer by code.
            qn: if a.id > 0 { Some(a.id) } else { None },
            language: None,
            role: Some(role.into()),
            url,
            backup_urls: merge_backups(&a.backup_url, &a.backup_url_camel),
        });
    };

    let mut idx = 0usize;
    for a in dash.audio {
        push_audio(a, idx);
        idx += 1;
    }
    // Dolby tracks often live under dash.dolby.audio (not only dash.audio).
    if let Some(dolby) = dash.dolby {
        for a in dolby.audio {
            push_audio(a, idx);
            idx += 1;
        }
    }
    // Hi-Res / FLAC may be a single object under dash.flac.audio.
    if let Some(flac) = dash.flac {
        if let Some(a) = flac.audio {
            push_audio(a, idx);
        }
    }

    // Dedupe by audio id (qn): keep highest bandwidth for each id.
    audio_streams = dedupe_audio_streams(audio_streams);

    if video_streams.is_empty() && audio_streams.is_empty() {
        return Err(Error::Invalid("dash has no playable streams".into()));
    }

    // Best codec first per qn so UI "first of each qn" keeps HW-preferred track.
    sort_video_streams_for_caps(&mut video_streams, hw_caps);

    let default_video = pick_default_video(&video_streams, preferred_qn, hw_caps);
    let default_audio = pick_default_audio(&audio_streams);

    Ok(MediaSource {
        cid,
        format: MediaFormat::Dash,
        video_streams,
        audio_streams,
        default_video,
        default_audio,
        duration_ms,
        headers,
        subtitles: Vec::<SubtitleTrack>::new(),
        requested_qn: preferred_qn,
    })
}
