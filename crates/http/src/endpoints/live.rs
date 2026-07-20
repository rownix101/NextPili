//! Live recommend + room info + playurl + chat send/history (REST; WS later).

use crate::client::{BiliClient, RequestOptions};
use crate::error::{Error, Result};
use auth::{Account, LIVE_BASE, WbiSigner};
use domain::live::{
    live_quality_label, pick_live_stream, LiveDanmakuItem, LivePlaySource, LiveRecommendPage,
    LiveRoomCard, LiveRoomInfo, LiveStreamOption,
};
use serde::Deserialize;
use serde_json::Value;
use std::collections::BTreeMap;
use std::time::{SystemTime, UNIX_EPOCH};

/// Live API surface.
pub struct LiveApi;

impl LiveApi {
    /// Web recommend rooms: `GET /xlive/web-interface/v1/second/getUserRecommend`.
    pub async fn recommend(
        client: &BiliClient,
        account: Option<&Account>,
        device_buvid3: Option<&str>,
        page: i32,
        page_size: u32,
    ) -> Result<LiveRecommendPage> {
        let page = page.max(1);
        let page_size = page_size.clamp(1, 30);

        let mut params = BTreeMap::new();
        params.insert("page".into(), page.to_string());
        params.insert("page_size".into(), page_size.to_string());
        params.insert("platform".into(), "web".into());

        let url = BiliClient::resolve_url(
            LIVE_BASE,
            "/xlive/web-interface/v1/second/getUserRecommend",
        );
        let opts = RequestOptions {
            account,
            device_buvid3,
            auth: if account.is_some() {
                crate::middleware::AuthMode::Cookie
            } else {
                crate::middleware::AuthMode::OptionalLogin
            },
            ..RequestOptions::default()
        }
        .with_referer("https://live.bilibili.com/");

        let resp = client.get_bili::<RecommendData>(&url, params, opts).await?;
        let data = resp.into_data()?;
        let items = data
            .list
            .unwrap_or_default()
            .into_iter()
            .filter_map(parse_card)
            .collect::<Vec<_>>();
        let has_more = !items.is_empty() && items.len() as u32 >= page_size;

        Ok(LiveRecommendPage {
            items,
            page,
            has_more,
        })
    }

    /// Room H5 info: `GET /xlive/web-room/v1/index/getH5InfoByRoom`.
    pub async fn room_info(
        client: &BiliClient,
        account: Option<&Account>,
        device_buvid3: Option<&str>,
        room_id: i64,
    ) -> Result<LiveRoomInfo> {
        if room_id <= 0 {
            return Err(Error::Domain(domain::Error::InvalidArgument {
                msg: "room_id must be > 0".into(),
            }));
        }

        let mut params = BTreeMap::new();
        params.insert("room_id".into(), room_id.to_string());

        let url = BiliClient::resolve_url(
            LIVE_BASE,
            "/xlive/web-room/v1/index/getH5InfoByRoom",
        );
        let referer = format!("https://live.bilibili.com/{room_id}");
        let opts = RequestOptions {
            account,
            device_buvid3,
            auth: if account.is_some() {
                crate::middleware::AuthMode::Cookie
            } else {
                crate::middleware::AuthMode::OptionalLogin
            },
            ..RequestOptions::default()
        }
        .with_referer(&referer);

        let resp = client.get_bili::<H5InfoData>(&url, params, opts).await?;
        let data = resp.into_data()?;
        parse_room_info(data, room_id)
    }

