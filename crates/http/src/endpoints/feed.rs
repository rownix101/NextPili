//! Recommend + popular feed endpoints.

use crate::client::{BiliClient, RequestOptions};
use crate::error::Result;
use auth::{Account, API_BASE, WbiSigner};
use domain::feed::{filter_feed_item, FeedItem};
use domain::id::DurationMs;
use serde::Deserialize;
use serde_json::Value;
use std::collections::BTreeMap;

const GOTO_BLACKLIST: &[&str] = &["ad", "banner", "bangumi", "live", "game", "special_s"];

/// Paginated recommend feed result.
#[derive(Debug, Clone)]
pub struct RecommendFeed {
    pub items: Vec<FeedItem>,
    pub next_fresh_idx: i32,
}

/// Paginated popular feed result.
#[derive(Debug, Clone)]
pub struct PopularFeed {
    pub items: Vec<FeedItem>,
    pub next_pn: i32,
    pub no_more: bool,
}

/// Partition ranking result (`ranking/v2`; typically top 100, no paging).
#[derive(Debug, Clone)]
pub struct RankingFeed {
    pub items: Vec<FeedItem>,
    pub note: String,
}

#[derive(Debug, Deserialize)]
struct RecommendData {
    #[serde(default)]
    item: Option<Vec<Value>>,
    #[serde(default)]
    items: Option<Vec<Value>>,
}

#[derive(Debug, Deserialize)]
struct PopularData {
    #[serde(default, deserialize_with = "crate::serde_util::null_as_default")]
    list: Vec<Value>,
    #[serde(default)]
    no_more: bool,
}

#[derive(Debug, Deserialize)]
struct RankingData {
    #[serde(default, deserialize_with = "crate::serde_util::null_as_default")]
    list: Vec<Value>,
    #[serde(default)]
    note: String,
}

#[derive(Debug, Deserialize, Default)]
struct OwnerRaw {
    #[serde(default)]
    name: String,
}

/// Feed API surface.
pub struct FeedApi;

impl FeedApi {
    /// Web recommend: `GET /x/web-interface/wbi/index/top/feed/rcmd` (WBI).
    pub async fn recommend(
        client: &BiliClient,
        account: Option<&Account>,
        device_buvid3: Option<&str>,
        wbi: &WbiSigner,
        fresh_idx: i32,
        ps: u32,
    ) -> Result<RecommendFeed> {
        let ps = ps.clamp(1, 30);
        let fresh_idx = fresh_idx.max(0);

        let mut params = BTreeMap::new();
        params.insert("web_location".into(), "1430650".into());
        params.insert("y_num".into(), "4".into());
        params.insert("fresh_type".into(), "4".into());
        params.insert("feed_version".into(), "V8".into());
        params.insert("fresh_idx_1h".into(), fresh_idx.to_string());
        params.insert("fetch_row".into(), "4".into());
        params.insert("fresh_idx".into(), fresh_idx.to_string());
        params.insert("brush".into(), fresh_idx.to_string());
        params.insert("homepage_ver".into(), "1".into());
        params.insert("ps".into(), ps.to_string());
        params.insert("last_y_num".into(), "5".into());
        params.insert("screen".into(), "2560-1440".into());
        params.insert("seo_info".into(), String::new());
        params.insert("last_showlist".into(), String::new());
        params.insert("uniq_id".into(), String::new());
        params.insert("version".into(), "1".into());

        let url = BiliClient::resolve_url(API_BASE, "/x/web-interface/wbi/index/top/feed/rcmd");
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
        opts = opts.with_wbi(wbi);

        let resp = client.get_bili::<RecommendData>(&url, params, opts).await?;
        let data = resp.into_data()?;
        let raw_items = data.item.or(data.items).unwrap_or_default();
        let items = raw_items
            .into_iter()
            .filter_map(|v| parse_recommend_item(v).ok().flatten())
            .collect();

        Ok(RecommendFeed {
            items,
            next_fresh_idx: fresh_idx.saturating_add(1),
        })
    }

    /// Popular: `GET /x/web-interface/popular`.
    pub async fn popular(
        client: &BiliClient,
        account: Option<&Account>,
        device_buvid3: Option<&str>,
        pn: i32,
        ps: u32,
    ) -> Result<PopularFeed> {
        let pn = pn.max(1);
        let ps = ps.clamp(1, 50);

        let mut params = BTreeMap::new();
        params.insert("pn".into(), pn.to_string());
        params.insert("ps".into(), ps.to_string());

        let url = BiliClient::resolve_url(API_BASE, "/x/web-interface/popular");
        let opts = RequestOptions {
            account,
            device_buvid3,
            auth: if account.is_some() {
                crate::middleware::AuthMode::Cookie
            } else {
                crate::middleware::AuthMode::OptionalLogin
            },
            ..RequestOptions::default()
        };

        let resp = client.get_bili::<PopularData>(&url, params, opts).await?;
        let data = resp.into_data()?;
        let items = data
            .list
            .into_iter()
            .filter_map(|v| parse_archive_item(v).ok().flatten())
            .collect();

        Ok(PopularFeed {
            items,
            next_pn: pn.saturating_add(1),
            no_more: data.no_more,
        })
    }

