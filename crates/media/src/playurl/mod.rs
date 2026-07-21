//! Parse Bilibili UGC playurl JSON into [`MediaSource`].

mod dash;
mod durl;
mod labels;
mod raw;
mod select;
mod util;

pub use labels::{
    audio_label, audio_role, quality_label, AUDIO_QN_192K, AUDIO_ROLE_DOLBY, AUDIO_ROLE_HIRES,
    AUDIO_ROLE_STANDARD,
};

use crate::error::{Error, Result};
use crate::source::MediaSource;
use domain::id::Cid;
use domain::HwDecodeCaps;
use serde_json::Value;
use std::collections::HashMap;

use dash::build_dash;
use durl::build_durl;
use raw::PlayUrlData;
use util::{DEFAULT_UA, WEB_REFERER};

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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::source::MediaFormat;
    use domain::id::Cid;
    use domain::HwDecodeCaps;
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