    /// Play streams: `GET /xlive/web-room/v2/index/getRoomPlayInfo` (WBI).
    pub async fn play_url(
        client: &BiliClient,
        account: Option<&Account>,
        device_buvid3: Option<&str>,
        wbi: &WbiSigner,
        room_id: i64,
        qn: u32,
    ) -> Result<LivePlaySource> {
        if room_id <= 0 {
            return Err(Error::Domain(domain::Error::InvalidArgument {
                msg: "room_id must be > 0".into(),
            }));
        }

        let qn = if qn == 0 { 10000 } else { qn };

        let mut params = BTreeMap::new();
        params.insert("room_id".into(), room_id.to_string());
        params.insert("protocol".into(), "0,1".into());
        params.insert("format".into(), "0,1,2".into());
        params.insert("codec".into(), "0,1".into());
        params.insert("qn".into(), qn.to_string());
        params.insert("platform".into(), "web".into());
        params.insert("ptype".into(), "8".into());
        params.insert("dolby".into(), "5".into());
        params.insert("panorama".into(), "1".into());

        let url = BiliClient::resolve_url(
            LIVE_BASE,
            "/xlive/web-room/v2/index/getRoomPlayInfo",
        );
        let referer = format!("https://live.bilibili.com/{room_id}");
        let mut opts = RequestOptions {
            account,
            device_buvid3,
            auth: if account.is_some() {
                crate::middleware::AuthMode::Cookie
            } else {
                crate::middleware::AuthMode::OptionalLogin
            },
            ..RequestOptions::default()
        };
        opts = opts.with_wbi(wbi).with_referer(&referer);

        let resp = client.get_bili::<PlayInfoData>(&url, params, opts).await?;
        let data = resp.into_data()?;
        parse_play_source(data, room_id, qn)
    }

    /// Recent room chat: `GET /xlive/web-room/v1/dM/gethistory`.
    pub async fn dm_history(
        client: &BiliClient,
        account: Option<&Account>,
        device_buvid3: Option<&str>,
        room_id: i64,
    ) -> Result<Vec<LiveDanmakuItem>> {
        if room_id <= 0 {
            return Err(Error::Domain(domain::Error::InvalidArgument {
                msg: "room_id must be > 0".into(),
            }));
        }

        let mut params = BTreeMap::new();
        params.insert("roomid".into(), room_id.to_string());

        let url = BiliClient::resolve_url(LIVE_BASE, "/xlive/web-room/v1/dM/gethistory");
        let referer = format!("https://live.bilibili.com/{room_id}");
        let opts = RequestOptions {
            account,
            device_buvid3,
            auth: if account.is_some() {
                crate::middleware::AuthMode::Cookie
            } else {
                crate::middleware::AuthMode::OptionalLogin
            },
            ..RequestOptions::default()
        }
        .with_referer(&referer);

        let resp = client.get_bili::<HistoryData>(&url, params, opts).await?;
        let data = resp.into_data().unwrap_or_default();
        Ok(parse_history(data))
    }

    /// Send live danmaku: `POST /msg/send` (Cookie + csrf).
    pub async fn send_msg(
        client: &BiliClient,
        account: &Account,
        device_buvid3: Option<&str>,
        room_id: i64,
        msg: &str,
        color: u32,
        fontsize: i32,
        mode: i32,
    ) -> Result<()> {
        if room_id <= 0 {
            return Err(Error::Domain(domain::Error::InvalidArgument {
                msg: "room_id must be > 0".into(),
            }));
        }
        let msg = msg.trim();
        if msg.is_empty() {
            return Err(Error::Domain(domain::Error::InvalidArgument {
                msg: "msg must not be empty".into(),
            }));
        }
        if msg.chars().count() > 100 {
            return Err(Error::Domain(domain::Error::InvalidArgument {
                msg: "msg too long (max 100)".into(),
            }));
        }
        let color = if color == 0 { 16_777_215 } else { color };
        let fontsize = if fontsize <= 0 { 25 } else { fontsize };
        let mode = if mode == 0 { 1 } else { mode };
        let rnd = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.as_secs() as i64)
            .unwrap_or(0);

