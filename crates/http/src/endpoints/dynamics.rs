//! Follow dynamics (polymer feed, read-only).

use crate::client::{BiliClient, RequestOptions};
use crate::error::Result;
use auth::{Account, API_BASE};
use domain::dynamics::{DynamicItem, DynamicPage};
use domain::id::DurationMs;
use serde::Deserialize;
use serde_json::Value;
use std::collections::BTreeMap;

/// Features query used by web polymer dynamic feed.
const DYN_FEATURES: &str =
    "itemOpusStyle,listOnlyfans,opusBigCover,onlyfansVote,decorationCard,onlyfansAssetsV2,forwardListHidden,ugcDelete";

/// Dynamics API surface.
pub struct DynamicsApi;

impl DynamicsApi {
    /// Follow feed: `GET /x/polymer/web-dynamic/v1/feed/all` (Cookie required).
    ///
    /// `offset` empty = first page; then pass previous `next_offset`.
    /// `type_filter`: `all` / `video` / `pgc` / `article` (default `all`).
    pub async fn feed_all(
        client: &BiliClient,
        account: &Account,
        device_buvid3: Option<&str>,
        offset: &str,
        type_filter: &str,
        page: i32,
    ) -> Result<DynamicPage> {
        let page = page.max(1);
        let ty = if type_filter.is_empty() {
            "all"
        } else {
            type_filter
        };

        let mut params = BTreeMap::new();
        params.insert("timezone_offset".into(), "-480".into());
        params.insert("type".into(), ty.into());
        params.insert("page".into(), page.to_string());
        params.insert("features".into(), DYN_FEATURES.into());
        params.insert("platform".into(), "web".into());
        params.insert("web_location".into(), "333.1365".into());
        if !offset.is_empty() {
            params.insert("offset".into(), offset.to_string());
        }

        let url = BiliClient::resolve_url(API_BASE, "/x/polymer/web-dynamic/v1/feed/all");
        let opts = RequestOptions {
            account: Some(account),
            device_buvid3,
            auth: crate::middleware::AuthMode::Cookie,
            ..RequestOptions::default()
        }
        .with_referer("https://t.bilibili.com/");

        let resp = client.get_bili::<FeedAllData>(&url, params, opts).await?;
        let data = resp.into_data()?;
        let items = data
            .items
            .unwrap_or_default()
            .into_iter()
            .filter_map(|v| parse_item(v))
            .collect();

        Ok(DynamicPage {
            items,
            next_offset: data.offset.unwrap_or_default(),
            has_more: data.has_more.unwrap_or(false),
            update_baseline: data.update_baseline.unwrap_or_default(),
            update_num: data.update_num.unwrap_or(0),
        })
    }
}

#[derive(Debug, Deserialize)]
struct FeedAllData {
    #[serde(default)]
    has_more: Option<bool>,
    #[serde(default)]
    items: Option<Vec<Value>>,
    #[serde(default)]
    offset: Option<String>,
    #[serde(default)]
    update_baseline: Option<String>,
    #[serde(default)]
    update_num: Option<i32>,
}

fn parse_item(v: Value) -> Option<DynamicItem> {
    let id = v
        .get("id_str")
        .and_then(|x| x.as_str())
        .unwrap_or("")
        .to_string();
    if id.is_empty() {
        return None;
    }
    let type_tag = v
        .get("type")
        .and_then(|x| x.as_str())
        .unwrap_or("")
        .to_string();
    if type_tag.is_empty() || type_tag == "DYNAMIC_TYPE_NONE" {
        return None;
    }
    // Hidden / folded cards still carry content; keep unless invisible explicitly false.
    if v.get("visible").and_then(|x| x.as_bool()) == Some(false) {
        return None;
    }

    let modules = v.get("modules")?;
    let author = modules.get("module_author");
    let author_mid = author
        .and_then(|a| a.get("mid"))
        .and_then(|x| x.as_i64())
        .unwrap_or(0);
    let author_name = author
        .and_then(|a| a.get("name"))
        .and_then(|x| x.as_str())
        .unwrap_or("")
        .to_string();
    let author_face = normalize_cover(
        author
            .and_then(|a| a.get("face"))
            .and_then(|x| x.as_str())
            .unwrap_or(""),
    );
    let pub_ts = author
        .and_then(|a| a.get("pub_ts"))
        .and_then(|x| x.as_i64())
        .unwrap_or(0);
    let pub_ts_ms = if pub_ts > 1_000_000_000_000 {
        pub_ts
    } else {
        pub_ts.saturating_mul(1000)
    };

    let dyn_mod = modules.get("module_dynamic");
    let text = extract_text(dyn_mod);
    let (title, cover, aid, bvid, duration_ms) = extract_major(dyn_mod);

    // Forward: fall back to original major when local major is empty.
    let (title, cover, aid, bvid, duration_ms, text) =
        if title.is_empty() && cover.is_empty() && aid <= 0 && bvid.is_empty() {
            if let Some(orig) = v.get("orig") {
                let orig_mod = orig.get("modules").and_then(|m| m.get("module_dynamic"));
                let (t, c, a, b, d) = extract_major(orig_mod);
                let orig_text = extract_text(orig_mod);
                let merged = if text.is_empty() {
                    orig_text
                } else if orig_text.is_empty() {
                    text
                } else {
                    format!("{text}\n// {orig_text}")
                };
                (t, c, a, b, d, merged)
            } else {
                (title, cover, aid, bvid, duration_ms, text)
            }
        } else {
            (title, cover, aid, bvid, duration_ms, text)
        };

    let stat = modules.get("module_stat");
    let like_count = stat_count(stat, "like");
    let comment_count = stat_count(stat, "comment");
    let repost_count = stat_count(stat, "forward");

    Some(DynamicItem {
        id,
        type_tag,
        author_mid,
        author_name,
        author_face,
        pub_ts_ms,
        text,
        title,
        cover,
        aid,
        bvid,
        duration_ms,
        like_count,
        comment_count,
        repost_count,
    })
}

