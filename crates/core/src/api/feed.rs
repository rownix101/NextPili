//! Feed-facing FFI API (recommend + popular).

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

    let feed = FeedApi::recommend(
        &app.http,
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

    let feed = FeedApi::popular(
        &app.http,
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
    NavApi::refresh_wbi(&app.http, &mut wbi, account.as_ref(), Some(buvid.as_str()))
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
