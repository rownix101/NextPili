//! Social FFI API (replies + danmaku read/write).

use crate::app::CoreApp;
use crate::error::{AppError, ErrorKind};
use auth::AccountSlot;
use http::{DanmakuApi, NavApi, ReplyApi};
use media::{limit_danmaku, merge_duplicate_danmaku, parse_dm_seg_so};

/// One comment for Flutter lists.
#[derive(Debug, Clone)]
pub struct ReplyDto {
    pub rpid: i64,
    pub mid: i64,
    pub uname: String,
    pub avatar: String,
    pub content: String,
    pub ctime_ms: i64,
    pub like: i64,
    pub children_count: i32,
}

/// Paginated main-floor reply list.
#[derive(Debug, Clone)]
pub struct ReplyListDto {
    pub replies: Vec<ReplyDto>,
    /// Pass as `next_offset` on the next call; empty when finished.
    pub next_offset: String,
    pub is_end: bool,
    pub all_count: i64,
}

/// Single danmaku item on the player timeline.
#[derive(Debug, Clone)]
pub struct DanmakuItemDto {
    pub id: i64,
    pub progress_ms: i64,
    pub mode: i32,
    pub fontsize: i32,
    pub color: u32,
    pub text: String,
    pub mid_hash: String,
}

/// Segment payload (one ~6 min window).
#[derive(Debug, Clone)]
pub struct DanmakuSegmentDto {
    pub segment_index: u32,
    pub items: Vec<DanmakuItemDto>,
}

/// Main-floor comment list (REST `/x/v2/reply/main`).
///
/// - `oid`: video **aid**
/// - `type_`: subject type (`0` → video `1`)
/// - `mode`: `0` → heat `3`; `2` time; `3` heat
/// - `next_offset`: empty for first page
pub async fn reply_list(
    oid: i64,
    type_: i32,
    mode: i32,
    next_offset: String,
) -> Result<ReplyListDto, AppError> {
    let app = CoreApp::global()?;
    let buvid = app.store.buvid3();
    let account = {
        let reg = app.accounts.read();
        reg.account_for(AccountSlot::Video)
            .or_else(|| reg.active_main())
            .cloned()
    };

    let http = app.http();
    let page = ReplyApi::main_list(
        &http,
        account.as_ref(),
        Some(buvid.as_str()),
        oid,
        type_,
        mode,
        &next_offset,
    )
    .await?;

    Ok(ReplyListDto {
        replies: page
            .replies
            .into_iter()
            .map(|r| ReplyDto {
                rpid: r.rpid,
                mid: r.mid.get(),
                uname: r.uname,
                avatar: r.avatar,
                content: r.content,
                ctime_ms: r.ctime_ms,
                like: r.like,
                children_count: r.children_count,
            })
            .collect(),
        next_offset: page.next_offset,
        is_end: page.is_end,
        all_count: page.all_count,
    })
}

/// One danmaku segment for `cid` (`segment_index` is **1-based**; `0` → `1`).
///
/// Soft-caps to 4000 items per segment for UI performance.
pub async fn danmaku_segments(
    aid: i64,
    cid: i64,
    segment_index: u32,
) -> Result<DanmakuSegmentDto, AppError> {
    let app = CoreApp::global()?;
    if cid <= 0 {
        return Err(AppError::new(ErrorKind::InvalidArgument, "cid must be > 0"));
    }
    let seg = segment_index.max(1);
    let buvid = app.store.buvid3();
    let account = {
        let reg = app.accounts.read();
        reg.account_for(AccountSlot::Video)
            .or_else(|| reg.active_main())
            .cloned()
    };

    let http = app.http();
    let bytes = DanmakuApi::web_seg_bytes(
        &http,
        account.as_ref(),
        Some(buvid.as_str()),
        aid,
        cid,
        seg,
    )
    .await?;

    let items = if bytes.is_empty() {
        Vec::new()
    } else {
        let parsed = parse_dm_seg_so(&bytes)
            .map_err(|e| AppError::new(ErrorKind::Parse, e.to_string()))?;
        // Merge near-duplicate text (PiliPlus mergeDanmaku), then density cap.
        let merged = merge_duplicate_danmaku(parsed);
        limit_danmaku(merged, 4000)
    };

    Ok(DanmakuSegmentDto {
        segment_index: seg,
        items: items
            .into_iter()
            .map(|d| DanmakuItemDto {
                id: d.id,
                progress_ms: d.progress_ms,
                mode: d.mode,
                fontsize: d.fontsize,
                color: d.color,
                text: d.text,
                mid_hash: d.mid_hash,
            })
            .collect(),
    })
}

