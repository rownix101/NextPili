//! Member (UP) space endpoints: profile card + App archive cursor.

use crate::client::{BiliClient, RequestOptions};
use crate::error::{Error, Result};
use auth::{API_BASE, APP_BASE, Account, MOBI_APP_ANDROID_HD, PLATFORM_ANDROID};
use domain::id::DurationMs;
use domain::member::{MemberProfile, MemberVideo, MemberVideoPage};
use serde_json::Value;
use std::collections::BTreeMap;

const APP_BUILD: &str = "1460200";
const APP_VERSION: &str = "1.46.2";
const APP_STATISTICS: &str = r#"{"appId":1,"platform":3,"version":"1.46.2","abtest":0}"#;

/// Member-space API surface.
pub struct MemberApi;

impl MemberApi {
    /// `GET /x/web-interface/card?mid=&photo=true`.
    ///
    /// Cookie is optional; include it to receive accurate `following` state.
    pub async fn profile(
        client: &BiliClient,
        account: Option<&Account>,
        device_buvid3: Option<&str>,
        mid: i64,
    ) -> Result<MemberProfile> {
        if mid <= 0 {
            return Err(Error::Domain(domain::Error::InvalidArgument {
                msg: "mid required".into(),
            }));
        }

        let mut params = BTreeMap::new();
        params.insert("mid".into(), mid.to_string());
        params.insert("photo".into(), "true".into());

        let url = BiliClient::resolve_url(API_BASE, "/x/web-interface/card");
        let referer = format!("https://space.bilibili.com/{mid}");
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

        let resp = client.get_bili::<Value>(&url, params, opts).await?;
        let data = resp.into_data()?;
        parse_profile(mid, &data)
    }

    /// App space archive cursor: `GET https://app.bilibili.com/x/v2/space/archive/cursor`.
    ///
    /// First page passes `aid_cursor = 0`; subsequent pages pass the last
    /// returned item's aid. `order` is `pubdate` or `click`.
    pub async fn archive_cursor(
        client: &BiliClient,
        account: Option<&Account>,
        mid: i64,
        aid_cursor: i64,
        order: &str,
        ps: u32,
    ) -> Result<MemberVideoPage> {
        if mid <= 0 {
            return Err(Error::Domain(domain::Error::InvalidArgument {
                msg: "mid required".into(),
            }));
        }
        let ps = ps.clamp(1, 50);
        let order = match order.trim() {
            "click" => "click",
            _ => "pubdate",
        };

        let mut params = BTreeMap::new();
        params.insert("build".into(), APP_BUILD.into());
        params.insert("version".into(), APP_VERSION.into());
        params.insert("c_locale".into(), "zh_CN".into());
        params.insert("channel".into(), "master".into());
        params.insert("mobi_app".into(), MOBI_APP_ANDROID_HD.into());
        params.insert("platform".into(), PLATFORM_ANDROID.into());
        params.insert("s_locale".into(), "zh_CN".into());
        params.insert("statistics".into(), APP_STATISTICS.into());
        params.insert("vmid".into(), mid.to_string());
        params.insert("ps".into(), ps.to_string());
        params.insert("order".into(), order.into());
        params.insert("sort".into(), "desc".into());
        params.insert("qn".into(), "80".into());
        if aid_cursor > 0 {
            params.insert("aid".into(), aid_cursor.to_string());
        }

        let url = BiliClient::resolve_url(APP_BASE, "/x/v2/space/archive/cursor");
        let mut opts = RequestOptions::app_sign();
        if let Some(account) = account {
            opts = opts.with_account(Some(account));
        }

        let resp = client.get_bili::<Value>(&url, params, opts).await?;
        let data = resp.into_data()?;
        parse_archive_page(&data)
    }
}

fn parse_profile(mid: i64, data: &Value) -> Result<MemberProfile> {
    let card = data
        .get("card")
        .filter(|c| c.is_object())
        .ok_or_else(|| Error::Parse("member card missing".into()))?;

    let name = string_at(card, &["name"]);
    if name.is_empty() {
        return Err(Error::Parse("member card name missing".into()));
    }

    let official_verify = card.get("official_verify");
    let official = card.get("Official");
    let official_desc = official_verify
        .map(|v| string_at(v, &["desc"]))
        .filter(|s| !s.is_empty());
    let official_title = official_desc.unwrap_or_else(|| {
        official
            .map(|v| string_at(v, &["title"]))
            .unwrap_or_default()
    });
    let official_type = official_verify
        .and_then(|v| value_i64_at(v, &["type"]))
        .or_else(|| official.and_then(|v| value_i64_at(v, &["type"])))
        .unwrap_or(-1) as i32;

    let vip = card.get("vip");
    let vip_status = vip
        .and_then(|v| v.get("status"))
        .and_then(value_i64)
        .map(|v| v > 0)
        .unwrap_or(false);
    let vip_label = vip
        .and_then(|v| v.get("label"))
        .map(|v| string_at(v, &["text"]))
        .unwrap_or_default();

    let fans = value_i64_at(card, &["fans"]).unwrap_or(0);
    let following = value_i64_at(card, &["attention"]).unwrap_or(0);
    let likes = value_i64_at(data, &["like_num"]).unwrap_or(0);
    let follower = value_i64_at(data, &["follower"]).unwrap_or(fans);
    let archive_count = value_i64_at(data, &["archive_count"]).unwrap_or(0);
    let following_state = data
        .get("following")
        .and_then(Value::as_bool)
        .unwrap_or(false);
    let level = card
        .get("level_info")
        .and_then(|v| value_i64_at(v, &["current_level"]))
        .unwrap_or(0) as i32;

    Ok(MemberProfile {
        mid: value_i64_at(card, &["mid"]).unwrap_or(mid),
        name,
        face: normalize_cover(&string_at(card, &["face"])),
        sign: string_at(card, &["sign"]),
        level,
        fans: follower.max(fans),
        following,
        likes,
        archive_count,
        following_state,
        official_title,
        official_type,
        vip_status,
        vip_label,
    })
}

