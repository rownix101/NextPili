//! Live room models (recommend list + room metadata + stream options).

use serde::{Deserialize, Serialize};

/// One card in the live recommend feed.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LiveRoomCard {
    /// Real room id (prefer over short id for playurl).
    pub room_id: i64,
    pub uid: i64,
    pub title: String,
    pub uname: String,
    pub face: String,
    pub cover: String,
    pub online: i64,
    pub area_name: String,
}

/// Paginated recommend rooms.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LiveRecommendPage {
    pub items: Vec<LiveRoomCard>,
    pub page: i32,
    pub has_more: bool,
}

/// Room metadata for the watch page.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LiveRoomInfo {
    pub room_id: i64,
    pub short_id: i64,
    pub uid: i64,
    pub title: String,
    pub cover: String,
    pub uname: String,
    pub face: String,
    pub online: i64,
    /// 0 = offline, 1 = live, 2 = round (carousel).
    pub live_status: i32,
    pub area_name: String,
}

/// One muxed live stream option (FLV / HLS).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LiveStreamOption {
    pub id: String,
    pub protocol: String,
    pub format: String,
    pub codec: String,
    pub qn: u32,
    pub quality_label: String,
    pub url: String,
    pub backup_urls: Vec<String>,
}

/// Playable live source (normalized from `getRoomPlayInfo`).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LivePlaySource {
    pub room_id: i64,
    pub streams: Vec<LiveStreamOption>,
    pub default_stream_id: String,
    pub requested_qn: Option<u32>,
}

/// One live room chat message (history REST or future WS).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LiveDanmakuItem {
    pub uid: i64,
    pub uname: String,
    pub text: String,
    /// Unix time in **milliseconds** when known.
    pub timeline_ms: i64,
}

/// Live qn → short label.
pub fn live_quality_label(qn: u32) -> String {
    match qn {
        80 => "流畅".into(),
        150 => "高清".into(),
        250 => "超清".into(),
        400 => "蓝光".into(),
        10000 => "原画".into(),
        20000 => "4K".into(),
        30000 => "杜比".into(),
        other => format!("qn{other}"),
    }
}

/// Prefer HLS (ts/fmp4) then FLV; avc over hevc for broader playback.
pub fn live_stream_preference_score(protocol: &str, format: &str, codec: &str) -> i32 {
    let mut score = 0;
    match protocol {
        "http_hls" => score += 100,
        "http_stream" => score += 50,
        _ => {}
    }
    match format {
        "fmp4" => score += 20,
        "ts" => score += 15,
        "flv" => score += 10,
        _ => {}
    }
    match codec {
        "avc" => score += 5,
        "hevc" => score += 2,
        "av1" => score += 1,
        _ => {}
    }
    score
}

/// Pick default stream among options for preferred qn (0 = highest available).
pub fn pick_live_stream<'a>(
    streams: &'a [LiveStreamOption],
    preferred_qn: Option<u32>,
) -> Option<&'a LiveStreamOption> {
    if streams.is_empty() {
        return None;
    }
    if let Some(qn) = preferred_qn.filter(|q| *q > 0) {
        let same_qn: Vec<_> = streams.iter().filter(|s| s.qn == qn).collect();
        if !same_qn.is_empty() {
            return same_qn.into_iter().max_by_key(|s| {
                live_stream_preference_score(&s.protocol, &s.format, &s.codec)
            });
        }
    }
    // Highest qn, then preference score.
    streams.iter().max_by(|a, b| {
        a.qn
            .cmp(&b.qn)
            .then_with(|| {
                live_stream_preference_score(&a.protocol, &a.format, &a.codec)
                    .cmp(&live_stream_preference_score(
                        &b.protocol,
                        &b.format,
                        &b.codec,
                    ))
            })
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn labels() {
        assert_eq!(live_quality_label(10000), "原画");
        assert_eq!(live_quality_label(150), "高清");
    }

    #[test]
    fn prefers_hls_avc() {
        let flv = LiveStreamOption {
            id: "a".into(),
            protocol: "http_stream".into(),
            format: "flv".into(),
            codec: "avc".into(),
            qn: 10000,
            quality_label: "原画".into(),
            url: "u1".into(),
            backup_urls: vec![],
        };
        let hls = LiveStreamOption {
            id: "b".into(),
            protocol: "http_hls".into(),
            format: "fmp4".into(),
            codec: "avc".into(),
            qn: 10000,
            quality_label: "原画".into(),
            url: "u2".into(),
            backup_urls: vec![],
        };
        let streams = [flv, hls];
        let pick = pick_live_stream(&streams, Some(10000)).unwrap();
        assert_eq!(pick.id, "b");
    }
}
