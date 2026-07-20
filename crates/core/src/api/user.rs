//! User library FFI API (history · watch-later · favorites read).

use crate::app::CoreApp;
use crate::error::{AppError, ErrorKind};
use auth::AccountSlot;
use http::UserApi;

/// Watch-history row.
#[derive(Debug, Clone)]
pub struct HistoryItemDto {
    pub aid: i64,
    pub bvid: String,
    pub cid: i64,
    pub title: String,
    pub cover: String,
    pub owner_name: String,
    pub duration_ms: i64,
    pub progress_ms: i64,
    pub view_at_ms: i64,
    pub business: String,
    pub kid: i64,
    pub show_title: String,
}

/// History cursor page.
#[derive(Debug, Clone)]
pub struct HistoryPageDto {
    pub items: Vec<HistoryItemDto>,
    pub next_max: i64,
    pub next_view_at: i64,
    pub next_business: String,
    pub has_more: bool,
}

/// Watch-later row.
#[derive(Debug, Clone)]
pub struct ToViewItemDto {
    pub aid: i64,
    pub bvid: String,
    pub cid: i64,
    pub title: String,
    pub cover: String,
    pub owner_name: String,
    pub duration_ms: i64,
    pub progress_ms: i64,
    pub add_at_ms: i64,
}

/// Watch-later page.
#[derive(Debug, Clone)]
pub struct ToViewPageDto {
    pub items: Vec<ToViewItemDto>,
    pub count: i32,
    pub pn: i32,
    pub has_more: bool,
}

/// Favorite folder.
#[derive(Debug, Clone)]
pub struct FavFolderDto {
    pub id: i64,
    pub title: String,
    pub media_count: i32,
    pub cover: String,
    pub attr: i32,
}

/// Created folders list.
#[derive(Debug, Clone)]
pub struct FavFolderListDto {
    pub folders: Vec<FavFolderDto>,
    pub count: i32,
}

/// Media inside a favorite folder.
#[derive(Debug, Clone)]
pub struct FavResourceItemDto {
    pub aid: i64,
    pub bvid: String,
    pub title: String,
    pub cover: String,
    pub owner_name: String,
    pub duration_ms: i64,
    pub fav_time_ms: i64,
}

/// Folder contents page.
#[derive(Debug, Clone)]
pub struct FavResourcePageDto {
    pub items: Vec<FavResourceItemDto>,
    pub media_id: i64,
    pub pn: i32,
    pub has_more: bool,
}

/// Watch history (main slot · Cookie). Cursor IFS: first call `max=0, view_at=0, business=""`.
///
/// `ps` defaults to 20 when 0.
pub async fn history_list(
    max: i64,
    view_at: i64,
    business: String,
    ps: u32,
) -> Result<HistoryPageDto, AppError> {
    let app = CoreApp::global()?;
    let account = require_main(&app)?;
    let buvid = app.store.buvid3();
    let page_size = if ps == 0 { 20 } else { ps };
    let http = app.http();

    let page = UserApi::history_cursor(
        &http,
        &account,
        Some(buvid.as_str()),
        max,
        view_at,
        &business,
        page_size,
    )
    .await?;

    Ok(HistoryPageDto {
        items: page
            .items
            .into_iter()
            .map(|it| HistoryItemDto {
                aid: it.aid,
                bvid: it.bvid,
                cid: it.cid,
                title: it.title,
                cover: it.cover,
                owner_name: it.owner_name,
                duration_ms: it.duration_ms.get(),
                progress_ms: it.progress_ms,
                view_at_ms: it.view_at_ms,
                business: it.business,
                kid: it.kid,
                show_title: it.show_title,
            })
            .collect(),
        next_max: page.next_max,
        next_view_at: page.next_view_at,
        next_business: page.next_business,
        has_more: page.has_more,
    })
}

/// Watch-later list. `pn` starts at 1; `ps` default 20.
pub async fn toview_list(pn: i32, ps: u32) -> Result<ToViewPageDto, AppError> {
    let app = CoreApp::global()?;
    let account = require_main(&app)?;
    let buvid = app.store.buvid3();
    let page_size = if ps == 0 { 20 } else { ps };
    let http = app.http();

    let page = UserApi::toview_web(
        &http,
        &account,
        Some(buvid.as_str()),
        pn,
        page_size,
    )
    .await?;

    Ok(ToViewPageDto {
        items: page
            .items
            .into_iter()
            .map(|it| ToViewItemDto {
                aid: it.aid,
                bvid: it.bvid,
                cid: it.cid,
                title: it.title,
                cover: it.cover,
                owner_name: it.owner_name,
                duration_ms: it.duration_ms.get(),
                progress_ms: it.progress_ms,
                add_at_ms: it.add_at_ms,
            })
            .collect(),
        count: page.count,
        pn: page.pn,
        has_more: page.has_more,
    })
}

/// Favorite folders created by the signed-in user.
pub async fn fav_folders() -> Result<FavFolderListDto, AppError> {
    let app = CoreApp::global()?;
    let account = require_main(&app)?;
    let mid = account.mid.get();
    if mid <= 0 {
        return Err(AppError::new(
            ErrorKind::Unauthenticated,
            "未登录或登录已失效",
        ));
    }
    let buvid = app.store.buvid3();
    let http = app.http();

    let list = UserApi::fav_folders(&http, &account, Some(buvid.as_str()), mid).await?;

    Ok(FavFolderListDto {
        folders: list
            .folders
            .into_iter()
            .map(|f| FavFolderDto {
                id: f.id,
                title: f.title,
                media_count: f.media_count,
                cover: f.cover,
                attr: f.attr,
            })
            .collect(),
        count: list.count,
    })
}

/// Resources in a favorite folder. `pn` starts at 1; `ps` default 20.
pub async fn fav_resources(
    media_id: i64,
    pn: i32,
    ps: u32,
) -> Result<FavResourcePageDto, AppError> {
    let app = CoreApp::global()?;
    let account = require_main(&app)?;
    let buvid = app.store.buvid3();
    let page_size = if ps == 0 { 20 } else { ps };
    let http = app.http();

    let page = UserApi::fav_resources(
        &http,
        &account,
        Some(buvid.as_str()),
        media_id,
        pn,
        page_size,
    )
    .await?;

    Ok(FavResourcePageDto {
        items: page
            .items
            .into_iter()
            .map(|it| FavResourceItemDto {
                aid: it.aid,
                bvid: it.bvid,
                title: it.title,
                cover: it.cover,
                owner_name: it.owner_name,
                duration_ms: it.duration_ms.get(),
                fav_time_ms: it.fav_time_ms,
            })
            .collect(),
        media_id: page.media_id,
        pn: page.pn,
        has_more: page.has_more,
    })
}

fn require_main(app: &CoreApp) -> Result<auth::Account, AppError> {
    let reg = app.accounts.read();
    reg.account_for(AccountSlot::Main)
        .or_else(|| reg.active_main())
        .cloned()
        .ok_or_else(|| AppError::new(ErrorKind::Unauthenticated, "未登录或登录已失效"))
}