fn extract_text(dyn_mod: Option<&Value>) -> String {
    let Some(dyn_mod) = dyn_mod else {
        return String::new();
    };
    if let Some(t) = dyn_mod
        .get("desc")
        .and_then(|d| d.get("text"))
        .and_then(|x| x.as_str())
    {
        return t.to_string();
    }
    // Opus-style draw / word.
    if let Some(t) = dyn_mod
        .get("major")
        .and_then(|m| m.get("opus"))
        .and_then(|o| o.get("summary"))
        .and_then(|s| s.get("text"))
        .and_then(|x| x.as_str())
    {
        return t.to_string();
    }
    String::new()
}

fn extract_major(
    dyn_mod: Option<&Value>,
) -> (String, String, i64, String, DurationMs) {
    let empty = (String::new(), String::new(), 0_i64, String::new(), DurationMs(0));
    let Some(major) = dyn_mod.and_then(|d| d.get("major")) else {
        return empty;
    };
    let major_type = major
        .get("type")
        .and_then(|x| x.as_str())
        .unwrap_or("");

    match major_type {
        "MAJOR_TYPE_ARCHIVE" | "MAJOR_TYPE_UGC_SEASON" => {
            let archive = major
                .get("archive")
                .or_else(|| major.get("ugc_season"))
                .cloned()
                .unwrap_or(Value::Null);
            let aid = json_i64(&archive, "aid");
            let bvid = json_str(&archive, "bvid");
            let title = json_str(&archive, "title");
            let cover = normalize_cover(&json_str(&archive, "cover"));
            let duration_ms = parse_duration_field(&archive);
            (title, cover, aid, bvid, duration_ms)
        }
        "MAJOR_TYPE_PGC" => {
            let pgc = major.get("pgc").cloned().unwrap_or(Value::Null);
            let title = json_str(&pgc, "title");
            let cover = normalize_cover(&json_str(&pgc, "cover"));
            let aid = json_i64(&pgc, "aid");
            let ep_id = json_i64(&pgc, "epid");
            // Prefer bvid when present; else leave empty (no play route for ep yet).
            let bvid = json_str(&pgc, "bvid");
            let _ = ep_id;
            (title, cover, aid, bvid, DurationMs(0))
        }
        "MAJOR_TYPE_ARTICLE" => {
            let art = major.get("article").cloned().unwrap_or(Value::Null);
            let title = json_str(&art, "title");
            let covers = art
                .get("covers")
                .and_then(|c| c.as_array())
                .and_then(|a| a.first())
                .and_then(|x| x.as_str())
                .unwrap_or("");
            let cover = normalize_cover(covers);
            (title, cover, 0, String::new(), DurationMs(0))
        }
        "MAJOR_TYPE_DRAW" => {
            let draw = major.get("draw").cloned().unwrap_or(Value::Null);
            let items = draw.get("items").and_then(|i| i.as_array());
            let cover = items
                .and_then(|a| a.first())
                .and_then(|it| it.get("src").and_then(|x| x.as_str()))
                .map(normalize_cover)
                .unwrap_or_default();
            (String::new(), cover, 0, String::new(), DurationMs(0))
        }
        "MAJOR_TYPE_OPUS" => {
            let opus = major.get("opus").cloned().unwrap_or(Value::Null);
            let title = json_str(&opus, "title");
            let pics = opus.get("pics").and_then(|p| p.as_array());
            let cover = pics
                .and_then(|a| a.first())
                .and_then(|it| it.get("url").and_then(|x| x.as_str()))
                .map(normalize_cover)
                .unwrap_or_default();
            (title, cover, 0, String::new(), DurationMs(0))
        }
        "MAJOR_TYPE_LIVE" | "MAJOR_TYPE_LIVE_RCMD" => {
            if let Some(live) = major.get("live") {
                let title = json_str(live, "title");
                let cover = normalize_cover(&json_str(live, "cover"));
                return (title, cover, 0, String::new(), DurationMs(0));
            }
            if let Some(rcmd) = major.get("live_rcmd") {
                if let Some(content) = rcmd.get("content").and_then(|x| x.as_str()) {
                    if let Ok(inner) = serde_json::from_str::<Value>(content) {
                        let info = inner.get("live_play_info").cloned().unwrap_or(Value::Null);
                        let title = json_str(&info, "title");
                        let cover = normalize_cover(
                            &json_str(&info, "cover")
                                .if_empty(|| json_str(&info, "cover_from_user")),
                        );
                        return (title, cover, 0, String::new(), DurationMs(0));
                    }
                }
            }
            empty
        }
        "MAJOR_TYPE_COMMON" => {
            let common = major.get("common").cloned().unwrap_or(Value::Null);
            let title = json_str(&common, "title");
            let cover = normalize_cover(&json_str(&common, "cover"));
            (title, cover, 0, String::new(), DurationMs(0))
        }
        _ => empty,
    }
}

