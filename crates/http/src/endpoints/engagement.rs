//! Archive engagement write path (relation · like · coin · fav · follow).

use crate::client::{BiliClient, RequestOptions};
use crate::error::{Error, Result};
use auth::{Account, API_BASE};
use domain::engagement::ArchiveRelation;
use serde::Deserialize;
use serde_json::Value;
use std::collections::BTreeMap;

/// Engagement / social write APIs (Cookie + csrf).
pub struct EngagementApi;

impl EngagementApi {
    /// `GET /x/web-interface/archive/relation` — needs login for meaningful flags.
    pub async fn archive_relation(
        client: &BiliClient,
        account: &Account,
        device_buvid3: Option<&str>,
        aid: i64,
        bvid: &str,
    ) -> Result<ArchiveRelation> {
        if aid <= 0 && bvid.is_empty() {
            return Err(Error::Domain(domain::Error::InvalidArgument {
                msg: "aid or bvid required".into(),
            }));
        }
        let mut params = BTreeMap::new();
        if aid > 0 {
            params.insert("aid".into(), aid.to_string());
        }
        if !bvid.is_empty() {
            params.insert("bvid".into(), bvid.to_string());
        }

        let url = BiliClient::resolve_url(API_BASE, "/x/web-interface/archive/relation");
        let opts = RequestOptions {
            account: Some(account),
            device_buvid3,
            auth: crate::middleware::AuthMode::Cookie,
            ..RequestOptions::default()
        }
        .with_referer(video_referer(bvid, aid));

        let resp = client
            .get_bili::<RelationData>(&url, params, opts)
            .await?;
        let data = resp.into_data().unwrap_or_default();
        Ok(map_relation(data))
    }

    /// `POST /x/web-interface/archive/like`
    ///
    /// Web convention: `like=1` 点赞 · `like=2` 取消.
    pub async fn archive_like(
        client: &BiliClient,
        account: &Account,
        device_buvid3: Option<&str>,
        aid: i64,
        like: bool,
        bvid: &str,
    ) -> Result<()> {
        if aid <= 0 {
            return Err(Error::Domain(domain::Error::InvalidArgument {
                msg: "aid required".into(),
            }));
        }
        let mut params = BTreeMap::new();
        params.insert("aid".into(), aid.to_string());
        params.insert("like".into(), if like { "1" } else { "2" }.into());

        let url = BiliClient::resolve_url(API_BASE, "/x/web-interface/archive/like");
        post_csrf(
            client,
            account,
            device_buvid3,
            &url,
            params,
            video_referer(bvid, aid),
        )
        .await
    }

    /// `POST /x/web-interface/coin/add`
    ///
    /// `multiply` is 1 or 2; `also_like` maps to `select_like`.
    pub async fn archive_coin(
        client: &BiliClient,
        account: &Account,
        device_buvid3: Option<&str>,
        aid: i64,
        multiply: i32,
        also_like: bool,
        bvid: &str,
    ) -> Result<()> {
        if aid <= 0 {
            return Err(Error::Domain(domain::Error::InvalidArgument {
                msg: "aid required".into(),
            }));
        }
        let multiply = multiply.clamp(1, 2);
        let mut params = BTreeMap::new();
        params.insert("aid".into(), aid.to_string());
        params.insert("multiply".into(), multiply.to_string());
        params.insert(
            "select_like".into(),
            if also_like { "1" } else { "0" }.into(),
        );
        if !bvid.is_empty() {
            params.insert("bvid".into(), bvid.to_string());
        }

        let url = BiliClient::resolve_url(API_BASE, "/x/web-interface/coin/add");
        post_csrf(
            client,
            account,
            device_buvid3,
            &url,
            params,
            video_referer(bvid, aid),
        )
        .await
    }

