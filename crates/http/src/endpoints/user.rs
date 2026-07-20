//! History · watch-later · favorites (read paths).

use crate::client::{BiliClient, RequestOptions};
use crate::error::{Error, Result};
use auth::{Account, API_BASE};
use domain::id::DurationMs;
use domain::library::{
    history_is_playable, FavFolder, FavFolderList, FavResourceItem, FavResourcePage, HistoryItem,
    HistoryPage, ToViewItem, ToViewPage,
};
use serde::Deserialize;
use serde_json::Value;
use std::collections::BTreeMap;

/// User library API surface (history / toview / fav).
pub struct UserApi;

impl UserApi {
    /// `GET /x/web-interface/history/cursor` (Cookie required).
    ///
    /// Cursor IFS: pass previous page's `next_*` as `max` / `view_at` / `business`.
    /// First page: all zeros / empty business.
    pub async fn history_cursor(
        client: &BiliClient,
        account: &Account,
        device_buvid3: Option<&str>,
        max: i64,
        view_at: i64,
        business: &str,
        ps: u32,
    ) -> Result<HistoryPage> {
        let ps = ps.clamp(1, 30);
        let mut params = BTreeMap::new();
        params.insert("max".into(), max.max(0).to_string());
        params.insert("view_at".into(), view_at.max(0).to_string());
        params.insert("business".into(), business.to_string());
        params.insert("ps".into(), ps.to_string());
        // Prefer archive-capable rows; server still returns mixed when type=all.
        params.insert("type".into(), "all".into());

        let url = BiliClient::resolve_url(API_BASE, "/x/web-interface/history/cursor");
        let opts = RequestOptions {
            account: Some(account),
            device_buvid3,
            auth: crate::middleware::AuthMode::Cookie,
            ..RequestOptions::default()
        }
        .with_referer("https://www.bilibili.com/account/history");

        let resp = client.get_bili::<HistoryData>(&url, params, opts).await?;
        let data = resp.into_data()?;
        let cursor = data.cursor.unwrap_or_default();
        let raw_list = data.list.unwrap_or_default();
        let items: Vec<HistoryItem> = raw_list
            .into_iter()
            .filter_map(parse_history_item)
            .collect();
        let has_more = !items.is_empty() && cursor.max > 0;

        Ok(HistoryPage {
            items,
            next_max: cursor.max,
            next_view_at: cursor.view_at,
            next_business: cursor.business,
            has_more,
        })
    }

    /// `GET /x/v2/history/toview/web` (Cookie required).
    pub async fn toview_web(
        client: &BiliClient,
        account: &Account,
        device_buvid3: Option<&str>,
        pn: i32,
        ps: u32,
    ) -> Result<ToViewPage> {
        let pn = pn.max(1);
        let ps = ps.clamp(1, 50);
        let mut params = BTreeMap::new();
        params.insert("pn".into(), pn.to_string());
        params.insert("ps".into(), ps.to_string());

        let url = BiliClient::resolve_url(API_BASE, "/x/v2/history/toview/web");
        let opts = RequestOptions {
            account: Some(account),
            device_buvid3,
            auth: crate::middleware::AuthMode::Cookie,
            ..RequestOptions::default()
        }
        .with_referer("https://www.bilibili.com/watchlater/");

        let resp = client.get_bili::<ToViewData>(&url, params, opts).await?;
        let data = resp.into_data()?;
        let count = data.count;
        let items: Vec<ToViewItem> = data
            .list
            .unwrap_or_default()
            .into_iter()
            .filter_map(parse_toview_item)
            .collect();
        let loaded = (pn as i64 - 1) * ps as i64 + items.len() as i64;
        let has_more = if count > 0 {
            loaded < count as i64 && !items.is_empty()
        } else {
            items.len() as u32 >= ps
        };

        Ok(ToViewPage {
            items,
            count,
            pn,
            has_more,
        })
    }