fn stat_count(stat: Option<&Value>, key: &str) -> i64 {
    stat.and_then(|s| s.get(key))
        .and_then(|k| k.get("count"))
        .and_then(|x| x.as_i64())
        .unwrap_or(0)
}

fn parse_duration_field(archive: &Value) -> DurationMs {
    if let Some(sec) = archive.get("duration").and_then(|x| x.as_i64()) {
        if sec > 0 {
            return DurationMs(sec.saturating_mul(1000));
        }
    }
    if let Some(label) = archive
        .get("duration_text")
        .and_then(|x| x.as_str())
    {
        return DurationMs(parse_duration_text(label).saturating_mul(1000));
    }
    DurationMs(0)
}

/// Parse `3:21` / `1:02:03` into seconds.
fn parse_duration_text(s: &str) -> i64 {
    let parts: Vec<i64> = s
        .split(':')
        .filter_map(|p| p.trim().parse::<i64>().ok())
        .collect();
    match parts.as_slice() {
        [h, m, sec] => h * 3600 + m * 60 + sec,
        [m, sec] => m * 60 + sec,
        [sec] => *sec,
        _ => 0,
    }
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

trait IfEmpty {
    fn if_empty(self, f: impl FnOnce() -> String) -> String;
}

impl IfEmpty for String {
    fn if_empty(self, f: impl FnOnce() -> String) -> String {
        if self.is_empty() {
            f()
        } else {
            self
        }
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

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn parse_av_card() {
        let v = json!({
            "id_str": "1234567890",
            "type": "DYNAMIC_TYPE_AV",
            "visible": true,
            "modules": {
                "module_author": {
                    "mid": 1,
                    "name": "UP",
                    "face": "//i0.hdslb.com/bfs/face/a.jpg",
                    "pub_ts": 1700000000
                },
                "module_dynamic": {
                    "desc": { "text": "今天投稿" },
                    "major": {
                        "type": "MAJOR_TYPE_ARCHIVE",
                        "archive": {
                            "aid": "170001",
                            "bvid": "BV1xx411c7mD",
                            "title": "hello",
                            "cover": "//i0.hdslb.com/bfs/archive/a.jpg",
                            "duration_text": "3:21"
                        }
                    }
                },
                "module_stat": {
                    "like": { "count": 10 },
                    "comment": { "count": 2 },
                    "forward": { "count": 1 }
                }
            }
        });
        let item = parse_item(v).unwrap();
        assert_eq!(item.id, "1234567890");
        assert_eq!(item.aid, 170001);
        assert_eq!(item.bvid, "BV1xx411c7mD");
        assert_eq!(item.duration_ms.get(), 201_000);
        assert!(item.cover.starts_with("https://"));
        assert_eq!(item.like_count, 10);
        assert_eq!(item.pub_ts_ms, 1_700_000_000_000);
    }

    #[test]
    fn parse_word_only() {
        let v = json!({
            "id_str": "9",
            "type": "DYNAMIC_TYPE_WORD",
            "modules": {
                "module_author": { "mid": 2, "name": "A", "face": "", "pub_ts": 1 },
                "module_dynamic": { "desc": { "text": "hi" } },
                "module_stat": {}
            }
        });
        let item = parse_item(v).unwrap();
        assert_eq!(item.text, "hi");
        assert!(item.bvid.is_empty());
    }

    #[test]
    fn drops_none_type() {
        let v = json!({ "id_str": "1", "type": "DYNAMIC_TYPE_NONE" });
        assert!(parse_item(v).is_none());
    }

    #[test]
    fn duration_text_parse() {
        assert_eq!(parse_duration_text("3:21"), 201);
        assert_eq!(parse_duration_text("1:02:03"), 3723);
    }
}