fn parse_archive_page(data: &Value) -> Result<MemberVideoPage> {
    let raw_items = data
        .get("item")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    let items: Vec<MemberVideo> = raw_items.into_iter().filter_map(parse_video).collect();
    let has_more = data
        .get("has_next")
        .and_then(Value::as_bool)
        .unwrap_or(!items.is_empty());
    let next_aid = if has_more {
        items.last().map(|v| v.aid).unwrap_or(0)
    } else {
        0
    };
    let total = value_i64_at(data, &["count"]).unwrap_or(items.len() as i64);

    Ok(MemberVideoPage {
        items,
        next_aid,
        has_more: has_more && next_aid > 0,
        total,
    })
}

fn parse_video(v: Value) -> Option<MemberVideo> {
    let bvid = string_at(&v, &["bvid"]);
    let aid = value_i64_at(&v, &["param"])
        .or_else(|| value_i64_at(&v, &["aid"]))
        .unwrap_or(0);
    if aid <= 0 && bvid.is_empty() {
        return None;
    }

    let title = string_at(&v, &["title"]);
    if title.is_empty() {
        return None;
    }

    let duration_sec = value_i64_at(&v, &["duration"]).unwrap_or(0);
    let duration_ms = if duration_sec > 0 {
        DurationMs(duration_sec.saturating_mul(1000))
    } else {
        parse_duration_label(&string_at(&v, &["length"]))
    };

    Some(MemberVideo {
        aid,
        bvid,
        cid: value_i64_at(&v, &["first_cid"]).unwrap_or(0),
        title,
        cover: normalize_cover(&string_at(&v, &["cover"])),
        duration_ms: duration_ms.get(),
        play: value_i64_at(&v, &["play"]).unwrap_or(0),
        danmaku: value_i64_at(&v, &["danmaku"]).unwrap_or(0),
        ctime_ms: value_i64_at(&v, &["ctime"])
            .unwrap_or(0)
            .saturating_mul(1000),
        author: string_at(&v, &["author"]),
    })
}

fn parse_duration_label(label: &str) -> DurationMs {
    let parts: Vec<&str> = label.trim().split(':').collect();
    if parts.is_empty() {
        return DurationMs(0);
    }
    let mut seconds = 0_i64;
    for part in parts {
        let n = part.parse::<i64>().unwrap_or(0);
        seconds = seconds.saturating_mul(60).saturating_add(n);
    }
    DurationMs(seconds.saturating_mul(1000))
}

fn string_at(value: &Value, path: &[&str]) -> String {
    let mut current = value;
    for key in path {
        let Some(next) = current.get(*key) else {
            return String::new();
        };
        current = next;
    }
    current.as_str().map(str::to_string).unwrap_or_default()
}

fn value_i64_at(value: &Value, path: &[&str]) -> Option<i64> {
    let mut current = value;
    for key in path {
        current = current.get(*key)?;
    }
    value_i64(current)
}

fn value_i64(value: &Value) -> Option<i64> {
    if let Some(n) = value.as_i64() {
        return Some(n);
    }
    if let Some(n) = value.as_u64() {
        return i64::try_from(n).ok();
    }
    value.as_str().and_then(|s| s.parse::<i64>().ok())
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

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn parses_profile_card() {
        let data = json!({
            "card": {
                "mid": "2",
                "name": "碧诗",
                "face": "//i0.hdslb.com/bfs/face/x.jpg",
                "sign": "hello",
                "fans": 10,
                "attention": 20,
                "level_info": {"current_level": 6},
                "official_verify": {"type": 0, "desc": "bilibili"},
                "vip": {"status": 1, "label": {"text": "年度大会员"}}
            },
            "follower": 11,
            "like_num": 12,
            "archive_count": 13,
            "following": true
        });
        let p = parse_profile(2, &data).unwrap();
        assert_eq!(p.name, "碧诗");
        assert_eq!(p.level, 6);
        assert_eq!(p.fans, 11);
        assert_eq!(p.following, 20);
        assert_eq!(p.likes, 12);
        assert_eq!(p.archive_count, 13);
        assert!(p.following_state);
        assert_eq!(p.official_type, 0);
        assert_eq!(p.official_title, "bilibili");
        assert_eq!(p.vip_label, "年度大会员");
        assert!(p.face.starts_with("https://"));
    }

    #[test]
    fn parses_archive_cursor() {
        let data = json!({
            "count": 2,
            "has_next": true,
            "item": [
                {"param": "101", "bvid": "BV1", "title": "A", "cover": "http://x/a.jpg", "duration": 61, "play": 7, "danmaku": 8, "ctime": 9, "author": "UP", "first_cid": 55},
                {"param": "102", "bvid": "BV2", "title": "B", "cover": "//x/b.jpg", "length": "1:02", "play": 10, "danmaku": 11, "ctime": 12, "author": "UP", "first_cid": 56}
            ]
        });
        let page = parse_archive_page(&data).unwrap();
        assert_eq!(page.items.len(), 2);
        assert_eq!(page.items[0].duration_ms, 61_000);
        assert_eq!(page.items[1].duration_ms, 62_000);
        assert_eq!(page.next_aid, 102);
        assert!(page.has_more);
        assert!(page.items[1].cover.starts_with("https://"));
    }
}
