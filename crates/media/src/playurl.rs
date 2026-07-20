//! Parse Bilibili UGC playurl JSON into [`MediaSource`].

use crate::error::{Error, Result};
use crate::source::{MediaFormat, MediaSource, Stream, StreamId, SubtitleTrack};
use domain::id::Cid;
use domain::quality::{pick_quality, AudioTrack};
use domain::QualityQn;
use serde::Deserialize;
use serde_json::Value;
use std::collections::HashMap;

const WEB_REFERER: &str = "https://www.bilibili.com";
const DEFAULT_UA: &str = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36 NextPili/0.1";

/// qn → short display label.
pub fn quality_label(qn: u32) -> String {
    match qn {
        16 => "360P".into(),
        32 => "480P".into(),
        64 => "720P".into(),
        74 => "720P60".into(),
        80 => "1080P".into(),
        112 => "1080P+".into(),
        116 => "1080P60".into(),
        120 => "4K".into(),
        125 => "HDR".into(),
        126 => "杜比视界".into(),
        127 => "8K".into(),
        other => format!("qn{other}"),
    }
}

/// Parse playurl `data` object (already unwrapped from BiliResponse).
pub fn parse_playurl_data(
    cid: Cid,
    data: &Value,
    preferred_qn: Option<u32>,
) -> Result<MediaSource> {
    let raw: PlayUrlData = serde_json::from_value(data.clone())
        .map_err(|e| Error::Invalid(format!("playurl deserialize: {e}")))?;
    build_source(cid, raw, preferred_qn)
}

/// Parse full playurl JSON body or just the `data` object.
pub fn parse_playurl_json(
    cid: Cid,
    raw: &str,
    preferred_qn: Option<u32>,
) -> Result<MediaSource> {
    let v: Value = serde_json::from_str(raw)
        .map_err(|e| Error::Invalid(format!("playurl json: {e}")))?;
    let data = if v.get("data").is_some() {
        v.get("data")
            .cloned()
            .ok_or_else(|| Error::Invalid("playurl missing data".into()))?
    } else {
        v
    };
    parse_playurl_data(cid, &data, preferred_qn)
}

fn build_source(cid: Cid, raw: PlayUrlData, preferred_qn: Option<u32>) -> Result<MediaSource> {
    let mut headers = HashMap::new();
    headers.insert("Referer".into(), WEB_REFERER.into());
    headers.insert("User-Agent".into(), DEFAULT_UA.into());
    headers.insert("Origin".into(), "https://www.bilibili.com".into());

    let duration_ms = if raw.timelength > 0 {
        raw.timelength
    } else if let Some(d) = raw.dash.as_ref().and_then(|d| d.duration) {
        d.saturating_mul(1000)
    } else {
        0
    };

    let qn_desc: HashMap<u32, String> = raw
        .support_formats
        .iter()
        .filter_map(|f| {
            let label = f
                .new_description
                .clone()
                .or_else(|| f.display_desc.clone())
                .filter(|s| !s.is_empty())?;
            Some((f.quality, label))
        })
        .collect();

    if let Some(dash) = raw.dash {
        return build_dash(
            cid,
            dash,
            duration_ms,
            headers,
            preferred_qn.or(Some(raw.quality)).filter(|q| *q > 0),
            &qn_desc,
        );
    }

    if !raw.durl.is_empty() {
        return build_durl(
            cid,
            raw.durl,
            duration_ms,
            headers,
            raw.quality,
            &qn_desc,
        );
    }

    Err(Error::Invalid("playurl has neither dash nor durl".into()))
}

