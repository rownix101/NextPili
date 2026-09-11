//! User library FFI API (history · watch-later · favorites read).

use crate::app::CoreApp;
use crate::error::{AppError, ErrorKind};
use auth::AccountSlot;
use http::{MemberApi, UserApi};

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
    /// True when listed with a resource `rid` and that resource is in this folder.
    pub in_folder: bool,
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
///
/// Pass `rid` (aid) > 0 to mark each folder's `in_folder` for that archive.
pub async fn fav_folders(rid: i64) -> Result<FavFolderListDto, AppError> {
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
    let rid_opt = if rid > 0 { Some(rid) } else { None };

    let list =
        UserApi::fav_folders(&http, &account, Some(buvid.as_str()), mid, rid_opt).await?;

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
                in_folder: f.in_folder,
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

/// Public UP profile for the member-space page.
#[derive(Debug, Clone)]
pub struct MemberProfileDto {
    pub mid: i64,
    pub name: String,
    pub face: String,
    pub sign: String,
    pub level: i32,
    pub fans: i64,
    pub following: i64,
    pub likes: i64,
    pub archive_count: i64,
    pub is_following: bool,
    pub is_self: bool,
    pub official_title: String,
    pub official_type: i32,
    pub vip_status: bool,
    pub vip_label: String,
}

/// One UP contribution (archive) row.
#[derive(Debug, Clone)]
pub struct MemberVideoItemDto {
    pub aid: i64,
    pub bvid: String,
    pub cid: i64,
    pub title: String,
    pub cover: String,
    pub duration_ms: i64,
    pub play: i64,
    pub danmaku: i64,
    pub ctime_ms: i64,
    pub author: String,
}

/// Paginated UP contribution page.
#[derive(Debug, Clone)]
pub struct MemberVideoPageDto {
    pub items: Vec<MemberVideoItemDto>,
    /// Pass as `aid` to request the next page; `0` when finished.
    pub next_aid: i64,
    pub has_more: bool,
    pub total: i64,
}

/// Member profile card (`/x/web-interface/card`). Cookie optional.
pub async fn member_profile(mid: i64) -> Result<MemberProfileDto, AppError> {
    let app = CoreApp::global()?;
    let account = optional_main(&app);
    let buvid = app.store.buvid3();
    let http = app.http();
    let profile = MemberApi::profile(&http, account.as_ref(), Some(buvid.as_str()), mid).await?;
    let is_self = account.as_ref().map(|a| a.mid.get()) == Some(mid);

    Ok(MemberProfileDto {
        mid: profile.mid,
        name: profile.name,
        face: profile.face,
        sign: profile.sign,
        level: profile.level,
        fans: profile.fans,
        following: profile.following,
        likes: profile.likes,
        archive_count: profile.archive_count,
        is_following: profile.following_state,
        is_self,
        official_title: profile.official_title,
        official_type: profile.official_type,
        vip_status: profile.vip_status,
        vip_label: profile.vip_label,
    })
}

/// UP contribution list via the App archive cursor.
///
/// First page: `aid = 0`. Subsequent pages: previous `next_aid`.
/// `order`: `pubdate` or `click`.
pub async fn member_videos(
    mid: i64,
    aid: i64,
    order: String,
) -> Result<MemberVideoPageDto, AppError> {
    let app = CoreApp::global()?;
    let account = optional_main(&app);
    let http = app.http();
    let page = MemberApi::archive_cursor(&http, account.as_ref(), mid, aid, &order, 20).await?;

    Ok(MemberVideoPageDto {
        items: page
            .items
            .into_iter()
            .map(|it| MemberVideoItemDto {
                aid: it.aid,
                bvid: it.bvid,
                cid: it.cid,
                title: it.title,
                cover: it.cover,
                duration_ms: it.duration_ms,
                play: it.play,
                danmaku: it.danmaku,
                ctime_ms: it.ctime_ms,
                author: it.author,
            })
            .collect(),
        next_aid: page.next_aid,
        has_more: page.has_more,
        total: page.total,
    })
}

fn optional_main(app: &CoreApp) -> Option<auth::Account> {
    let reg = app.accounts.read();
    reg.account_for(AccountSlot::Main)
        .or_else(|| reg.active_main())
        .cloned()
}