    /// `GET /x/v3/fav/folder/created/list-all` (Cookie required).
    pub async fn fav_folders(
        client: &BiliClient,
        account: &Account,
        device_buvid3: Option<&str>,
        up_mid: i64,
    ) -> Result<FavFolderList> {
        if up_mid <= 0 {
            return Err(Error::Domain(domain::Error::Unauthenticated));
        }
        let mut params = BTreeMap::new();
        params.insert("up_mid".into(), up_mid.to_string());
        params.insert("type".into(), "2".into());

        let url = BiliClient::resolve_url(API_BASE, "/x/v3/fav/folder/created/list-all");
        let opts = RequestOptions {
            account: Some(account),
            device_buvid3,
            auth: crate::middleware::AuthMode::Cookie,
            ..RequestOptions::default()
        }
        .with_referer("https://www.bilibili.com/");

        let resp = client.get_bili::<FavFoldersData>(&url, params, opts).await?;
        // Hidden/empty space may return `data: null` with code 0.
        let data = resp.into_data_opt()?.unwrap_or_default();
        let folders = data
            .list
            .unwrap_or_default()
            .into_iter()
            .filter_map(parse_fav_folder)
            .collect::<Vec<_>>();
        let count = if data.count > 0 {
            data.count
        } else {
            folders.len() as i32
        };

        Ok(FavFolderList { folders, count })
    }

    /// `GET /x/v3/fav/resource/list` (Cookie required).
    pub async fn fav_resources(
        client: &BiliClient,
        account: &Account,
        device_buvid3: Option<&str>,
        media_id: i64,
        pn: i32,
        ps: u32,
    ) -> Result<FavResourcePage> {
        if media_id <= 0 {
            return Err(Error::Domain(domain::Error::InvalidArgument {
                msg: "media_id required".into(),
            }));
        }
        let pn = pn.max(1);
        let ps = ps.clamp(1, 40);
        let mut params = BTreeMap::new();
        params.insert("media_id".into(), media_id.to_string());
        params.insert("pn".into(), pn.to_string());
        params.insert("ps".into(), ps.to_string());
        params.insert("order".into(), "mtime".into());
        params.insert("type".into(), "0".into());
        params.insert("platform".into(), "web".into());

        let url = BiliClient::resolve_url(API_BASE, "/x/v3/fav/resource/list");
        let opts = RequestOptions {
            account: Some(account),
            device_buvid3,
            auth: crate::middleware::AuthMode::Cookie,
            ..RequestOptions::default()
        }
        .with_referer("https://www.bilibili.com/");

        let resp = client
            .get_bili::<FavResourceData>(&url, params, opts)
            .await?;
        let data = resp.into_data()?;
        let has_more = data.has_more;
        let items = data
            .medias
            .unwrap_or_default()
            .into_iter()
            .filter_map(parse_fav_resource)
            .collect();

        Ok(FavResourcePage {
            items,
            media_id,
            pn,
            has_more,
        })
    }
}

// ─── raw payloads ───────────────────────────────────────────────────────────

#[derive(Debug, Deserialize, Default)]
struct HistoryData {
    #[serde(default)]
    cursor: Option<HistoryCursorRaw>,
    #[serde(default)]
    list: Option<Vec<Value>>,
}

#[derive(Debug, Deserialize, Default)]
struct HistoryCursorRaw {
    #[serde(default)]
    max: i64,
    #[serde(default)]
    view_at: i64,
    #[serde(default)]
    business: String,
}

#[derive(Debug, Deserialize, Default)]
struct ToViewData {
    #[serde(default)]
    count: i32,
    #[serde(default)]
    list: Option<Vec<Value>>,
}

#[derive(Debug, Deserialize, Default)]
struct FavFoldersData {
    #[serde(default)]
    count: i32,
    #[serde(default)]
    list: Option<Vec<Value>>,
}

#[derive(Debug, Deserialize, Default)]
struct FavResourceData {
    #[serde(default)]
    medias: Option<Vec<Value>>,
    #[serde(default)]
    has_more: bool,
}

// ─── parsers ────────────────────────────────────────────────────────────────