        let mut params = BTreeMap::new();
        params.insert("roomid".into(), room_id.to_string());
        params.insert("msg".into(), msg.to_string());
        params.insert("color".into(), color.to_string());
        params.insert("fontsize".into(), fontsize.to_string());
        params.insert("mode".into(), mode.to_string());
        params.insert("bubble".into(), "0".into());
        params.insert("rnd".into(), rnd.to_string());
        // Live web also echoes csrf as csrf_token.
        if let Some(csrf) = account.cookie_jar.csrf() {
            params.insert("csrf_token".into(), csrf.to_string());
        }

        let url = BiliClient::resolve_url(LIVE_BASE, "/msg/send");
        let referer = format!("https://live.bilibili.com/{room_id}");
        let opts = RequestOptions {
            account: Some(account),
            device_buvid3,
            auth: crate::middleware::AuthMode::Cookie,
            csrf: true,
            ..RequestOptions::default()
        }
        .with_referer(&referer);

        let resp = client.post_form_bili::<Value>(&url, params, opts).await?;
        resp.ensure_ok()
    }
}

#[derive(Debug, Deserialize, Default)]
struct HistoryData {
    #[serde(default)]
    room: Option<Vec<Value>>,
    #[serde(default)]
    admin: Option<Vec<Value>>,
}

#[derive(Debug, Deserialize)]
struct RecommendData {
    #[serde(default)]
    list: Option<Vec<Value>>,
}

#[derive(Debug, Deserialize)]
struct H5InfoData {
    #[serde(default)]
    room_info: Option<Value>,
    #[serde(default)]
    anchor_info: Option<Value>,
}

#[derive(Debug, Deserialize)]
struct PlayInfoData {
    #[serde(default)]
    room_id: Option<i64>,
    #[serde(default)]
    live_status: Option<i32>,
    #[serde(default)]
    playurl_info: Option<Value>,
}

fn parse_card(v: Value) -> Option<LiveRoomCard> {
    let room_id = json_i64(&v, "roomid")
        .max(json_i64(&v, "room_id"))
        .max(0);
    if room_id <= 0 {
        return None;
    }
    let title = json_str(&v, "title");
    if title.is_empty() {
        return None;
    }
    let cover = first_nonempty(&[
        normalize_cover(&json_str(&v, "cover")),
        normalize_cover(&json_str(&v, "user_cover")),
        normalize_cover(&json_str(&v, "system_cover")),
        normalize_cover(&json_str(&v, "keyframes")),
    ]);
    let face = normalize_cover(&json_str(&v, "face"));
    let uname = first_nonempty(&[json_str(&v, "uname"), json_str(&v, "username")]);
    let area_name = first_nonempty(&[
        json_str(&v, "area_v2_name"),
        json_str(&v, "area_name"),
    ]);
    Some(LiveRoomCard {
        room_id,
        uid: json_i64(&v, "uid"),
        title,
        uname,
        face,
        cover,
        online: json_i64(&v, "online"),
        area_name,
    })
}

fn parse_room_info(data: H5InfoData, fallback_room_id: i64) -> Result<LiveRoomInfo> {
    let room = data.room_info.unwrap_or(Value::Null);
    let room_id = json_i64(&room, "room_id").max(fallback_room_id);
    if room_id <= 0 {
        return Err(Error::Domain(domain::Error::NotFound));
    }
    let anchor = data
        .anchor_info
        .as_ref()
        .and_then(|a| a.get("base_info"))
        .cloned()
        .unwrap_or(Value::Null);

    Ok(LiveRoomInfo {
        room_id,
        short_id: json_i64(&room, "short_id"),
        uid: json_i64(&room, "uid"),
        title: json_str(&room, "title"),
        cover: normalize_cover(&json_str(&room, "cover")),
        uname: json_str(&anchor, "uname"),
        face: normalize_cover(&json_str(&anchor, "face")),
        online: json_i64(&room, "online"),
        live_status: json_i64(&room, "live_status") as i32,
        area_name: first_nonempty(&[
            json_str(&room, "area_name"),
            json_str(&room, "parent_area_name"),
        ]),
    })
}