    /// Partition ranking: `GET /x/web-interface/ranking/v2` (WBI).
    ///
    /// `rid`: primary partition tid; `0` = site-wide. Only main partitions are supported.
    /// `rank_type`: `all` | `rookie` | `origin` (default `all`).
    pub async fn ranking(
        client: &BiliClient,
        account: Option<&Account>,
        device_buvid3: Option<&str>,
        wbi: &WbiSigner,
        rid: i32,
        rank_type: &str,
    ) -> Result<RankingFeed> {
        let rid = rid.max(0);
        let rank_type = match rank_type {
            "rookie" | "origin" => rank_type,
            _ => "all",
        };

        let mut params = BTreeMap::new();
        params.insert("rid".into(), rid.to_string());
        params.insert("type".into(), rank_type.to_string());
        params.insert("web_location".into(), "333.934".into());

        let url = BiliClient::resolve_url(API_BASE, "/x/web-interface/ranking/v2");
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
        opts = opts.with_wbi(wbi);

        let resp = client.get_bili::<RankingData>(&url, params, opts).await?;
        let data = resp.into_data()?;
        let items = data
            .list
            .into_iter()
            .filter_map(|v| parse_archive_item(v).ok().flatten())
            .collect();

        Ok(RankingFeed {
            items,
            note: data.note,
        })
    }
}

fn parse_recommend_item(v: Value) -> Result<Option<FeedItem>> {
    let goto = v
        .get("goto")
        .and_then(|x| x.as_str())
        .unwrap_or("")
        .to_string();
    if goto != "av" || !filter_feed_item(&goto, GOTO_BLACKLIST) {
        return Ok(None);
    }

    let aid = v
        .get("id")
        .or_else(|| v.get("aid"))
        .and_then(|x| x.as_i64())
        .unwrap_or(0);
    let bvid = v
        .get("bvid")
        .and_then(|x| x.as_str())
        .unwrap_or("")
        .to_string();
    if aid <= 0 && bvid.is_empty() {
        return Ok(None);
    }

    let title = v
        .get("title")
        .and_then(|x| x.as_str())
        .unwrap_or("")
        .to_string();
    if title.is_empty() {
        return Ok(None);
    }

    let cover = normalize_cover(
        v.get("pic")
            .or_else(|| v.get("cover"))
            .and_then(|x| x.as_str())
            .unwrap_or(""),
    );
    let owner_name = v
        .get("owner")
        .and_then(|o| serde_json::from_value::<OwnerRaw>(o.clone()).ok())
        .map(|o| o.name)
        .unwrap_or_default();
    let duration_sec = v.get("duration").and_then(|x| x.as_i64()).unwrap_or(0);

    Ok(Some(FeedItem {
        aid,
        bvid,
        title,
        cover,
        owner_name,
        duration_ms: DurationMs(duration_sec.saturating_mul(1000)),
        goto,
    }))
}

fn parse_archive_item(v: Value) -> Result<Option<FeedItem>> {
    let aid = v.get("aid").and_then(|x| x.as_i64()).unwrap_or(0);
    let bvid = v
        .get("bvid")
        .and_then(|x| x.as_str())
        .unwrap_or("")
        .to_string();
    if aid <= 0 && bvid.is_empty() {
        return Ok(None);
    }
    let title = v
        .get("title")
        .and_then(|x| x.as_str())
        .unwrap_or("")
        .to_string();
    if title.is_empty() {
        return Ok(None);
    }
    let cover = normalize_cover(v.get("pic").and_then(|x| x.as_str()).unwrap_or(""));
    let owner_name = v
        .get("owner")
        .and_then(|o| serde_json::from_value::<OwnerRaw>(o.clone()).ok())
        .map(|o| o.name)
        .unwrap_or_default();
    let duration_sec = v.get("duration").and_then(|x| x.as_i64()).unwrap_or(0);

    Ok(Some(FeedItem {
        aid,
        bvid,
        title,
        cover,
        owner_name,
        duration_ms: DurationMs(duration_sec.saturating_mul(1000)),
        goto: "av".into(),
    }))
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
    fn parse_recommend_av() {
        let v = json!({
            "id": 170001,
            "bvid": "BV1xx411c7mD",
            "goto": "av",
            "title": "hello",
            "pic": "//i0.hdslb.com/bfs/archive/a.jpg",
            "duration": 90,
            "owner": { "name": "UP" }
        });
        let item = parse_recommend_item(v).unwrap().unwrap();
        assert_eq!(item.aid, 170001);
        assert_eq!(item.bvid, "BV1xx411c7mD");
        assert_eq!(item.duration_ms.get(), 90_000);
        assert!(item.cover.starts_with("https://"));
    }

    #[test]
    fn drops_ads() {
        let v = json!({
            "id": 1,
            "bvid": "BV1",
            "goto": "ad",
            "title": "ad"
        });
        assert!(parse_recommend_item(v).unwrap().is_none());
    }

    #[test]
    fn parse_popular() {
        let v = json!({
            "aid": 2,
            "bvid": "BV2",
            "title": "hot",
            "pic": "https://i0.hdslb.com/x.jpg",
            "duration": 10,
            "owner": { "name": "A" }
        });
        let item = parse_archive_item(v).unwrap().unwrap();
        assert_eq!(item.goto, "av");
        assert_eq!(item.duration_ms.get(), 10_000);
    }

    #[test]
    fn normalize_cover_scheme() {
        assert_eq!(
            normalize_cover("//cdn.example/a.jpg"),
            "https://cdn.example/a.jpg"
        );
        assert_eq!(
            normalize_cover("http://cdn.example/a.jpg"),
            "https://cdn.example/a.jpg"
        );
    }

    #[test]
    fn parse_ranking_archive() {
        let v = json!({
            "aid": 3,
            "bvid": "BV3",
            "title": "rank",
            "pic": "//i0.hdslb.com/x.jpg",
            "duration": 42,
            "owner": { "name": "UP" }
        });
        let item = parse_archive_item(v).unwrap().unwrap();
        assert_eq!(item.aid, 3);
        assert_eq!(item.duration_ms.get(), 42_000);
        assert!(item.cover.starts_with("https://"));
    }
}
