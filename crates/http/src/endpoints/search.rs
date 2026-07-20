//! Search endpoints (suggest + type=video).

use crate::client::{BiliClient, RequestOptions};
use crate::error::{Error, Result};
use auth::{Account, API_BASE, SEARCH_BASE, WbiSigner};
use domain::search::{parse_duration_label, strip_search_highlight, SearchVideoItem};
use serde::Deserialize;
use serde_json::Value;
use std::collections::BTreeMap;

/// Suggest hits for the search box.
#[derive(Debug, Clone)]
pub struct SearchSuggest {
    pub terms: Vec<String>,
}

/// Paginated video search result.
#[derive(Debug, Clone)]
pub struct SearchVideoPage {
    pub items: Vec<SearchVideoItem>,
    pub page: i32,
    pub num_pages: i32,
    pub num_results: i64,
}

#[derive(Debug, Deserialize, Default)]
struct SuggestPayload {
    #[serde(default)]
    tag: Vec<SuggestTag>,
}

#[derive(Debug, Deserialize, Default)]
struct SuggestTag {
    #[serde(default)]
    value: String,
    #[serde(default)]
    name: String,
    #[serde(default)]
    term: String,
}

#[derive(Debug, Deserialize, Default)]
struct SearchTypeData {
    #[serde(default)]
    result: Option<Vec<Value>>,
    #[serde(default, rename = "numPages")]
    num_pages: i32,
    #[serde(default, rename = "numResults")]
    num_results: i64,
    #[serde(default)]
    page: i32,
}

/// Search API surface.
pub struct SearchApi;

impl SearchApi {
    /// `GET https://s.search.bilibili.com/main/suggest`
    pub async fn suggest(
        client: &BiliClient,
        account: Option<&Account>,
        device_buvid3: Option<&str>,
        term: &str,
    ) -> Result<SearchSuggest> {
        let term = term.trim();
        if term.is_empty() {
            return Ok(SearchSuggest { terms: Vec::new() });
        }

        let mut params = BTreeMap::new();
        params.insert("term".into(), term.to_string());
        params.insert("main_ver".into(), "v1".into());
        params.insert("highlight".into(), term.to_string());

        let url = BiliClient::resolve_url(SEARCH_BASE, "/main/suggest");
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

        // Suggest payload is non-standard (`result.tag`, sometimes a JSON string).
        let bytes = client.get_bytes(&url, params, opts).await?;
        let text = String::from_utf8_lossy(&bytes);
        let terms = parse_suggest_body(&text)?;
        Ok(SearchSuggest { terms })
    }

    /// `GET /x/web-interface/wbi/search/type` with `search_type=video` (WBI).
    pub async fn search_video(
        client: &BiliClient,
        account: Option<&Account>,
        device_buvid3: Option<&str>,
        wbi: &WbiSigner,
        keyword: &str,
        page: i32,
    ) -> Result<SearchVideoPage> {
        let keyword = keyword.trim();
        if keyword.is_empty() {
            return Err(Error::Domain(domain::Error::InvalidArgument {
                msg: "keyword required".into(),
            }));
        }
        let page = page.max(1);

        let mut params = BTreeMap::new();
        params.insert("search_type".into(), "video".into());
        params.insert("keyword".into(), keyword.to_string());
        params.insert("page".into(), page.to_string());
        params.insert("page_size".into(), "20".into());
        params.insert("order".into(), "totalrank".into());
        params.insert("platform".into(), "pc".into());
        params.insert("web_location".into(), "1430654".into());

        let url = BiliClient::resolve_url(API_BASE, "/x/web-interface/wbi/search/type");
        let referer = format!(
            "https://search.bilibili.com/video?keyword={}",
            urlencoding_query(keyword)
        );
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
        opts = opts.with_wbi(wbi).with_referer(&referer);

        let resp = client.get_bili::<SearchTypeData>(&url, params, opts).await?;
        let data = resp.into_data()?;
        let items = data
            .result
            .unwrap_or_default()
            .into_iter()
            .filter_map(|v| parse_video_hit(v))
            .collect();

        Ok(SearchVideoPage {
            items,
            page: if data.page > 0 { data.page } else { page },
            num_pages: data.num_pages,
            num_results: data.num_results,
        })
    }
}