/// Post a main-floor comment (or nested when `root`/`parent` > 0).
///
/// Requires login. `oid` is video **aid** for `type_=1`.
pub async fn reply_add(
    oid: i64,
    type_: i32,
    message: String,
    root: i64,
    parent: i64,
) -> Result<ReplyDto, AppError> {
    let app = CoreApp::global()?;
    let account = require_main(&app)?;
    let buvid = app.store.buvid3();
    let http = app.http();
    let result = ReplyApi::add(
        &http,
        &account,
        Some(buvid.as_str()),
        oid,
        type_,
        &message,
        root,
        parent,
    )
    .await?;

    if let Some(r) = result.reply {
        return Ok(ReplyDto {
            rpid: r.rpid,
            mid: r.mid.get(),
            uname: r.uname,
            avatar: r.avatar,
            content: r.content,
            ctime_ms: r.ctime_ms,
            like: r.like,
            children_count: r.children_count,
        });
    }

    // API sometimes omits nested `reply`; synthesize for optimistic UI.
    Ok(ReplyDto {
        rpid: result.rpid,
        mid: account.mid.get(),
        uname: account.name.clone(),
        avatar: account.face.clone(),
        content: message.trim().to_string(),
        ctime_ms: 0,
        like: 0,
        children_count: 0,
    })
}

/// Post a video danmaku at `progress_ms` (Cookie + WBI).
///
/// - `oid`: **cid**
/// - `mode`: 0/1 scroll · 4 bottom · 5 top
/// - `color`: 0 → white
pub async fn danmaku_post(
    oid: i64,
    aid: i64,
    bvid: String,
    msg: String,
    progress_ms: i64,
    mode: i32,
    color: u32,
) -> Result<DanmakuItemDto, AppError> {
    let app = CoreApp::global()?;
    let account = require_main(&app)?;
    ensure_wbi(&app).await?;
    let buvid = app.store.buvid3();
    let wbi = app.wbi.read().clone();
    let http = app.http();
    let result = DanmakuApi::post(
        &http,
        &account,
        Some(buvid.as_str()),
        &wbi,
        oid,
        aid,
        &bvid,
        &msg,
        progress_ms,
        mode,
        color,
        25,
    )
    .await?;

    Ok(DanmakuItemDto {
        id: result.dmid,
        progress_ms: progress_ms.max(0),
        mode: if mode == 0 { 1 } else { mode },
        fontsize: 25,
        color: if color == 0 { 16_777_215 } else { color },
        text: msg.trim().to_string(),
        mid_hash: String::new(),
    })
}

/// Like / unlike a video danmaku (`POST /x/v2/dm/thumbup/add`).
///
/// - `oid`: **cid**
/// - `dmid`: danmaku id
/// - `like`: `true` 赞 · `false` 取消
pub async fn danmaku_like(oid: i64, dmid: i64, like: bool) -> Result<(), AppError> {
    let app = CoreApp::global()?;
    let account = require_main(&app)?;
    let buvid = app.store.buvid3();
    let http = app.http();
    DanmakuApi::like(
        &http,
        &account,
        Some(buvid.as_str()),
        oid,
        dmid,
        like,
    )
    .await?;
    Ok(())
}

/// Report a video danmaku (`POST /x/dm/report/add`).
///
/// - `cid`: part cid
/// - `dmid`: danmaku id
/// - `reason`: report reason code (0 → server `11` “其它” with optional `content`)
/// - `block_user`: also request block
/// - `content`: free text when reason is other
///
/// Returns server `data.block` business code (0 = submitted).
pub async fn danmaku_report(
    cid: i64,
    dmid: i64,
    reason: i32,
    block_user: bool,
    content: String,
) -> Result<i32, AppError> {
    let app = CoreApp::global()?;
    let account = require_main(&app)?;
    let buvid = app.store.buvid3();
    let http = app.http();
    // PiliPlus: reasonType 0 maps to API reason 11 (“其它”).
    let api_reason = if reason == 0 { 11 } else { reason };
    let content_opt = if content.trim().is_empty() {
        None
    } else {
        Some(content.as_str())
    };
    let code = DanmakuApi::report(
        &http,
        &account,
        Some(buvid.as_str()),
        cid,
        dmid,
        api_reason,
        block_user,
        content_opt,
    )
    .await?;
    Ok(code)
}

fn require_main(app: &CoreApp) -> Result<auth::Account, AppError> {
    let reg = app.accounts.read();
    reg.account_for(AccountSlot::Main)
        .or_else(|| reg.active_main())
        .cloned()
        .ok_or_else(|| AppError::new(ErrorKind::Unauthenticated, "未登录或登录已失效"))
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
