//! Social read-only FFI API (replies + danmaku).

use crate::app::CoreApp;
use crate::error::{AppError, ErrorKind};
use auth::AccountSlot;
use http::{DanmakuApi, ReplyApi};
use media::{limit_danmaku, parse_dm_seg_so};

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
        limit_danmaku(parsed, 4000)
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
