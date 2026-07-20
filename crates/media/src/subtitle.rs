//! Bilibili subtitle list parsing and JSON → WebVTT conversion.

use crate::error::{Error, Result};
use crate::source::SubtitleTrack;
use serde::Deserialize;
use serde_json::Value;

/// Extract subtitle tracks from `/x/player/wbi/v2` `data` JSON.
pub fn parse_player_v2_subtitles(data: &Value) -> Vec<SubtitleTrack> {
    let list = data
        .pointer("/subtitle/subtitles")
        .or_else(|| data.pointer("/subtitle/list"))
        .and_then(|v| v.as_array())
        .cloned()
        .unwrap_or_default();

    let mut out = Vec::new();
    for (i, item) in list.into_iter().enumerate() {
        let lan = item
            .get("lan")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string();
        let mut label = item
            .get("lan_doc")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string();
        if label.is_empty() {
            label = if lan.is_empty() {
                format!("subtitle-{i}")
            } else {
                lan.clone()
            };
        }
        let ty = item.get("type").and_then(|v| v.as_i64()).unwrap_or(0);
        if ty == 1 && !label.contains("AI") {
            label = format!("{label}（AI）");
        }
        let url = item
            .get("subtitle_url_v2")
            .and_then(|v| v.as_str())
            .filter(|s| !s.is_empty())
            .or_else(|| item.get("subtitle_url").and_then(|v| v.as_str()))
            .unwrap_or("")
            .to_string();
        if url.is_empty() {
            continue;
        }
        let id = item
            .get("id_str")
            .and_then(|v| v.as_str())
            .map(str::to_string)
            .or_else(|| {
                item.get("id")
                    .and_then(|v| v.as_i64().or_else(|| v.as_u64().map(|u| u as i64)))
                    .map(|n| n.to_string())
            })
            .unwrap_or_else(|| format!("sub-{i}"));

        out.push(SubtitleTrack {
            id,
            lang: lan,
            label,
            url: normalize_url(&url),
        });
    }
    out
}

/// Convert Bilibili subtitle JSON body (`{ body: [{from,to,content}] }`) to WebVTT.
pub fn bilibili_json_to_vtt(raw: &str) -> Result<String> {
    let doc: SubtitleDoc = serde_json::from_str(raw)
        .map_err(|e| Error::Invalid(format!("subtitle json: {e}")))?;
    let mut vtt = String::from("WEBVTT\n\n");
    for (i, cue) in doc.body.iter().enumerate() {
        if cue.content.trim().is_empty() {
            continue;
        }
        let from = format_vtt_ts(cue.from);
        let to = format_vtt_ts(cue.to);
        // Escape for WebVTT cue text (minimal).
        let text = cue
            .content
            .replace('&', "&amp;")
            .replace('<', "&lt;")
            .replace('\n', "\n");
        vtt.push_str(&format!("{}\n{} --> {}\n{}\n\n", i + 1, from, to, text));
    }
    Ok(vtt)
}

fn normalize_url(url: &str) -> String {
    if url.starts_with("//") {
        format!("https:{url}")
    } else if url.starts_with("http://") {
        format!("https://{}", url.trim_start_matches("http://"))
    } else {
        url.to_string()
    }
}

fn format_vtt_ts(sec: f64) -> String {
    let ms_total = (sec.max(0.0) * 1000.0).round() as u64;
    let h = ms_total / 3_600_000;
    let m = (ms_total % 3_600_000) / 60_000;
    let s = (ms_total % 60_000) / 1000;
    let ms = ms_total % 1000;
    format!("{:02}:{:02}:{:02}.{:03}", h, m, s, ms)
}

#[derive(Debug, Deserialize)]
struct SubtitleDoc {
    #[serde(default)]
    body: Vec<SubtitleCue>,
}

#[derive(Debug, Deserialize)]
struct SubtitleCue {
    #[serde(default)]
    from: f64,
    #[serde(default)]
    to: f64,
    #[serde(default)]
    content: String,
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn parses_player_v2_list() {
        let data = json!({
            "subtitle": {
                "subtitles": [
                    {
                        "id": 1,
                        "lan": "zh-CN",
                        "lan_doc": "中文（中国）",
                        "subtitle_url": "//i0.hdslb.com/bfs/subtitle/a.json",
                        "type": 0
                    },
                    {
                        "id": 2,
                        "lan": "ai-zh",
                        "lan_doc": "中文（自动生成）",
                        "subtitle_url": "//i0.hdslb.com/bfs/subtitle/b.json",
                        "type": 1
                    }
                ]
            }
        });
        let tracks = parse_player_v2_subtitles(&data);
        assert_eq!(tracks.len(), 2);
        assert!(tracks[0].url.starts_with("https://"));
        assert!(tracks[1].label.contains("AI"));
    }

    #[test]
    fn converts_body_to_vtt() {
        let raw = r#"{"body":[{"from":1.5,"to":3.25,"content":"你好"},{"from":4.0,"to":5.0,"content":"world"}]}"#;
        let vtt = bilibili_json_to_vtt(raw).unwrap();
        assert!(vtt.starts_with("WEBVTT"));
        assert!(vtt.contains("00:00:01.500 --> 00:00:03.250"));
        assert!(vtt.contains("你好"));
        assert!(vtt.contains("world"));
    }
}
