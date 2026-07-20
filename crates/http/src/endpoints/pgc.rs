//! PGC (bangumi / movie) season detail, rank, and playurl.

use crate::client::{BiliClient, RequestOptions};
use crate::error::{Error, Result};
use auth::{Account, API_BASE, WbiSigner};
use crate::endpoints::video::PLAYURL_FNVAL_DASH;
use domain::id::{Cid, DurationMs};
use domain::pgc::{PgcEpisode, PgcRankItem, PgcRankPage, PgcSeason};
use serde_json::Value;
use std::collections::BTreeMap;

/// Parameters for PGC playurl.
#[derive(Debug, Clone)]
pub struct PgcPlayUrlParams {
    pub ep_id: i64,
    pub cid: Cid,
    pub qn: u32,
    pub fnval: u32,
}

/// PGC API surface.
pub struct PgcApi;

impl PgcApi {
    /// Web rank list: `GET /pgc/web/rank/list` (WBI).
    ///
    /// `season_type`: 1 番剧 · 2 电影 · 3 纪录片 · 4 国创 · 5 电视剧 · 7 综艺.
    /// `day`: 3 | 7 ranking window (server may ignore).
    pub async fn rank_list(
        client: &BiliClient,
        account: Option<&Account>,
        device_buvid3: Option<&str>,
        wbi: &WbiSigner,
        season_type: i32,
        day: i32,
    ) -> Result<PgcRankPage> {
        let season_type = if season_type <= 0 { 1 } else { season_type };
        let day = if day <= 0 { 3 } else { day };

        let mut params = BTreeMap::new();
        params.insert("season_type".into(), season_type.to_string());
        params.insert("day".into(), day.to_string());

        let url = BiliClient::resolve_url(API_BASE, "/pgc/web/rank/list");
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
        opts = opts
            .with_wbi(wbi)
            .with_referer("https://www.bilibili.com/anime/ranking");

        let resp = client.get_bili::<Value>(&url, params, opts).await?;
        let data = resp.into_data()?;
        Ok(parse_rank(data, season_type))
    }

    /// Season detail: `GET /pgc/view/web/season` by `season_id` or `ep_id`.
    pub async fn season(
        client: &BiliClient,
        account: Option<&Account>,
        device_buvid3: Option<&str>,
        season_id: i64,
        ep_id: i64,
    ) -> Result<PgcSeason> {
        if season_id <= 0 && ep_id <= 0 {
            return Err(Error::Domain(domain::Error::InvalidArgument {
                msg: "season_id or ep_id required".into(),
            }));
        }

        let mut params = BTreeMap::new();
        if season_id > 0 {
            params.insert("season_id".into(), season_id.to_string());
        }
        if ep_id > 0 {
            params.insert("ep_id".into(), ep_id.to_string());
        }

        let url = BiliClient::resolve_url(API_BASE, "/pgc/view/web/season");
        let referer = if season_id > 0 {
            format!("https://www.bilibili.com/bangumi/play/ss{season_id}")
        } else {
            format!("https://www.bilibili.com/bangumi/play/ep{ep_id}")
        };
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
        parse_season(data)
    }

    /// PGC playurl: `GET /pgc/player/web/v2/playurl` → `result.video_info`.
    pub async fn play_url(
        client: &BiliClient,
        account: Option<&Account>,
        device_buvid3: Option<&str>,
        p: &PgcPlayUrlParams,
    ) -> Result<Value> {
        if p.ep_id <= 0 {
            return Err(Error::Domain(domain::Error::InvalidArgument {
                msg: "ep_id must be > 0".into(),
            }));
        }
        let qn = if p.qn == 0 { 80 } else { p.qn };
        let fnval = if p.fnval == 0 {
            PLAYURL_FNVAL_DASH
        } else {
            p.fnval
        };

        let mut params = BTreeMap::new();
        params.insert("ep_id".into(), p.ep_id.to_string());
        params.insert("cid".into(), p.cid.get().to_string());
        params.insert("qn".into(), qn.to_string());
        params.insert("fnval".into(), fnval.to_string());
        params.insert("fnver".into(), "0".into());
        params.insert("fourk".into(), "1".into());
        params.insert("from_client".into(), "BROWSER".into());
        params.insert("drm_tech_type".into(), "2".into());
        params.insert("support_multi_audio".into(), "true".into());

        let url = BiliClient::resolve_url(API_BASE, "/pgc/player/web/v2/playurl");
        let referer = format!("https://www.bilibili.com/bangumi/play/ep{}", p.ep_id);
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
        // Prefer nested video_info; fall back to root (some mirrors).
        if let Some(vi) = data.get("video_info") {
            return Ok(vi.clone());
        }
        Ok(data)
    }
}

