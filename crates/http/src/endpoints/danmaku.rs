//! Danmaku segment fetch (REST `seg.so` protobuf body).

use crate::client::{BiliClient, RequestOptions};
use crate::error::{Error, Result};
use auth::{Account, API_BASE};
use std::collections::BTreeMap;

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
}