fn build_dash(
    cid: Cid,
    dash: DashRaw,
    duration_ms: i64,
    headers: HashMap<String, String>,
    preferred_qn: Option<u32>,
    qn_desc: &HashMap<u32, String>,
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
    for (i, a) in dash.audio.into_iter().enumerate() {
        let url = first_url(&a.base_url, &a.base_url_camel, &a.backup_url, &a.backup_url_camel);
        if url.is_empty() {
            continue;
        }
        audio_streams.push(Stream {
            id: format!("a-{}-{}", a.id, i),
            codec: a.codecs.unwrap_or_default(),
            bandwidth: a.bandwidth.unwrap_or(0),
            width: None,
            height: None,
            fps: None,
            quality_label: format!("audio-{}", a.id),
            qn: None,
            language: None,
            role: None,
            url,
            backup_urls: merge_backups(&a.backup_url, &a.backup_url_camel),
        });
    }

    if video_streams.is_empty() && audio_streams.is_empty() {
        return Err(Error::Invalid("dash has no playable streams".into()));
    }

    let default_video = pick_default_video(&video_streams, preferred_qn);
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

fn build_durl(
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

fn pick_default_video(streams: &[Stream], preferred_qn: Option<u32>) -> StreamId {
    if streams.is_empty() {
        return String::new();
    }
    let qns: Vec<QualityQn> = streams
        .iter()
        .filter_map(|s| s.qn.map(QualityQn))
        .collect();
    let pref = preferred_qn.unwrap_or(80);
    if let Some(pick) = pick_quality(&qns, QualityQn(pref), None) {
        // Prefer AVC when same qn has multiple codecs.
        let same: Vec<&Stream> = streams
            .iter()
            .filter(|x| x.qn == Some(pick.get()))
            .collect();
        if let Some(avc) = same.iter().find(|s| s.codec.starts_with("avc")) {
            return avc.id.clone();
        }
        if let Some(s) = same.first() {
            return s.id.clone();
        }
    }
    streams[0].id.clone()
}

fn pick_default_audio(streams: &[Stream]) -> StreamId {
    if streams.is_empty() {
        return String::new();
    }
    let tracks: Vec<AudioTrack> = streams
        .iter()
        .map(|s| AudioTrack {
            id: s.id.clone(),
            language: s.language.clone(),
            is_ai: s.role.as_deref() == Some("ai"),
        })
        .collect();
    domain::pick_audio_track(&tracks, None)
        .map(|t| t.id.clone())
        .unwrap_or_else(|| streams[0].id.clone())
}

fn first_url(
    base: &Option<String>,
    base_camel: &Option<String>,
    backup: &Option<Vec<String>>,
    backup_camel: &Option<Vec<String>>,
) -> String {
    base.as_ref()
        .filter(|s| !s.is_empty())
        .or(base_camel.as_ref().filter(|s| !s.is_empty()))
        .cloned()
        .or_else(|| {
            backup
                .as_ref()
                .and_then(|v| v.first())
                .filter(|s| !s.is_empty())
                .cloned()
        })
        .or_else(|| {
            backup_camel
                .as_ref()
                .and_then(|v| v.first())
                .filter(|s| !s.is_empty())
                .cloned()
        })
        .unwrap_or_default()
}

fn merge_backups(a: &Option<Vec<String>>, b: &Option<Vec<String>>) -> Vec<String> {
    let mut out = a.clone().unwrap_or_default();
    if out.is_empty() {
        out = b.clone().unwrap_or_default();
    }
    out
}

fn parse_fps(s: Option<&str>) -> Option<u32> {
    let s = s?;
    if s.is_empty() {
        return None;
    }
    if let Ok(f) = s.parse::<f64>() {
        return Some(f.round() as u32);
    }
    // "30000/1001"
    if let Some((n, d)) = s.split_once('/')
        && let (Ok(n), Ok(d)) = (n.parse::<f64>(), d.parse::<f64>())
        && d > 0.0
    {
        return Some((n / d).round() as u32);
    }
    None
}

// --- raw wire types ---

#[derive(Debug, Deserialize)]
struct PlayUrlData {
    #[serde(default)]
    quality: u32,
    #[serde(default)]
    timelength: i64,
    #[serde(default)]
    dash: Option<DashRaw>,
    #[serde(default)]
    durl: Vec<DurlRaw>,
    #[serde(default)]
    support_formats: Vec<SupportFormatRaw>,
}

#[derive(Debug, Deserialize)]
struct SupportFormatRaw {
    #[serde(default)]
    quality: u32,
    #[serde(default)]
    new_description: Option<String>,
    #[serde(default)]
    display_desc: Option<String>,
}

#[derive(Debug, Deserialize)]
struct DashRaw {
    #[serde(default)]
    duration: Option<i64>,
    #[serde(default)]
    video: Vec<DashStreamRaw>,
    #[serde(default)]
    audio: Vec<DashStreamRaw>,
}

#[derive(Debug, Deserialize)]
struct DashStreamRaw {
    #[serde(default)]
    id: u32,
    #[serde(default, rename = "base_url")]
    base_url: Option<String>,
    #[serde(default, rename = "baseUrl")]
    base_url_camel: Option<String>,
    #[serde(default, rename = "backup_url")]
    backup_url: Option<Vec<String>>,
    #[serde(default, rename = "backupUrl")]
    backup_url_camel: Option<Vec<String>>,
    #[serde(default)]
    bandwidth: Option<u32>,
    #[serde(default)]
    codecs: Option<String>,
    #[serde(default)]
    width: Option<u32>,
    #[serde(default)]
    height: Option<u32>,
    #[serde(default, rename = "frameRate")]
    frame_rate: Option<String>,
}

#[derive(Debug, Deserialize)]
struct DurlRaw {
    #[serde(default)]
    url: String,
    #[serde(default)]
    backup_url: Option<Vec<String>>,
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn parses_dash_fixture() {
        let data = json!({
            "quality": 80,
            "timelength": 125000,
            "support_formats": [
                { "quality": 80, "new_description": "1080P 高清", "display_desc": "1080P" },
                { "quality": 64, "new_description": "720P 高清", "display_desc": "720P" }
            ],
            "dash": {
                "duration": 125,
                "video": [
                    {
                        "id": 80,
                        "baseUrl": "https://example.com/v80.m4s",
                        "bandwidth": 2000000,
                        "codecs": "avc1.640032",
                        "width": 1920,
                        "height": 1080,
                        "frameRate": "30"
                    },
                    {
                        "id": 64,
                        "base_url": "https://example.com/v64.m4s",
                        "bandwidth": 1000000,
                        "codecs": "avc1.640028",
                        "width": 1280,
                        "height": 720,
                        "frameRate": "30"
                    }
                ],
                "audio": [
                    {
                        "id": 30280,
                        "baseUrl": "https://example.com/a.m4s",
                        "bandwidth": 128000,
                        "codecs": "mp4a.40.2"
                    }
                ]
            }
        });
        let src = parse_playurl_data(Cid(99), &data, Some(80)).unwrap();
        assert_eq!(src.format, MediaFormat::Dash);
        assert_eq!(src.video_streams.len(), 2);
        assert_eq!(src.audio_streams.len(), 1);
        assert_eq!(src.duration_ms, 125000);
        assert!(!src.default_video.is_empty());
        assert!(!src.default_audio.is_empty());
        assert_eq!(src.headers.get("Referer").unwrap(), WEB_REFERER);
        let def = src
            .video_streams
            .iter()
            .find(|s| s.id == src.default_video)
            .unwrap();
        assert_eq!(def.qn, Some(80));
    }

    #[test]
    fn parses_durl_fixture() {
        let data = json!({
            "quality": 32,
            "timelength": 60000,
            "durl": [
                {
                    "url": "https://example.com/seg.flv",
                    "backup_url": ["https://example.com/seg2.flv"]
                }
            ]
        });
        let src = parse_playurl_data(Cid(1), &data, None).unwrap();
        assert_eq!(src.format, MediaFormat::Segment);
        assert_eq!(src.video_streams.len(), 1);
        assert_eq!(src.video_streams[0].qn, Some(32));
    }

    #[test]
    fn quality_label_table() {
        assert_eq!(quality_label(80), "1080P");
        assert_eq!(quality_label(999), "qn999");
    }
}