fn parse_play_source(data: PlayInfoData, fallback_room_id: i64, requested_qn: u32) -> Result<LivePlaySource> {
    let room_id = data.room_id.unwrap_or(fallback_room_id).max(fallback_room_id);
    if data.live_status == Some(0) {
        return Err(Error::Domain(domain::Error::Api {
            code: 60004,
            message: "主播未开播".into(),
        }));
    }

    let playurl = data
        .playurl_info
        .as_ref()
        .and_then(|p| p.get("playurl"))
        .cloned()
        .unwrap_or(Value::Null);
    let streams_raw = playurl
        .get("stream")
        .and_then(|s| s.as_array())
        .cloned()
        .unwrap_or_default();

    let mut streams = Vec::new();
    for stream in streams_raw {
        let protocol = json_str(&stream, "protocol_name");
        let formats = stream
            .get("format")
            .and_then(|f| f.as_array())
            .cloned()
            .unwrap_or_default();
        for format in formats {
            let format_name = json_str(&format, "format_name");
            let codecs = format
                .get("codec")
                .and_then(|c| c.as_array())
                .cloned()
                .unwrap_or_default();
            for codec in codecs {
                let codec_name = json_str(&codec, "codec_name");
                let qn = json_i64(&codec, "current_qn").max(0) as u32;
                if qn == 0 {
                    continue;
                }
                let base_url = json_str(&codec, "base_url");
                if base_url.is_empty() {
                    continue;
                }
                let url_infos = codec
                    .get("url_info")
                    .and_then(|u| u.as_array())
                    .cloned()
                    .unwrap_or_default();
                let mut urls = Vec::new();
                for info in &url_infos {
                    let host = json_str(info, "host");
                    let extra = json_str(info, "extra");
                    if host.is_empty() {
                        continue;
                    }
                    urls.push(format!("{host}{base_url}{extra}"));
                }
                if urls.is_empty() {
                    continue;
                }
                let primary = urls.remove(0);
                let id = format!("{protocol}/{format_name}/{codec_name}/qn{qn}");
                streams.push(LiveStreamOption {
                    id,
                    protocol: protocol.clone(),
                    format: format_name.clone(),
                    codec: codec_name,
                    qn,
                    quality_label: live_quality_label(qn),
                    url: primary,
                    backup_urls: urls,
                });
            }
        }
    }

    if streams.is_empty() {
        return Err(Error::Domain(domain::Error::Api {
            code: -1,
            message: "无可播放的直播流".into(),
        }));
    }

    // Deduplicate by id (same qn/protocol may appear twice).
    streams.sort_by(|a, b| a.id.cmp(&b.id));
    streams.dedup_by(|a, b| a.id == b.id);

    let default_id = pick_live_stream(&streams, Some(requested_qn))
        .map(|s| s.id.clone())
        .unwrap_or_else(|| streams[0].id.clone());

    Ok(LivePlaySource {
        room_id,
        streams,
        default_stream_id: default_id,
        requested_qn: Some(requested_qn),
    })
}

fn parse_history(data: HistoryData) -> Vec<LiveDanmakuItem> {
    let mut out = Vec::new();
    for list in [data.admin, data.room] {
        let Some(items) = list else { continue };
        for v in items {
            let text = first_nonempty(&[json_str(&v, "text"), json_str(&v, "msg")]);
            if text.is_empty() {
                continue;
            }
            let uname = first_nonempty(&[json_str(&v, "nickname"), json_str(&v, "uname")]);
            let uid = json_i64(&v, "uid").max(json_i64(&v, "mid"));
            let timeline = json_str(&v, "timeline");
            let timeline_ms = parse_timeline_ms(&timeline);
            out.push(LiveDanmakuItem {
                uid,
                uname,
                text,
                timeline_ms,
            });
        }
    }
    out
}