fn parse_suggest_body(text: &str) -> Result<Vec<String>> {
    let text = text.trim();
    if text.is_empty() {
        return Ok(Vec::new());
    }

    // Sometimes the body is a JSON *string* containing JSON.
    let value: Value = match serde_json::from_str(text) {
        Ok(Value::String(s)) => {
            serde_json::from_str(&s).map_err(|e| Error::Parse(e.to_string()))?
        }
        Ok(v) => v,
        Err(e) => return Err(Error::Parse(e.to_string())),
    };

    // Prefer result.tag; also accept data.tag.
    let tag_val = value
        .get("result")
        .and_then(|r| r.get("tag"))
        .or_else(|| value.get("data").and_then(|d| d.get("tag")))
        .cloned()
        .unwrap_or(Value::Null);

    let payload: SuggestPayload = if tag_val.is_null() {
        SuggestPayload::default()
    } else {
        serde_json::from_value(Value::Object(
            [("tag".into(), tag_val)].into_iter().collect(),
        ))
        .unwrap_or_default()
    };

    let mut terms = Vec::new();
    for t in payload.tag {
        let term = first_nonempty(&[&t.value, &t.name, &t.term]);
        let term = strip_search_highlight(&term);
        if !term.is_empty() && !terms.iter().any(|x| x == &term) {
            terms.push(term);
        }
    }
    Ok(terms)
}

fn parse_video_hit(v: Value) -> Option<SearchVideoItem> {
    let ty = v.get("type").and_then(|x| x.as_str()).unwrap_or("video");
    if ty != "video" {
        return None;
    }

    let aid = v
        .get("aid")
        .or_else(|| v.get("id"))
        .and_then(|x| x.as_i64())
        .unwrap_or(0);
    let bvid = v
        .get("bvid")
        .and_then(|x| x.as_str())
        .unwrap_or("")
        .to_string();
    if aid <= 0 && bvid.is_empty() {
        return None;
    }

    let raw_title = v
        .get("title")
        .and_then(|x| x.as_str())
        .unwrap_or("")
        .to_string();
    let title = strip_search_highlight(&raw_title);
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
        .get("author")
        .and_then(|x| x.as_str())
        .or_else(|| v.get("owner").and_then(|o| o.get("name")).and_then(|x| x.as_str()))
        .unwrap_or("")
        .to_string();

    let duration_ms = match v.get("duration") {
        Some(Value::String(s)) => parse_duration_label(s),
        Some(Value::Number(n)) => {
            let sec = n.as_i64().unwrap_or(0);
            domain::id::DurationMs(sec.saturating_mul(1000).max(0))
        }
        _ => domain::id::DurationMs(0),
    };

    let play = v
        .get("play")
        .and_then(|x| x.as_i64())
        .or_else(|| v.get("view").and_then(|x| x.as_i64()))
        .unwrap_or(0);

    Some(SearchVideoItem {
        aid,
        bvid,
        title,
        cover,
        owner_name,
        duration_ms,
        play,
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

fn first_nonempty(parts: &[&str]) -> String {
    for p in parts {
        let t = p.trim();
        if !t.is_empty() {
            return t.to_string();
        }
    }
    String::new()
}

fn urlencoding_query(s: &str) -> String {
    let mut out = String::with_capacity(s.len() * 2);
    for b in s.bytes() {
        match b {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => {
                out.push(b as char)
            }
            b' ' => out.push_str("%20"),
            _ => out.push_str(&format!("%{b:02X}")),
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn parse_suggest_tags() {
        let body = r#"{"code":0,"result":{"tag":[{"value":"rust"},{"name":"flutter"}]}}"#;
        let terms = parse_suggest_body(body).unwrap();
        assert_eq!(terms, vec!["rust", "flutter"]);
    }

    #[test]
    fn parse_suggest_string_body() {
        let inner = r#"{"code":0,"result":{"tag":[{"value":"foo"}]}}"#;
        let wrapped = serde_json::to_string(inner).unwrap();
        let terms = parse_suggest_body(&wrapped).unwrap();
        assert_eq!(terms, vec!["foo"]);
    }

    #[test]
    fn parse_video_with_em_title() {
        let v = json!({
            "type": "video",
            "aid": 42,
            "bvid": "BV1xx",
            "title": r#"hello <em class="keyword">world</em>"#,
            "pic": "//i0.hdslb.com/a.jpg",
            "author": "UP",
            "duration": "1:30",
            "play": 100
        });
        let item = parse_video_hit(v).unwrap();
        assert_eq!(item.title, "hello world");
        assert_eq!(item.duration_ms.get(), 90_000);
        assert!(item.cover.starts_with("https://"));
        assert_eq!(item.play, 100);
    }

    #[test]
    fn drops_non_video() {
        let v = json!({"type": "bili_user", "title": "x", "mid": 1});
        assert!(parse_video_hit(v).is_none());
    }
}
