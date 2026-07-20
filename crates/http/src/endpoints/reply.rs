//! Comment list endpoints (REST main list).

use crate::client::{BiliClient, RequestOptions};
use crate::error::{Error, Result};
use auth::{Account, API_BASE};
use domain::id::UserMid;
use domain::reply::{Reply, ReplyPage};
use serde::Deserialize;
use std::collections::BTreeMap;

/// Video comment subject type.
pub const REPLY_TYPE_VIDEO: i32 = 1;

/// Sort by heat (default for main list).
pub const REPLY_MODE_HOT: i32 = 3;

/// Sort by time.
pub const REPLY_MODE_TIME: i32 = 2;

#[derive(Debug, Deserialize)]
struct MainData {
    #[serde(default)]
    cursor: CursorRaw,
    #[serde(default)]
    replies: Option<Vec<ReplyRaw>>,
    #[serde(default)]
    top_replies: Option<Vec<ReplyRaw>>,
}

#[derive(Debug, Deserialize, Default)]
struct CursorRaw {
    #[serde(default)]
    is_end: bool,
    #[serde(default)]
    all_count: i64,
    #[serde(default)]
    pagination_reply: Option<PaginationReplyRaw>,
    /// Older field sometimes present.
    #[serde(default)]
    next: i64,
}

#[derive(Debug, Deserialize, Default)]
struct PaginationReplyRaw {
    #[serde(default)]
    next_offset: String,
}

#[derive(Debug, Deserialize)]
struct ReplyRaw {
    #[serde(default)]
    rpid: i64,
    #[serde(default)]
    mid: i64,
    #[serde(default)]
    like: i64,
    #[serde(default)]
    ctime: i64,
    #[serde(default)]
    rcount: i32,
    #[serde(default)]
    member: MemberRaw,
    #[serde(default)]
    content: ContentRaw,
}

#[derive(Debug, Deserialize, Default)]
struct MemberRaw {
    #[serde(default)]
    mid: serde_json::Value,
    #[serde(default)]
    uname: String,
    #[serde(default)]
    avatar: String,
}

#[derive(Debug, Deserialize, Default)]
struct ContentRaw {
    #[serde(default)]
    message: String,
}

/// Reply API surface.
pub struct ReplyApi;

impl ReplyApi {
    /// `GET /x/v2/reply/main` — main floor with `pagination_str` cursor.
    ///
    /// - `oid`: video **aid**
    /// - `type_`: subject type (`1` = video)
    /// - `mode`: `3` heat / `2` time
    /// - `next_offset`: empty for first page; otherwise previous `ReplyPage.next_offset`
    pub async fn main_list(
        client: &BiliClient,
        account: Option<&Account>,
        device_buvid3: Option<&str>,
        oid: i64,
        type_: i32,
        mode: i32,
        next_offset: &str,
    ) -> Result<ReplyPage> {
        if oid <= 0 {
            return Err(Error::Domain(domain::Error::InvalidArgument {
                msg: "oid must be > 0".into(),
            }));
        }
        let type_ = if type_ == 0 { REPLY_TYPE_VIDEO } else { type_ };
        let mode = if mode == 0 { REPLY_MODE_HOT } else { mode };

        let mut params = BTreeMap::new();
        params.insert("oid".into(), oid.to_string());
        params.insert("type".into(), type_.to_string());
        params.insert("mode".into(), mode.to_string());
        params.insert("plat".into(), "1".into());
        params.insert("web_location".into(), "1315875".into());
        // pagination_str is a JSON string: {"offset":"<next_offset>"}
        let pagination = if next_offset.is_empty() {
            r#"{"offset":""}"#.to_string()
        } else {
            format!(
                r#"{{"offset":{}}}"#,
                serde_json::to_string(next_offset).unwrap_or_else(|_| "\"\"".into())
            )
        };
        params.insert("pagination_str".into(), pagination);

        let url = BiliClient::resolve_url(API_BASE, "/x/v2/reply/main");
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

        let resp = client.get_bili::<MainData>(&url, params, opts).await?;
        let data = resp.into_data()?;
        map_main(data)
    }
}

fn map_main(data: MainData) -> Result<ReplyPage> {
    let mut replies = Vec::new();
    // Surface top replies first (if any), then normal list.
    if let Some(top) = data.top_replies {
        for r in top {
            if let Some(item) = map_reply(r)? {
                replies.push(item);
            }
        }
    }
    if let Some(list) = data.replies {
        for r in list {
            if let Some(item) = map_reply(r)? {
                replies.push(item);
            }
        }
    }

    let next_offset = data
        .cursor
        .pagination_reply
        .as_ref()
        .map(|p| p.next_offset.clone())
        .unwrap_or_default();
    let is_end = data.cursor.is_end || next_offset.is_empty();

    Ok(ReplyPage {
        replies,
        next_offset: if is_end {
            String::new()
        } else {
            next_offset
        },
        is_end,
        all_count: data.cursor.all_count,
    })
}

fn map_reply(r: ReplyRaw) -> Result<Option<Reply>> {
    if r.rpid == 0 && r.content.message.is_empty() {
        return Ok(None);
    }
    let mid_raw = match &r.member.mid {
        serde_json::Value::Number(n) => n.as_i64().unwrap_or(r.mid),
        serde_json::Value::String(s) => s.parse().unwrap_or(r.mid),
        _ => r.mid,
    };
    let mid = UserMid::new(mid_raw.max(0)).map_err(Error::from)?;
    Ok(Some(Reply {
        rpid: r.rpid,
        mid,
        uname: r.member.uname,
        avatar: normalize_cover(&r.member.avatar),
        content: r.content.message,
        ctime_ms: r.ctime.saturating_mul(1000),
        like: r.like,
        children_count: r.rcount.max(0),
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
    fn maps_main_json() {
        let raw = json!({
            "cursor": {
                "is_end": false,
                "all_count": 42,
                "pagination_reply": { "next_offset": "abc" }
            },
            "replies": [{
                "rpid": 9,
                "mid": 1,
                "like": 3,
                "ctime": 1700000000,
                "rcount": 2,
                "member": {
                    "mid": "1",
                    "uname": "UP",
                    "avatar": "//i0.hdslb.com/f.jpg"
                },
                "content": { "message": "hi" }
            }],
            "top_replies": [{
                "rpid": 1,
                "mid": 2,
                "like": 10,
                "ctime": 1600000000,
                "rcount": 0,
                "member": {
                    "mid": 2,
                    "uname": "Top",
                    "avatar": "https://i0.hdslb.com/t.jpg"
                },
                "content": { "message": "pinned" }
            }]
        });
        let data: MainData = serde_json::from_value(raw).unwrap();
        let page = map_main(data).unwrap();
        assert_eq!(page.replies.len(), 2);
        assert_eq!(page.replies[0].content, "pinned");
        assert_eq!(page.replies[1].content, "hi");
        assert_eq!(page.next_offset, "abc");
        assert!(!page.is_end);
        assert_eq!(page.all_count, 42);
        assert!(page.replies[1].avatar.starts_with("https://"));
        assert_eq!(page.replies[1].ctime_ms, 1_700_000_000_000);
    }
}