/// `timeline` is often `"2024-01-02 15:04:05"`; keep 0 when unparsable.
fn parse_timeline_ms(s: &str) -> i64 {
    if s.is_empty() {
        return 0;
    }
    // Prefer pure unix if API ever returns it.
    if let Ok(secs) = s.parse::<i64>() {
        return secs.saturating_mul(1000);
    }
    0
}

fn json_str(v: &Value, key: &str) -> String {
    match v.get(key) {
        Some(Value::String(s)) => s.clone(),
        Some(Value::Number(n)) => n.to_string(),
        _ => String::new(),
    }
}

fn json_i64(v: &Value, key: &str) -> i64 {
    match v.get(key) {
        Some(Value::Number(n)) => n.as_i64().unwrap_or(0),
        Some(Value::String(s)) => s.parse().unwrap_or(0),
        _ => 0,
    }
}

fn normalize_cover(url: &str) -> String {
    if url.is_empty() {
        return String::new();
    }
    if url.starts_with("//") {
        format!("https:{url}")
    } else if url.starts_with("http://") {
        format!("https://{}", url.trim_start_matches("http://"))
    } else {
        url.to_string()
    }
}

fn first_nonempty(parts: &[String]) -> String {
    parts
        .iter()
        .find(|s| !s.is_empty())
        .cloned()
        .unwrap_or_default()
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn parse_recommend_card() {
        let v = json!({
            "roomid": 460078,
            "uid": 1,
            "title": "测试直播",
            "uname": "主播",
            "face": "//i0.hdslb.com/bfs/face/a.jpg",
            "cover": "//i0.hdslb.com/bfs/live/a.jpg",
            "online": 1234,
            "area_v2_name": "单机游戏"
        });
        let c = parse_card(v).unwrap();
        assert_eq!(c.room_id, 460078);
        assert!(c.cover.starts_with("https://"));
        assert_eq!(c.area_name, "单机游戏");
    }

    #[test]
    fn parse_play_flv_hls() {
        let data = PlayInfoData {
            room_id: Some(1),
            live_status: Some(1),
            playurl_info: Some(json!({
                "playurl": {
                    "stream": [
                        {
                            "protocol_name": "http_stream",
                            "format": [{
                                "format_name": "flv",
                                "codec": [{
                                    "codec_name": "avc",
                                    "current_qn": 10000,
                                    "base_url": "/live-bvc/1.flv",
                                    "url_info": [
                                        { "host": "https://d1.live-play.acgvideo.com", "extra": "?trid=1" }
                                    ]
                                }]
                            }]
                        },
                        {
                            "protocol_name": "http_hls",
                            "format": [{
                                "format_name": "fmp4",
                                "codec": [{
                                    "codec_name": "avc",
                                    "current_qn": 10000,
                                    "base_url": "/live-bvc/1.m4s",
                                    "url_info": [
                                        { "host": "https://d2.live-play.acgvideo.com", "extra": "?trid=2" }
                                    ]
                                }]
                            }]
                        }
                    ]
                }
            })),
        };
        let src = parse_play_source(data, 1, 10000).unwrap();
        assert_eq!(src.streams.len(), 2);
        assert!(src.default_stream_id.contains("http_hls"));
        assert!(src.streams.iter().any(|s| s.url.contains("d2.live-play")));
    }

    #[test]
    fn offline_room_errors() {
        let data = PlayInfoData {
            room_id: Some(1),
            live_status: Some(0),
            playurl_info: None,
        };
        assert!(parse_play_source(data, 1, 10000).is_err());
    }

    #[test]
    fn parse_dm_history() {
        let data = HistoryData {
            room: Some(vec![json!({
                "uid": 9,
                "nickname": "观众",
                "text": "你好",
                "timeline": "2024-01-01 12:00:00"
            })]),
            admin: None,
        };
        let items = parse_history(data);
        assert_eq!(items.len(), 1);
        assert_eq!(items[0].text, "你好");
        assert_eq!(items[0].uname, "观众");
        assert_eq!(items[0].uid, 9);
    }
}