fn parse_rank(data: Value, season_type: i32) -> PgcRankPage {
    let list = data
        .get("list")
        .and_then(|v| v.as_array())
        .cloned()
        .unwrap_or_default();
    let note = json_str(&data, "note");
    let mut items = Vec::new();
    for (i, v) in list.into_iter().enumerate() {
        let season_id = json_i64(&v, "season_id");
        if season_id <= 0 {
            continue;
        }
        let title = json_str(&v, "title");
        if title.is_empty() {
            continue;
        }
        let index_show = v
            .get("new_ep")
            .map(|n| json_str(n, "index_show"))
            .filter(|s| !s.is_empty())
            .unwrap_or_else(|| json_str(&v, "index_show"));
        let rating = v
            .get("rating")
            .map(|r| {
                if let Some(s) = r.as_str() {
                    s.to_string()
                } else if let Some(n) = r.as_f64() {
                    format!("{n:.1}")
                } else {
                    json_str(r, "score")
                }
            })
            .unwrap_or_default();
        let order = json_i64(&v, "rank").max(json_i64(&v, "order"));
        items.push(PgcRankItem {
            season_id,
            title,
            cover: normalize_cover(&json_str(&v, "cover")),
            badge: json_str(&v, "badge"),
            index_show,
            rating,
            order: if order > 0 { order as i32 } else { (i + 1) as i32 },
        });
    }
    PgcRankPage {
        items,
        season_type,
        note,
    }
}

fn parse_season(data: Value) -> Result<PgcSeason> {
    let season_id = json_i64(&data, "season_id");
    if season_id <= 0 {
        return Err(Error::Domain(domain::Error::NotFound));
    }
    let episodes_raw = data
        .get("episodes")
        .and_then(|e| e.as_array())
        .cloned()
        .unwrap_or_default();
    let mut episodes = Vec::new();
    for ep in episodes_raw {
        let ep_id = json_i64(&ep, "id").max(json_i64(&ep, "ep_id"));
        let cid = json_i64(&ep, "cid");
        if ep_id <= 0 || cid <= 0 {
            continue;
        }
        let duration_ms = parse_ep_duration(&ep);
        episodes.push(PgcEpisode {
            ep_id,
            aid: json_i64(&ep, "aid").max(json_i64(&ep, "aid")),
            bvid: json_str(&ep, "bvid"),
            cid,
            title: json_str(&ep, "title"),
            long_title: json_str(&ep, "long_title"),
            cover: normalize_cover(&json_str(&ep, "cover")),
            duration_ms,
            badge: json_str(&ep, "badge"),
        });
    }

    let default_ep_id = data
        .get("user_status")
        .and_then(|u| u.get("progress"))
        .and_then(|p| p.get("last_ep_id"))
        .and_then(|x| x.as_i64())
        .filter(|id| *id > 0)
        .or_else(|| {
            data.get("new_ep")
                .and_then(|n| n.get("id"))
                .and_then(|x| x.as_i64())
                .filter(|id| *id > 0)
        })
        .or_else(|| episodes.first().map(|e| e.ep_id))
        .unwrap_or(0);

    let rating_score = data
        .get("rating")
        .map(|r| {
            if let Some(n) = r.get("score").and_then(|s| s.as_f64()) {
                format!("{n:.1}")
            } else {
                json_str(r, "score")
            }
        })
        .unwrap_or_default();

    Ok(PgcSeason {
        season_id,
        season_title: first_nonempty(&[
            json_str(&data, "season_title"),
            json_str(&data, "title"),
        ]),
        title: first_nonempty(&[json_str(&data, "title"), json_str(&data, "season_title")]),
        cover: normalize_cover(&json_str(&data, "cover")),
        evaluate: json_str(&data, "evaluate"),
        season_type: json_i64(&data, "type") as i32,
        type_name: json_str(&data, "type_name"),
        rating_score,
        episodes,
        default_ep_id,
    })
}

fn parse_ep_duration(ep: &Value) -> DurationMs {
    // duration may be ms or seconds depending on endpoint version.
    let d = json_i64(ep, "duration");
    if d <= 0 {
        return DurationMs(0);
    }
    if d > 100_000 {
        // already ms (e.g. 24min ≈ 1.4e6)
        DurationMs(d)
    } else {
        DurationMs(d.saturating_mul(1000))
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
    fn parse_rank_items() {
        let data = json!({
            "list": [{
                "season_id": 33378,
                "title": "间谍过家家",
                "cover": "//i0.hdslb.com/bfs/bangumi/a.jpg",
                "badge": "会员",
                "new_ep": { "index_show": "更新至第 12 话" },
                "rating": "9.7",
                "rank": 1
            }],
            "note": "根据播放量"
        });
        let page = parse_rank(data, 1);
        assert_eq!(page.items.len(), 1);
        assert_eq!(page.items[0].season_id, 33378);
        assert!(page.items[0].cover.starts_with("https://"));
        assert_eq!(page.items[0].index_show, "更新至第 12 话");
    }

    #[test]
    fn parse_season_eps() {
        let data = json!({
            "season_id": 1,
            "title": "测试番",
            "season_title": "测试番",
            "cover": "https://i0.hdslb.com/bfs/bangumi/a.jpg",
            "evaluate": "简介",
            "type": 1,
            "type_name": "番剧",
            "rating": { "score": 9.5 },
            "episodes": [{
                "id": 1001,
                "aid": 200,
                "bvid": "BV1xx",
                "cid": 300,
                "title": "1",
                "long_title": "第一话",
                "cover": "//i0.hdslb.com/bfs/bangumi/e.jpg",
                "duration": 1440
            }]
        });
        let s = parse_season(data).unwrap();
        assert_eq!(s.season_id, 1);
        assert_eq!(s.episodes.len(), 1);
        assert_eq!(s.episodes[0].ep_id, 1001);
        assert_eq!(s.episodes[0].duration_ms.get(), 1_440_000);
        assert_eq!(s.default_ep_id, 1001);
        assert_eq!(s.rating_score, "9.5");
    }
}