    /// `POST /x/v3/fav/resource/deal` — add and/or remove from folders.
    pub async fn fav_resource_deal(
        client: &BiliClient,
        account: &Account,
        device_buvid3: Option<&str>,
        aid: i64,
        add_media_ids: &str,
        del_media_ids: &str,
    ) -> Result<()> {
        if aid <= 0 {
            return Err(Error::Domain(domain::Error::InvalidArgument {
                msg: "aid required".into(),
            }));
        }
        let mut params = BTreeMap::new();
        params.insert("rid".into(), aid.to_string());
        params.insert("type".into(), "2".into());
        if !add_media_ids.is_empty() {
            params.insert("add_media_ids".into(), add_media_ids.to_string());
        }
        if !del_media_ids.is_empty() {
            params.insert("del_media_ids".into(), del_media_ids.to_string());
        }

        let url = BiliClient::resolve_url(API_BASE, "/x/v3/fav/resource/deal");
        post_csrf(
            client,
            account,
            device_buvid3,
            &url,
            params,
            "https://www.bilibili.com/",
        )
        .await
    }

    /// `POST /x/v3/fav/resource/unfav-all` — remove from every folder.
    pub async fn fav_resource_unfav_all(
        client: &BiliClient,
        account: &Account,
        device_buvid3: Option<&str>,
        aid: i64,
    ) -> Result<()> {
        if aid <= 0 {
            return Err(Error::Domain(domain::Error::InvalidArgument {
                msg: "aid required".into(),
            }));
        }
        let mut params = BTreeMap::new();
        params.insert("rid".into(), aid.to_string());
        params.insert("type".into(), "2".into());

        let url = BiliClient::resolve_url(API_BASE, "/x/v3/fav/resource/unfav-all");
        post_csrf(
            client,
            account,
            device_buvid3,
            &url,
            params,
            "https://www.bilibili.com/",
        )
        .await
    }

    /// `POST /x/relation/modify` — follow / unfollow UP.
    ///
    /// `act`: 1 follow · 2 unfollow. `re_src` defaults to web video (14).
    pub async fn relation_modify(
        client: &BiliClient,
        account: &Account,
        device_buvid3: Option<&str>,
        mid: i64,
        follow: bool,
    ) -> Result<()> {
        if mid <= 0 {
            return Err(Error::Domain(domain::Error::InvalidArgument {
                msg: "mid required".into(),
            }));
        }
        let mut params = BTreeMap::new();
        params.insert("fid".into(), mid.to_string());
        params.insert("act".into(), if follow { "1" } else { "2" }.into());
        params.insert("re_src".into(), "14".into());

        let url = BiliClient::resolve_url(API_BASE, "/x/relation/modify");
        post_csrf(
            client,
            account,
            device_buvid3,
            &url,
            params,
            "https://www.bilibili.com/",
        )
        .await
    }
}

async fn post_csrf(
    client: &BiliClient,
    account: &Account,
    device_buvid3: Option<&str>,
    url: &str,
    params: BTreeMap<String, String>,
    referer: &str,
) -> Result<()> {
    let opts = RequestOptions {
        account: Some(account),
        device_buvid3,
        auth: crate::middleware::AuthMode::Cookie,
        csrf: true,
        ..RequestOptions::default()
    }
    .with_referer(referer);

    let resp = client.post_form_bili::<Value>(url, params, opts).await?;
    resp.ensure_ok()
}

fn video_referer(bvid: &str, aid: i64) -> &'static str {
    // Static referer is enough for csrf checks; path is not signed.
    let _ = (bvid, aid);
    "https://www.bilibili.com/"
}

#[derive(Debug, Deserialize, Default)]
struct RelationData {
    #[serde(default)]
    attention: i32,
    #[serde(default)]
    favorite: i32,
    #[serde(default)]
    like: i32,
    #[serde(default)]
    dislike: i32,
    #[serde(default)]
    coin: i32,
}

fn map_relation(d: RelationData) -> ArchiveRelation {
    ArchiveRelation {
        liked: d.like != 0,
        disliked: d.dislike != 0,
        coin: d.coin.clamp(0, 2),
        favorited: d.favorite != 0,
        following: d.attention != 0,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn maps_relation_flags() {
        let r = map_relation(RelationData {
            attention: 1,
            favorite: 1,
            like: 1,
            dislike: 0,
            coin: 2,
        });
        assert!(r.liked && r.favorited && r.following);
        assert!(!r.disliked);
        assert_eq!(r.coin, 2);
    }
}
