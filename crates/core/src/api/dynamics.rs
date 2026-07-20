//! Follow-dynamics FFI (read-only feed).

use crate::app::CoreApp;
use crate::error::{AppError, ErrorKind};
use auth::AccountSlot;
use http::DynamicsApi;

/// One dynamic card for the UI.
#[derive(Debug, Clone)]
pub struct DynamicItemDto {
    pub id: String,
    /// e.g. `DYNAMIC_TYPE_AV`
    pub type_tag: String,
    pub author_mid: i64,
    pub author_name: String,
    pub author_face: String,
    pub pub_ts_ms: i64,
    pub text: String,
    pub title: String,
    pub cover: String,
    pub aid: i64,
    pub bvid: String,
    pub duration_ms: i64,
    pub like_count: i64,
    pub comment_count: i64,
    pub repost_count: i64,
}

/// Cursor page of dynamics.
#[derive(Debug, Clone)]
pub struct DynamicPageDto {
    pub items: Vec<DynamicItemDto>,
    pub next_offset: String,
    pub has_more: bool,
    pub update_baseline: String,
    pub update_num: i32,
}

/// Follow dynamics feed (main slot · Cookie).
///
/// First page: `offset = ""`. Subsequent: pass `next_offset`.
/// `type_filter`: `all` / `video` / `pgc` / `article` (empty → `all`).
/// `page`: 1-based page counter (web still expects it; cursor is `offset`).
pub async fn dynamics_feed(
    offset: String,
    type_filter: String,
    page: i32,
) -> Result<DynamicPageDto, AppError> {
    let app = CoreApp::global()?;
    let account = require_main(&app)?;
    let buvid = app.store.buvid3();
    let http = app.http();
    let page = if page <= 0 { 1 } else { page };

    let feed = DynamicsApi::feed_all(
        &http,
        &account,
        Some(buvid.as_str()),
        &offset,
        &type_filter,
        page,
    )
    .await?;

    Ok(DynamicPageDto {
        items: feed
            .items
            .into_iter()
            .map(|it| DynamicItemDto {
                id: it.id,
                type_tag: it.type_tag,
                author_mid: it.author_mid,
                author_name: it.author_name,
                author_face: it.author_face,
                pub_ts_ms: it.pub_ts_ms,
                text: it.text,
                title: it.title,
                cover: it.cover,
                aid: it.aid,
                bvid: it.bvid,
                duration_ms: it.duration_ms.get(),
                like_count: it.like_count,
                comment_count: it.comment_count,
                repost_count: it.repost_count,
            })
            .collect(),
        next_offset: feed.next_offset,
        has_more: feed.has_more,
        update_baseline: feed.update_baseline,
        update_num: feed.update_num,
    })
}

fn require_main(app: &CoreApp) -> Result<auth::Account, AppError> {
    let reg = app.accounts.read();
    reg.account_for(AccountSlot::Main)
        .or_else(|| reg.active_main())
        .cloned()
        .ok_or_else(|| AppError::new(ErrorKind::Unauthenticated, "未登录或登录已失效"))
}