fn parse_history_item(v: Value) -> Option<HistoryItem> {
    let hist = v.get("history")?;
    let business = hist
        .get("business")
        .and_then(|x| x.as_str())
        .or_else(|| v.get("business").and_then(|x| x.as_str()))
        .unwrap_or("")
        .to_string();
    if !history_is_playable(&business) {
        return None;
    }

    let aid = hist
        .get("oid")
        .and_then(|x| x.as_i64())
        .or_else(|| v.get("kid").and_then(|x| x.as_i64()))
        .unwrap_or(0);
    let bvid = hist
        .get("bvid")
        .and_then(|x| x.as_str())
        .unwrap_or("")
        .to_string();
    if aid <= 0 && bvid.is_empty() {
        return None;
    }

    let cid = hist.get("cid").and_then(|x| x.as_i64()).unwrap_or(0);
    let title = v
        .get("title")
        .and_then(|x| x.as_str())
        .unwrap_or("")
        .to_string();
    if title.is_empty() {
        return None;
    }
    let cover = normalize_cover(v.get("cover").and_then(|x| x.as_str()).unwrap_or(""));
    let owner_name = v
        .get("author_name")
        .and_then(|x| x.as_str())
        .unwrap_or("")
        .to_string();
    let duration_sec = v.get("duration").and_then(|x| x.as_i64()).unwrap_or(0);
    let progress_sec = v.get("progress").and_then(|x| x.as_i64()).unwrap_or(0);
    let view_at = v.get("view_at").and_then(|x| x.as_i64()).unwrap_or(0);
    let kid = v.get("kid").and_then(|x| x.as_i64()).unwrap_or(aid);
    let show_title = v
        .get("show_title")
        .and_then(|x| x.as_str())
        .unwrap_or("")
        .to_string();

    Some(HistoryItem {
        aid,
        bvid,
        cid,
        title,
        cover,
        owner_name,
        duration_ms: DurationMs(duration_sec.saturating_mul(1000).max(0)),
        progress_ms: progress_sec.saturating_mul(1000).max(0),
        view_at_ms: view_at.saturating_mul(1000).max(0),
        business,
        kid,
        show_title,
    })
}

fn parse_toview_item(v: Value) -> Option<ToViewItem> {
    let aid = v.get("aid").and_then(|x| x.as_i64()).unwrap_or(0);
    let bvid = v
        .get("bvid")
        .and_then(|x| x.as_str())
        .unwrap_or("")
        .to_string();
    if aid <= 0 && bvid.is_empty() {
        return None;
    }
    let title = v
        .get("title")
        .and_then(|x| x.as_str())
        .unwrap_or("")
        .to_string();
    if title.is_empty() {
        return None;
    }
    let cover = normalize_cover(
        v.get("pic")
            .or_else(|| v.get("cover"))
            .and_then(|x| x.as_str())
            .unwrap_or(""),
    );
    let owner_name = v
        .get("owner")
        .and_then(|o| o.get("name"))
        .and_then(|x| x.as_str())
        .unwrap_or("")
        .to_string();
    let cid = v.get("cid").and_then(|x| x.as_i64()).unwrap_or(0);
    let duration_sec = v.get("duration").and_then(|x| x.as_i64()).unwrap_or(0);
    let progress_sec = v.get("progress").and_then(|x| x.as_i64()).unwrap_or(0);
    let add_at = v.get("add_at").and_then(|x| x.as_i64()).unwrap_or(0);

    Some(ToViewItem {
        aid,
        bvid,
        cid,
        title,
        cover,
        owner_name,
        duration_ms: DurationMs(duration_sec.saturating_mul(1000).max(0)),
        progress_ms: progress_sec.saturating_mul(1000).max(0),
        add_at_ms: add_at.saturating_mul(1000).max(0),
    })
}

fn parse_fav_folder(v: Value) -> Option<FavFolder> {
    let id = v.get("id").and_then(|x| x.as_i64()).unwrap_or(0);
    if id <= 0 {
        return None;
    }
    let title = v
        .get("title")
        .and_then(|x| x.as_str())
        .unwrap_or("")
        .to_string();
    if title.is_empty() {
        return None;
    }
    let media_count = v
        .get("media_count")
        .and_then(|x| x.as_i64())
        .unwrap_or(0) as i32;
    let cover = normalize_cover(v.get("cover").and_then(|x| x.as_str()).unwrap_or(""));
    let attr = v.get("attr").and_then(|x| x.as_i64()).unwrap_or(0) as i32;

    Some(FavFolder {
        id,
        title,
        media_count,
        cover,
        attr,
    })
}

