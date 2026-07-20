//! Video-facing FFI API (detail for P2; playurl later).

use crate::app::CoreApp;
use crate::error::AppError;
use auth::AccountSlot;
use domain::id::VideoId;
use http::VideoApi;

/// One part (分 P) in a multi-part archive.
#[derive(Debug, Clone)]
pub struct VideoPageDto {
    pub cid: i64,
    pub page: i32,
    pub part: String,
    pub duration_ms: i64,
}

/// Archive statistics.
#[derive(Debug, Clone)]
pub struct VideoStatDto {
    pub view: i64,
    pub danmaku: i64,
    pub reply: i64,
    pub favorite: i64,
    pub coin: i64,
    pub share: i64,
    pub like: i64,
}

/// Video detail DTO for Flutter.
#[derive(Debug, Clone)]
pub struct VideoDetailDto {
    pub aid: i64,
    pub bvid: String,
    pub title: String,
    pub cover: String,
    pub desc: String,
    pub owner_mid: i64,
    pub owner_name: String,
    pub owner_face: String,
    pub pages: Vec<VideoPageDto>,
    pub stat: VideoStatDto,
    pub duration_ms: i64,
}

/// Fetch video detail by bvid or aid string (e.g. `BV1…` / `av170001` / `170001`).
pub async fn video_detail(id: String) -> Result<VideoDetailDto, AppError> {
    let app = CoreApp::global()?;
    let video_id = VideoId::parse(&id).map_err(AppError::from)?;

    let buvid = app.store.buvid3();
    let account = {
        let reg = app.accounts.read();
        reg.account_for(AccountSlot::Video)
            .or_else(|| reg.active_main())
            .cloned()
    };

    let detail = VideoApi::detail(
        &app.http,
        account.as_ref(),
        Some(buvid.as_str()),
        &video_id,
    )
    .await?;

    Ok(VideoDetailDto {
        aid: detail.aid,
        bvid: detail.bvid,
        title: detail.title,
        cover: detail.cover,
        desc: detail.desc,
        owner_mid: detail.owner.mid.get(),
        owner_name: detail.owner.name,
        owner_face: detail.owner.face,
        pages: detail
            .pages
            .into_iter()
            .map(|p| VideoPageDto {
                cid: p.cid.get(),
                page: p.page,
                part: p.part,
                duration_ms: p.duration_ms.get(),
            })
            .collect(),
        stat: VideoStatDto {
            view: detail.stat.view,
            danmaku: detail.stat.danmaku,
            reply: detail.stat.reply,
            favorite: detail.stat.favorite,
            coin: detail.stat.coin,
            share: detail.stat.share,
            like: detail.stat.like,
        },
        duration_ms: detail.duration_ms.get(),
    })
}
