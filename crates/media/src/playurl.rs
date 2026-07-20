//! Parse Bilibili UGC playurl JSON into [`MediaSource`].

use crate::error::{Error, Result};
use crate::source::{MediaFormat, MediaSource, Stream, StreamId, SubtitleTrack};
use domain::id::Cid;
use domain::quality::pick_quality;
use domain::classify_video_codec;
use domain::{pick_best_codec_stream, video_codec_score, HwDecodeCaps, QualityQn};
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

/// Preferred default standard audio qn (192K).
pub const AUDIO_QN_192K: u32 = 30280;

/// Audio role stored in [`Stream::role`].
pub const AUDIO_ROLE_STANDARD: &str = "standard";
pub const AUDIO_ROLE_DOLBY: &str = "dolby";
pub const AUDIO_ROLE_HIRES: &str = "hires";

/// Classify DASH audio id → role.
pub fn audio_role(id: u32) -> &'static str {
    match id {
        // Dolby Atmos / Dolby audio
        30250 | 30252 | 30255 => AUDIO_ROLE_DOLBY,
        // Hi-Res lossless
        30251 => AUDIO_ROLE_HIRES,
        _ => AUDIO_ROLE_STANDARD,
    }
}

/// DASH audio id → short menu label.
///
/// Standard ladder: 64K / 132K / 192K. Dolby & Hi-Res are independent options.
pub fn audio_label(id: u32, bandwidth: u32) -> String {
    match id {
        30216 => "64K".into(),
        30232 => "132K".into(),
        30280 => "192K".into(),
        30250 | 30252 | 30255 => "杜比全景声".into(),
        30251 => "Hi-Res".into(),
        // Unknown standard: show bitrate estimate.
        other if audio_role(other) == AUDIO_ROLE_STANDARD && bandwidth >= 1000 => {
            format!("{}K", bandwidth / 1000)
        }
        other => format!("audio-{other}"),
    }
}

/// Rank for default / menu sort (higher = preferred among standard).
/// Dolby / Hi-Res are not in the default ladder.
fn audio_standard_rank(id: u32, bandwidth: u32) -> u32 {
    match id {
        30280 => 192_000,
        30232 => 132_000,
        30216 => 64_000,
        _ => bandwidth.max(1),
    }
}

/// Parse playurl `data` object (already unwrapped from BiliResponse).
pub fn parse_playurl_data(
    cid: Cid,
    data: &Value,
    preferred_qn: Option<u32>,
) -> Result<MediaSource> {
    parse_playurl_data_with_caps(cid, data, preferred_qn, HwDecodeCaps::default())
}

/// Parse playurl with host HW-decode capability for codec preference.
pub fn parse_playurl_data_with_caps(
    cid: Cid,
    data: &Value,
    preferred_qn: Option<u32>,
    hw_caps: HwDecodeCaps,
) -> Result<MediaSource> {
    let raw: PlayUrlData = serde_json::from_value(data.clone())
        .map_err(|e| Error::Invalid(format!("playurl deserialize: {e}")))?;
    build_source(cid, raw, preferred_qn, hw_caps)
}

/// Parse full playurl JSON body or just the `data` object.
pub fn parse_playurl_json(
    cid: Cid,
    raw: &str,
    preferred_qn: Option<u32>,
) -> Result<MediaSource> {
    parse_playurl_json_with_caps(cid, raw, preferred_qn, HwDecodeCaps::default())
}

/// Parse playurl JSON with host HW-decode capability for codec preference.
pub fn parse_playurl_json_with_caps(
    cid: Cid,
    raw: &str,
    preferred_qn: Option<u32>,
    hw_caps: HwDecodeCaps,
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
    parse_playurl_data_with_caps(cid, &data, preferred_qn, hw_caps)
}

