//! Feed-facing FFI API (recommend + popular + partition ranking).

use crate::app::CoreApp;
use crate::error::{AppError, ErrorKind};
use auth::AccountSlot;
use http::{FeedApi, NavApi};

/// Single card in home feed.
#[derive(Debug, Clone)]
pub struct FeedItemDto {
    pub aid: i64,
    pub bvid: String,
    pub title: String,
    pub cover: String,
    pub owner_name: String,
    pub duration_ms: i64,
    pub goto: String,
}

/// Recommend page payload.
#[derive(Debug, Clone)]
pub struct RecommendFeedDto {
    pub items: Vec<FeedItemDto>,
    /// Pass this as `fresh_idx` on the next call (starts at 0/1).
    pub next_fresh_idx: i32,
}

/// Popular page payload.
#[derive(Debug, Clone)]
pub struct PopularFeedDto {
    pub items: Vec<FeedItemDto>,
    pub next_pn: i32,
    pub no_more: bool,
}

/// Partition ranking payload (`ranking/v2`; typically ≤100 items, no paging).
#[derive(Debug, Clone)]
pub struct RankingFeedDto {
    pub items: Vec<FeedItemDto>,
    pub note: String,
}

/// One primary partition entry for home 分区导航 (text labels only).
#[derive(Debug, Clone)]
pub struct RegionDto {
    pub rid: i32,
    /// Stable key for l10n (e.g. `all`, `douga`, `music`). Empty for unknown.
    pub key: String,
    /// Chinese display name from taxonomy (Flutter may prefer ARB by `key`).
    pub name: String,
}

/// Home recommend feed (WBI · recommend slot).
///
/// `fresh_idx`: refresh counter, start at `0` or `1`, then use `next_fresh_idx`.
/// `ps`: page size (default 12 if 0).
pub async fn feed_recommend(fresh_idx: i32, ps: u32) -> Result<RecommendFeedDto, AppError> {
    let app = CoreApp::global()?;
    ensure_wbi(&app).await?;

    let buvid = app.store.buvid3();
    let account = {
        let reg = app.accounts.read();
        reg.account_for(AccountSlot::Recommend)
            .or_else(|| reg.active_main())
            .cloned()
    };
    let wbi = app.wbi.read().clone();
    let page_size = if ps == 0 { 12 } else { ps };

    let http = app.http();
    let feed = FeedApi::recommend(
        &http,
        account.as_ref(),
        Some(buvid.as_str()),
        &wbi,
        fresh_idx,
        page_size,
    )
    .await?;

    Ok(RecommendFeedDto {
        items: feed.items.into_iter().map(map_item).collect(),
        next_fresh_idx: feed.next_fresh_idx,
    })
}

/// Popular feed (paginated).
///
/// `pn`: page number starting at 1; `ps`: page size (default 20 if 0).
pub async fn feed_popular(pn: i32, ps: u32) -> Result<PopularFeedDto, AppError> {
    let app = CoreApp::global()?;
    let buvid = app.store.buvid3();
    let account = {
        let reg = app.accounts.read();
        reg.account_for(AccountSlot::Recommend)
            .or_else(|| reg.active_main())
            .cloned()
    };
    let page_size = if ps == 0 { 20 } else { ps };

    let http = app.http();
    let feed = FeedApi::popular(
        &http,
        account.as_ref(),
        Some(buvid.as_str()),
        pn,
        page_size,
    )
    .await?;

    Ok(PopularFeedDto {
        items: feed.items.into_iter().map(map_item).collect(),
        next_pn: feed.next_pn,
        no_more: feed.no_more,
    })
}

/// Primary partition list for home 分区导航 (static main tids; ranking only).
pub fn feed_regions() -> Vec<RegionDto> {
    PRIMARY_REGIONS
        .iter()
        .map(|(rid, key, name)| RegionDto {
            rid: *rid,
            key: (*key).into(),
            name: (*name).into(),
        })
        .collect()
}

/// Partition ranking (WBI · recommend slot).
///
/// `rid`: primary partition tid; `0` = site-wide.
/// `rank_type`: `all` | `rookie` | `origin` (empty → `all`).
pub async fn feed_ranking(rid: i32, rank_type: String) -> Result<RankingFeedDto, AppError> {
    let app = CoreApp::global()?;
    ensure_wbi(&app).await?;

    let buvid = app.store.buvid3();
    let account = {
        let reg = app.accounts.read();
        reg.account_for(AccountSlot::Recommend)
            .or_else(|| reg.active_main())
            .cloned()
    };
    let wbi = app.wbi.read().clone();
    let rank_type = if rank_type.is_empty() {
        "all".into()
    } else {
        rank_type
    };

    let http = app.http();
    let feed = FeedApi::ranking(
        &http,
        account.as_ref(),
        Some(buvid.as_str()),
        &wbi,
        rid,
        &rank_type,
    )
    .await?;

    Ok(RankingFeedDto {
        items: feed.items.into_iter().map(map_item).collect(),
        note: feed.note,
    })
}

/// Main partitions supported by `ranking/v2` (`rid`).
const PRIMARY_REGIONS: &[(i32, &str, &str)] = &[
    (0, "all", "全站"),
    (1, "douga", "动画"),
    (3, "music", "音乐"),
    (129, "dance", "舞蹈"),
    (4, "game", "游戏"),
    (36, "knowledge", "知识"),
    (188, "tech", "科技"),
    (234, "sports", "运动"),
    (223, "car", "汽车"),
    (160, "life", "生活"),
    (211, "food", "美食"),
    (217, "animal", "动物圈"),
    (119, "kichiku", "鬼畜"),
    (155, "fashion", "时尚"),
    (5, "ent", "娱乐"),
    (181, "cinephile", "影视"),
    (177, "documentary", "纪录片"),
    (23, "movie", "电影"),
    (11, "tv", "电视剧"),
    (202, "info", "资讯"),
];

fn map_item(item: domain::FeedItem) -> FeedItemDto {
    FeedItemDto {
        aid: item.aid,
        bvid: item.bvid,
        title: item.title,
        cover: item.cover,
        owner_name: item.owner_name,
        duration_ms: item.duration_ms.get(),
        goto: item.goto,
    }
}

async fn ensure_wbi(app: &CoreApp) -> Result<(), AppError> {
    if app.wbi.read().has_keys() {
        return Ok(());
    }
    let buvid = app.store.buvid3();
    let account = app.accounts.read().active_main().cloned();
    let mut wbi = app.wbi.read().clone();
    NavApi::refresh_wbi(&app.http(), &mut wbi, account.as_ref(), Some(buvid.as_str()))
        .await
        .map_err(AppError::from)?;
    if !wbi.has_keys() {
        return Err(AppError::new(
            ErrorKind::Internal,
            "无法获取 WBI 签名密钥",
        ));
    }
    *app.wbi.write() = wbi;
    Ok(())
}