fn parse_fav_resource(v: Value) -> Option<FavResourceItem> {
    // type 2 = video; skip invalid / other
    let ty = v.get("type").and_then(|x| x.as_i64()).unwrap_or(2);
    if ty != 2 && ty != 0 {
        // still accept if bvid/aid present
    }
    let id = v.get("id").and_then(|x| x.as_i64()).unwrap_or(0);
    let bvid = v
        .get("bvid")
        .and_then(|x| x.as_str())
        .unwrap_or("")
        .to_string();
    let aid = if id > 0 {
        id
    } else {
        v.get("aid").and_then(|x| x.as_i64()).unwrap_or(0)
    };
    if aid <= 0 && bvid.is_empty() {
        return None;
    }
    let title = v
        .get("title")
        .and_then(|x| x.as_str())
        .unwrap_or("")
        .to_string();
    if title.is_empty() {
        return None;
    }
    let cover = normalize_cover(v.get("cover").and_then(|x| x.as_str()).unwrap_or(""));
    let owner_name = v
        .get("upper")
        .and_then(|o| o.get("name"))
        .and_then(|x| x.as_str())
        .or_else(|| {
            v.get("owner")
                .and_then(|o| o.get("name"))
                .and_then(|x| x.as_str())
        })
        .unwrap_or("")
        .to_string();
    let duration_sec = v.get("duration").and_then(|x| x.as_i64()).unwrap_or(0);
    let fav_time = v.get("fav_time").and_then(|x| x.as_i64()).unwrap_or(0);

    Some(FavResourceItem {
        aid,
        bvid,
        title,
        cover,
        owner_name,
        duration_ms: DurationMs(duration_sec.saturating_mul(1000).max(0)),
        fav_time_ms: fav_time.saturating_mul(1000).max(0),
    })
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
    fn parses_archive_history() {
        let v = json!({
            "title": "hello",
            "cover": "//i0.hdslb.com/a.jpg",
            "author_name": "UP",
            "view_at": 1700000000,
            "progress": 30,
            "duration": 120,
            "kid": 42,
            "show_title": "P1",
            "history": {
                "oid": 42,
                "bvid": "BV1xx",
                "cid": 99,
                "business": "archive"
            }
        });
        let item = parse_history_item(v).unwrap();
        assert_eq!(item.bvid, "BV1xx");
        assert_eq!(item.progress_ms, 30_000);
        assert_eq!(item.view_at_ms, 1_700_000_000_000);
        assert!(item.cover.starts_with("https://"));
    }

    #[test]
    fn drops_live_history() {
        let v = json!({
            "title": "live",
            "history": { "oid": 1, "business": "live" }
        });
        assert!(parse_history_item(v).is_none());
    }

    #[test]
    fn parses_toview() {
        let v = json!({
            "aid": 1,
            "bvid": "BV1",
            "cid": 2,
            "title": "t",
            "pic": "http://i0.hdslb.com/x.jpg",
            "duration": 10,
            "progress": 3,
            "add_at": 100,
            "owner": { "name": "up" }
        });
        let item = parse_toview_item(v).unwrap();
        assert_eq!(item.owner_name, "up");
        assert_eq!(item.progress_ms, 3_000);
        assert!(item.cover.starts_with("https://"));
    }

    #[test]
    fn parses_fav_folder_and_resource() {
        let f = parse_fav_folder(json!({
            "id": 123,
            "title": "默认收藏夹",
            "media_count": 5,
            "cover": "",
            "attr": 1
        }))
        .unwrap();
        assert_eq!(f.id, 123);
        assert_eq!(f.media_count, 5);

        let r = parse_fav_resource(json!({
            "id": 9,
            "bvid": "BV9",
            "type": 2,
            "title": "clip",
            "cover": "//i0.hdslb.com/c.jpg",
            "duration": 60,
            "fav_time": 50,
            "upper": { "name": "u" }
        }))
        .unwrap();
        assert_eq!(r.aid, 9);
        assert_eq!(r.fav_time_ms, 50_000);
    }
}