fn build_source(
    cid: Cid,
    raw: PlayUrlData,
    preferred_qn: Option<u32>,
    hw_caps: HwDecodeCaps,
) -> Result<MediaSource> {
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
            hw_caps,
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

fn sort_video_streams_for_caps(streams: &mut [Stream], hw_caps: HwDecodeCaps) {
    streams.sort_by(|a, b| {
        let qn = b.qn.unwrap_or(0).cmp(&a.qn.unwrap_or(0));
        if qn != std::cmp::Ordering::Equal {
            return qn;
        }
        let sa = video_codec_score(classify_video_codec(&a.codec), hw_caps);
        let sb = video_codec_score(classify_video_codec(&b.codec), hw_caps);
        sb.cmp(&sa)
            .then_with(|| b.bandwidth.cmp(&a.bandwidth))
            .then_with(|| a.id.cmp(&b.id))
    });
}

fn pick_default_video(
    streams: &[Stream],
    preferred_qn: Option<u32>,
    hw_caps: HwDecodeCaps,
) -> StreamId {
    if streams.is_empty() {
        return String::new();
    }
    let qns: Vec<QualityQn> = streams
        .iter()
        .filter_map(|s| s.qn.map(QualityQn))
        .collect();
    let pref = preferred_qn.unwrap_or(80);
    if let Some(pick) = pick_quality(&qns, QualityQn(pref), None) {
        let same: Vec<&Stream> = streams
            .iter()
            .filter(|x| x.qn == Some(pick.get()))
            .collect();
        if let Some(best) = pick_best_codec_stream(
            &same,
            hw_caps,
            |s| s.codec.as_str(),
            |s| s.bandwidth,
            |s| s.id.as_str(),
        ) {
            return best.id.clone();
        }
    }
    streams[0].id.clone()
}

/// Default audio: **192K if present**, else highest **standard** track.
/// Dolby / Hi-Res are never auto-selected (opt-in menu only).
fn pick_default_audio(streams: &[Stream]) -> StreamId {
    if streams.is_empty() {
        return String::new();
    }

    // Exact 192K.
    if let Some(s) = streams.iter().find(|s| {
        s.qn == Some(AUDIO_QN_192K) && s.role.as_deref() != Some(AUDIO_ROLE_DOLBY)
    }) {
        return s.id.clone();
    }

    // Highest standard (non-dolby, non-hires).
    let mut standard: Vec<&Stream> = streams
        .iter()
        .filter(|s| {
            let role = s.role.as_deref().unwrap_or(AUDIO_ROLE_STANDARD);
            role == AUDIO_ROLE_STANDARD
        })
        .collect();
    if !standard.is_empty() {
        standard.sort_by_key(|s| {
            let qn = s.qn.unwrap_or(0);
            std::cmp::Reverse(audio_standard_rank(qn, s.bandwidth))
        });
        return standard[0].id.clone();
    }

    // Only special tracks available — pick first (rare).
    streams[0].id.clone()
}

fn dedupe_audio_streams(streams: Vec<Stream>) -> Vec<Stream> {
    use std::collections::HashMap;
    let mut best: HashMap<u32, Stream> = HashMap::new();
    let mut no_qn = Vec::new();
    for s in streams {
        match s.qn {
            Some(q) => {
                best.entry(q)
                    .and_modify(|cur| {
                        if s.bandwidth > cur.bandwidth {
                            *cur = s.clone();
                        }
                    })
                    .or_insert(s);
            }
            None => no_qn.push(s),
        }
    }
    let mut out: Vec<Stream> = best.into_values().collect();
    out.extend(no_qn);
    // Menu order: standard high→low, then Dolby, then Hi-Res.
    out.sort_by(|a, b| {
        let ra = a.role.as_deref().unwrap_or(AUDIO_ROLE_STANDARD);
        let rb = b.role.as_deref().unwrap_or(AUDIO_ROLE_STANDARD);
        let order = |r: &str| match r {
            AUDIO_ROLE_STANDARD => 0,
            AUDIO_ROLE_DOLBY => 1,
            AUDIO_ROLE_HIRES => 2,
            _ => 3,
        };
        order(ra)
            .cmp(&order(rb))
            .then_with(|| {
                let qa = a.qn.unwrap_or(0);
                let qb = b.qn.unwrap_or(0);
                audio_standard_rank(qb, b.bandwidth).cmp(&audio_standard_rank(qa, a.bandwidth))
            })
    });
    out
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

/// Bilibili often emits `"field": null` for empty lists; bare `Vec` + `default` only
/// covers *missing* keys, not null → "invalid type: null, expected a sequence".
fn null_as_default<'de, D, T>(deserializer: D) -> std::result::Result<T, D::Error>
where
    D: serde::Deserializer<'de>,
    T: Default + Deserialize<'de>,
{
    Ok(Option::<T>::deserialize(deserializer)?.unwrap_or_default())
}

#[derive(Debug, Deserialize)]
struct PlayUrlData {
    #[serde(default)]
    quality: u32,
    #[serde(default)]
    timelength: i64,
    #[serde(default)]
    dash: Option<DashRaw>,
    #[serde(default, deserialize_with = "null_as_default")]
    durl: Vec<DurlRaw>,
    #[serde(default, deserialize_with = "null_as_default")]
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
    #[serde(default, deserialize_with = "null_as_default")]
    video: Vec<DashStreamRaw>,
    #[serde(default, deserialize_with = "null_as_default")]
    audio: Vec<DashStreamRaw>,
    #[serde(default)]
    dolby: Option<DashDolbyRaw>,
    #[serde(default)]
    flac: Option<DashFlacRaw>,
}

#[derive(Debug, Deserialize)]
struct DashDolbyRaw {
    #[serde(default, deserialize_with = "null_as_default")]
    audio: Vec<DashStreamRaw>,
}

#[derive(Debug, Deserialize)]
struct DashFlacRaw {
    /// Single FLAC / Hi-Res stream object (not a list).
    #[serde(default)]
    audio: Option<DashStreamRaw>,
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

    #[test]
    fn default_audio_prefers_192k() {
        let data = json!({
            "quality": 80,
            "timelength": 1000,
            "dash": {
                "video": [{
                    "id": 80,
                    "baseUrl": "https://example.com/v.m4s",
                    "bandwidth": 1,
                    "codecs": "avc1"
                }],
                "audio": [
                    {
                        "id": 30216,
                        "baseUrl": "https://example.com/a64.m4s",
                        "bandwidth": 64000,
                        "codecs": "mp4a"
                    },
                    {
                        "id": 30280,
                        "baseUrl": "https://example.com/a192.m4s",
                        "bandwidth": 192000,
                        "codecs": "mp4a"
                    },
                    {
                        "id": 30232,
                        "baseUrl": "https://example.com/a132.m4s",
                        "bandwidth": 132000,
                        "codecs": "mp4a"
                    }
                ],
                "dolby": {
                    "audio": [{
                        "id": 30250,
                        "baseUrl": "https://example.com/dolby.m4s",
                        "bandwidth": 768000,
                        "codecs": "ec-3"
                    }]
                },
                "flac": {
                    "audio": {
                        "id": 30251,
                        "baseUrl": "https://example.com/hires.m4s",
                        "bandwidth": 900000,
                        "codecs": "fLaC"
                    }
                }
            }
        });
        let src = parse_playurl_data(Cid(1), &data, None).unwrap();
        assert_eq!(src.audio_streams.len(), 5);
        let def = src
            .audio_streams
            .iter()
            .find(|s| s.id == src.default_audio)
            .unwrap();
        assert_eq!(def.qn, Some(AUDIO_QN_192K));
        assert_eq!(def.role.as_deref(), Some(AUDIO_ROLE_STANDARD));
        assert!(src
            .audio_streams
            .iter()
            .any(|s| s.role.as_deref() == Some(AUDIO_ROLE_DOLBY)));
        assert!(src
            .audio_streams
            .iter()
            .any(|s| s.role.as_deref() == Some(AUDIO_ROLE_HIRES)));
    }

    #[test]
    fn default_audio_falls_to_highest_standard() {
        let data = json!({
            "quality": 80,
            "timelength": 1000,
            "dash": {
                "video": [{
                    "id": 80,
                    "baseUrl": "https://example.com/v.m4s",
                    "bandwidth": 1,
                    "codecs": "avc1"
                }],
                "audio": [
                    {
                        "id": 30216,
                        "baseUrl": "https://example.com/a64.m4s",
                        "bandwidth": 64000,
                        "codecs": "mp4a"
                    },
                    {
                        "id": 30232,
                        "baseUrl": "https://example.com/a132.m4s",
                        "bandwidth": 132000,
                        "codecs": "mp4a"
                    }
                ],
                "dolby": {
                    "audio": [{
                        "id": 30250,
                        "baseUrl": "https://example.com/dolby.m4s",
                        "bandwidth": 768000,
                        "codecs": "ec-3"
                    }]
                }
            }
        });
        let src = parse_playurl_data(Cid(1), &data, None).unwrap();
        let def = src
            .audio_streams
            .iter()
            .find(|s| s.id == src.default_audio)
            .unwrap();
        // No 192K → 132K is highest standard (not Dolby).
        assert_eq!(def.qn, Some(30232));
        assert_eq!(def.role.as_deref(), Some(AUDIO_ROLE_STANDARD));
    }

    #[test]
    fn audio_label_roles() {
        assert_eq!(audio_label(30280, 0), "192K");
        assert_eq!(audio_label(30250, 0), "杜比全景声");
        assert_eq!(audio_label(30251, 0), "Hi-Res");
        assert_eq!(audio_role(30255), AUDIO_ROLE_DOLBY);
    }

    #[test]
    fn null_lists_ok() {
        // API often uses null instead of [] for empty arrays.
        let data = json!({
            "quality": 80,
            "timelength": 1000,
            "durl": null,
            "support_formats": null,
            "dash": {
                "video": [{
                    "id": 80,
                    "baseUrl": "https://example.com/v.m4s",
                    "bandwidth": 1,
                    "codecs": "avc1",
                    "backupUrl": null
                }],
                "audio": null,
                "dolby": { "audio": null }
            }
        });
        let src = parse_playurl_data(Cid(1), &data, Some(80)).unwrap();
        assert_eq!(src.video_streams.len(), 1);
        assert!(src.audio_streams.is_empty());
    }

    #[test]
    fn picks_hw_hevc_over_soft_av1_on_rx580() {
        let data = json!({
            "quality": 80,
            "timelength": 1000,
            "dash": {
                "video": [
                    {
                        "id": 80,
                        "baseUrl": "https://example.com/av1.m4s",
                        "bandwidth": 500000,
                        "codecs": "av01.0.08M.08"
                    },
                    {
                        "id": 80,
                        "baseUrl": "https://example.com/hevc.m4s",
                        "bandwidth": 600000,
                        "codecs": "hev1.1.6.L150.90"
                    },
                    {
                        "id": 80,
                        "baseUrl": "https://example.com/avc.m4s",
                        "bandwidth": 800000,
                        "codecs": "avc1.640032"
                    }
                ],
                "audio": [{
                    "id": 30280,
                    "baseUrl": "https://example.com/a.m4s",
                    "bandwidth": 192000
                }]
            }
        });
        let caps = HwDecodeCaps::from_pci(0x1002, 0x6fdf);
        let src = parse_playurl_data_with_caps(Cid(1), &data, Some(80), caps).unwrap();
        let def = src
            .video_streams
            .iter()
            .find(|s| s.id == src.default_video)
            .unwrap();
        assert!(def.codec.starts_with("hev"), "got {}", def.codec);
    }

    #[test]
    fn picks_av1_when_hw_supports() {
        let data = json!({
            "quality": 80,
            "timelength": 1000,
            "dash": {
                "video": [
                    {
                        "id": 80,
                        "baseUrl": "https://example.com/avc.m4s",
                        "bandwidth": 800000,
                        "codecs": "avc1.640032"
                    },
                    {
                        "id": 80,
                        "baseUrl": "https://example.com/av1.m4s",
                        "bandwidth": 500000,
                        "codecs": "av01.0.08M.08"
                    }
                ],
                "audio": []
            }
        });
        let caps = HwDecodeCaps::from_pci(0x10de, 0x2204);
        let src = parse_playurl_data_with_caps(Cid(1), &data, Some(80), caps).unwrap();
        let def = src
            .video_streams
            .iter()
            .find(|s| s.id == src.default_video)
            .unwrap();
        assert!(def.codec.starts_with("av01"), "got {}", def.codec);
    }
}
