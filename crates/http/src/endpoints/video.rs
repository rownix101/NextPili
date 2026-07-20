//! Video detail + playurl + heartbeat endpoints.

use crate::client::{BiliClient, RequestOptions};
use crate::error::{Error, Result};
use auth::{Account, API_BASE, WbiSigner};
use domain::id::{Cid, DurationMs, UserMid, VideoId};
use domain::video::{Owner, VideoDetail, VideoPage, VideoStat};
use serde::Deserialize;
use serde_json::Value;
use std::collections::BTreeMap;
use std::time::{SystemTime, UNIX_EPOCH};

/// Default fnval: DASH + HDR + 4K + Dolby + AV1 etc. (community common mask).
pub const PLAYURL_FNVAL_DASH: u32 = 4048;

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
    #[serde(default, deserialize_with = "crate::serde_util::null_as_default")]
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

/// Parameters for playurl request.
#[derive(Debug, Clone)]
pub struct PlayUrlParams<'a> {
    pub id: &'a VideoId,
    pub cid: Cid,
    pub qn: u32,
    pub fnval: u32,
    /// Optional multi-language / AI audio track language code.
    pub cur_language: Option<&'a str>,
}

/// Context for playback heartbeat / history.
#[derive(Debug, Clone)]
pub struct HeartbeatParams {
    pub aid: i64,
    pub bvid: String,
    pub cid: i64,
    pub mid: i64,
    /// Seconds played (server field name: played_time).
    pub played_time: i64,
    /// 0 playing / 1 start / 2 pause-end (common web mapping).
    pub play_type: i32,
    pub start_ts: i64,
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

    /// `GET /x/player/wbi/v2` — playback page meta (subtitles, viewpoints, …).
    pub async fn player_v2(
        client: &BiliClient,
        account: Option<&Account>,
        device_buvid3: Option<&str>,
        wbi: &WbiSigner,
        id: &VideoId,
        cid: Cid,
    ) -> Result<Value> {
        let mut params = BTreeMap::new();
        match id {
            VideoId::Bvid(b) => {
                params.insert("bvid".into(), b.clone());
            }
            VideoId::Aid(a) => {
                params.insert("aid".into(), a.to_string());
            }
        }
        params.insert("cid".into(), cid.get().to_string());

        let url = BiliClient::resolve_url(API_BASE, "/x/player/wbi/v2");
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

        let resp = client.get_bili::<Value>(&url, params, opts).await?;
        resp.into_data()
    }

    /// `GET /x/player/wbi/playurl` — returns raw `data` JSON for media crate.
    pub async fn play_url(
        client: &BiliClient,
        account: Option<&Account>,
        device_buvid3: Option<&str>,
        wbi: &WbiSigner,
        p: PlayUrlParams<'_>,
    ) -> Result<Value> {
        let qn = if p.qn == 0 { 80 } else { p.qn };
        let fnval = if p.fnval == 0 {
            PLAYURL_FNVAL_DASH
        } else {
            p.fnval
        };

        let mut params = BTreeMap::new();
        match p.id {
            VideoId::Bvid(b) => {
                params.insert("bvid".into(), b.clone());
            }
            VideoId::Aid(a) => {
                params.insert("avid".into(), a.to_string());
            }
        }
        params.insert("cid".into(), p.cid.get().to_string());
        params.insert("qn".into(), qn.to_string());
        params.insert("fnval".into(), fnval.to_string());
        params.insert("fnver".into(), "0".into());
        params.insert("fourk".into(), "1".into());
        params.insert("gaia_source".into(), "pre-load".into());
        params.insert("isGaiaAvoided".into(), "true".into());
        params.insert("web_location".into(), "1315873".into());
        params.insert("voice_balance".into(), "1".into());
        params.insert("try_look".into(), "1".into());
        // Risk-control placeholders (empty / fixed shapes used by many clients).
        params.insert("dm_img_list".into(), "[]".into());
        params.insert("dm_img_str".into(), "V2ViR0wgMS4wIChPcGVuR0wgRVMgMi4wIENocm9taXVtKQ".into());
        params.insert(
            "dm_cover_img_str".into(),
            "QU5HTEUgKE5WSURJQSwgTlZJRElBIEdlRm9yY2UgUlRYIDMwNjAgTGFwdG9wIEdQVSAoMHgwMDAwMjVFMylE".into(),
        );
        params.insert(
            "dm_img_inter".into(),
            r#"{"ds":[],"wh":[0,0,0],"of":[0,0,0]}"#.into(),
        );
        if let Some(lang) = p.cur_language {
            params.insert("cur_language".into(), lang.to_string());
        }

        let url = BiliClient::resolve_url(API_BASE, "/x/player/wbi/playurl");
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

        let resp = client.get_bili::<Value>(&url, params, opts).await?;
        resp.into_data()
    }

    /// `POST /x/click-interface/web/heartbeat` — skip silently when no account/csrf.
    pub async fn heartbeat(
        client: &BiliClient,
        account: Option<&Account>,
        device_buvid3: Option<&str>,
        p: &HeartbeatParams,
    ) -> Result<()> {
        let Some(acc) = account else {
            return Ok(());
        };
        if acc.cookie_jar.csrf().is_none() {
            return Ok(());
        }

        let mut params = BTreeMap::new();
        params.insert("aid".into(), p.aid.to_string());
        if !p.bvid.is_empty() {
            params.insert("bvid".into(), p.bvid.clone());
        }
        params.insert("cid".into(), p.cid.to_string());
        if p.mid > 0 {
            params.insert("mid".into(), p.mid.to_string());
        }
        params.insert("played_time".into(), p.played_time.to_string());
        params.insert("real_played_time".into(), p.played_time.to_string());
        params.insert("realtime".into(), p.played_time.to_string());
        params.insert("start_ts".into(), p.start_ts.to_string());
        params.insert("type".into(), "3".into());
        params.insert("dt".into(), "2".into());
        params.insert("play_type".into(), p.play_type.to_string());
        // quality placeholder
        params.insert("quality".into(), "0".into());
        params.insert("video_duration".into(), "0".into());
        params.insert("last_play_progress_time".into(), p.played_time.to_string());
        params.insert("max_play_progress_time".into(), p.played_time.to_string());

        let url = BiliClient::resolve_url(API_BASE, "/x/click-interface/web/heartbeat");
        let opts = RequestOptions {
            account: Some(acc),
            device_buvid3,
            auth: crate::middleware::AuthMode::Cookie,
            csrf: true,
            ..RequestOptions::default()
        };

        // Heartbeat failures must not break playback — map soft.
        match client.post_form_bili::<Value>(&url, params, opts).await {
            Ok(resp) => {
                if resp.code != 0 {
                    tracing::debug!(code = resp.code, "heartbeat non-zero");
                }
                Ok(())
            }
            Err(e) => {
                tracing::debug!(error = %e, "heartbeat failed");
                Ok(())
            }
        }
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

/// Unix timestamp seconds.
pub fn now_unix() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0)
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
