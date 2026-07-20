//! Video detail endpoints.

use crate::client::{BiliClient, RequestOptions};
use crate::error::{Error, Result};
use auth::{Account, API_BASE};
use domain::id::{Cid, DurationMs, UserMid, VideoId};
use domain::video::{Owner, VideoDetail, VideoPage, VideoStat};
use serde::Deserialize;
use std::collections::BTreeMap;

#[derive(Debug, Deserialize)]
struct ViewData {
    #[serde(default)]
    aid: i64,
    #[serde(default)]
    bvid: String,
    #[serde(default)]
    title: String,
    #[serde(default)]
    pic: String,
    #[serde(default)]
    desc: String,
    #[serde(default)]
    duration: i64,
    #[serde(default)]
    owner: OwnerRaw,
    #[serde(default)]
    pages: Vec<PageRaw>,
    #[serde(default)]
    stat: StatRaw,
}

#[derive(Debug, Deserialize, Default)]
struct OwnerRaw {
    #[serde(default)]
    mid: i64,
    #[serde(default)]
    name: String,
    #[serde(default)]
    face: String,
}

#[derive(Debug, Deserialize, Default)]
struct PageRaw {
    #[serde(default)]
    cid: i64,
    #[serde(default)]
    page: i32,
    #[serde(default)]
    part: String,
    #[serde(default)]
    duration: i64,
}

#[derive(Debug, Deserialize, Default)]
struct StatRaw {
    #[serde(default)]
    view: i64,
    #[serde(default)]
    danmaku: i64,
    #[serde(default)]
    reply: i64,
    #[serde(default)]
    favorite: i64,
    #[serde(default)]
    coin: i64,
    #[serde(default)]
    share: i64,
    #[serde(default)]
    like: i64,
}

/// Video API surface.
pub struct VideoApi;

impl VideoApi {
    /// `GET /x/web-interface/view` by aid or bvid.
    pub async fn detail(
        client: &BiliClient,
        account: Option<&Account>,
        device_buvid3: Option<&str>,
        id: &VideoId,
    ) -> Result<VideoDetail> {
        let mut params = BTreeMap::new();
        match id {
            VideoId::Bvid(b) => {
                params.insert("bvid".into(), b.clone());
            }
            VideoId::Aid(a) => {
                params.insert("aid".into(), a.to_string());
            }
        }

        let url = BiliClient::resolve_url(API_BASE, "/x/web-interface/view");
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

        let resp = client.get_bili::<ViewData>(&url, params, opts).await?;
        let data = resp.into_data()?;
        map_view(data)
    }
}

fn map_view(data: ViewData) -> Result<VideoDetail> {
    if data.bvid.is_empty() && data.aid <= 0 {
        return Err(Error::Parse("video view missing aid/bvid".into()));
    }
    if data.title.is_empty() {
        return Err(Error::Parse("video view missing title".into()));
    }

    let mid = UserMid::new(data.owner.mid.max(0)).map_err(Error::from)?;
    let pages: Result<Vec<VideoPage>> = data
        .pages
        .into_iter()
        .filter(|p| p.cid > 0)
        .map(|p| {
            Ok(VideoPage {
                cid: Cid::new(p.cid).map_err(Error::from)?,
                page: if p.page > 0 { p.page } else { 1 },
                part: p.part,
                duration_ms: DurationMs(p.duration.saturating_mul(1000)),
            })
        })
        .collect();
    let pages = pages?;

    Ok(VideoDetail {
        aid: data.aid,
        bvid: data.bvid,
        title: data.title,
        cover: normalize_cover(&data.pic),
        desc: data.desc,
        owner: Owner {
            mid,
            name: data.owner.name,
            face: normalize_cover(&data.owner.face),
        },
        pages,
        stat: VideoStat {
            view: data.stat.view,
            danmaku: data.stat.danmaku,
            reply: data.stat.reply,
            favorite: data.stat.favorite,
            coin: data.stat.coin,
            share: data.stat.share,
            like: data.stat.like,
        },
        duration_ms: DurationMs(data.duration.saturating_mul(1000)),
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
    fn maps_view_json() {
        let raw = json!({
            "aid": 170001,
            "bvid": "BV1xx411c7mD",
            "title": "t",
            "pic": "//i0.hdslb.com/a.jpg",
            "desc": "d",
            "duration": 120,
            "owner": { "mid": 1, "name": "UP", "face": "//i0.hdslb.com/f.jpg" },
            "pages": [
                { "cid": 99, "page": 1, "part": "P1", "duration": 60 },
                { "cid": 100, "page": 2, "part": "P2", "duration": 60 }
            ],
            "stat": {
                "view": 1, "danmaku": 2, "reply": 3, "favorite": 4,
                "coin": 5, "share": 6, "like": 7
            }
        });
        let data: ViewData = serde_json::from_value(raw).unwrap();
        let d = map_view(data).unwrap();
        assert_eq!(d.aid, 170001);
        assert_eq!(d.pages.len(), 2);
        assert_eq!(d.pages[0].cid.get(), 99);
        assert_eq!(d.duration_ms.get(), 120_000);
        assert!(d.cover.starts_with("https://"));
        assert_eq!(d.stat.like, 7);
    }
}
