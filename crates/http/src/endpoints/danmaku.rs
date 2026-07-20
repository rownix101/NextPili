//! Danmaku segment fetch + post (REST).

use crate::client::{BiliClient, RequestOptions};
use crate::error::{Error, Result};
use auth::{Account, API_BASE, WbiSigner};
use domain::danmaku::DanmakuPostResult;
use serde::Deserialize;
use std::collections::BTreeMap;
use std::time::{SystemTime, UNIX_EPOCH};

/// Danmaku API surface.
pub struct DanmakuApi;

impl DanmakuApi {
    /// `GET /x/v2/dm/web/seg.so` — raw protobuf body for one ~6-minute segment.
    ///
    /// - `aid`: video aid (`pid`)
    /// - `cid`: part cid (`oid`)
    /// - `segment_index`: **1-based**
    ///
    /// Caller (core/`media`) parses bytes → `DanmakuItem`.
    pub async fn web_seg_bytes(
        client: &BiliClient,
        account: Option<&Account>,
        device_buvid3: Option<&str>,
        aid: i64,
        cid: i64,
        segment_index: u32,
    ) -> Result<Vec<u8>> {
        if cid <= 0 {
            return Err(Error::Domain(domain::Error::InvalidArgument {
                msg: "cid must be > 0".into(),
            }));
        }
        let seg = segment_index.max(1);

        let mut params = BTreeMap::new();
        params.insert("type".into(), "1".into());
        params.insert("oid".into(), cid.to_string());
        if aid > 0 {
            params.insert("pid".into(), aid.to_string());
        }
        params.insert("segment_index".into(), seg.to_string());
        params.insert("web_location".into(), "1315873".into());

        let url = BiliClient::resolve_url(API_BASE, "/x/v2/dm/web/seg.so");
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

        client.get_bytes(&url, params, opts).await
    }

    /// `POST /x/v2/dm/post` — send a video danmaku (Cookie + csrf + WBI).
    ///
    /// - `oid`: **cid**
    /// - `msg`: text &lt; 100 chars
    /// - `progress_ms`: appear time in video
    /// - `mode`: 1 scroll · 4 bottom · 5 top
    /// - `color`: decimal RGB888 (default white `16777215`)
    pub async fn post(
        client: &BiliClient,
        account: &Account,
        device_buvid3: Option<&str>,
        wbi: &WbiSigner,
        oid: i64,
        aid: i64,
        bvid: &str,
        msg: &str,
        progress_ms: i64,
        mode: i32,
        color: u32,
        fontsize: i32,
    ) -> Result<DanmakuPostResult> {
        if oid <= 0 {
            return Err(Error::Domain(domain::Error::InvalidArgument {
                msg: "cid (oid) must be > 0".into(),
            }));
        }
        if aid <= 0 && bvid.is_empty() {
            return Err(Error::Domain(domain::Error::InvalidArgument {
                msg: "aid or bvid required".into(),
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
        let mode = if mode == 0 { 1 } else { mode };
        let color = if color == 0 { 16_777_215 } else { color };
        let fontsize = if fontsize <= 0 { 25 } else { fontsize };
        let rnd = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.as_micros() as i64)
            .unwrap_or(0);

        let mut params = BTreeMap::new();
        params.insert("type".into(), "1".into());
        params.insert("oid".into(), oid.to_string());
        params.insert("msg".into(), msg.to_string());
        params.insert("mode".into(), mode.to_string());
        params.insert("progress".into(), progress_ms.max(0).to_string());
        params.insert("color".into(), color.to_string());
        params.insert("fontsize".into(), fontsize.to_string());
        params.insert("pool".into(), "0".into());
        params.insert("rnd".into(), rnd.to_string());
        params.insert("web_location".into(), "1315873".into());
        if aid > 0 {
            params.insert("aid".into(), aid.to_string());
        }
        if !bvid.is_empty() {
            params.insert("bvid".into(), bvid.to_string());
        }

        let url = BiliClient::resolve_url(API_BASE, "/x/v2/dm/post");
        let opts = RequestOptions {
            account: Some(account),
            device_buvid3,
            auth: crate::middleware::AuthMode::Cookie,
            csrf: true,
            ..RequestOptions::default()
        }
        .with_wbi(wbi)
        .with_referer("https://www.bilibili.com/");

        let resp = client
            .post_form_bili::<PostData>(&url, params, opts)
            .await?;
        let data = resp.into_data()?;
        Ok(DanmakuPostResult {
            dmid: data.dmid,
            visible: data.visible.unwrap_or(true),
        })
    }
}

#[derive(Debug, Deserialize, Default)]
struct PostData {
    #[serde(default)]
    dmid: i64,
    #[serde(default)]
    visible: Option<bool>,
}
