//! Live FFI (recommend + room metadata + playurl + chat).

use crate::api::video::{HeaderDto, MediaFormatDto, MediaSourceDto, StreamDto};
use crate::app::CoreApp;
use crate::error::{AppError, ErrorKind};
use auth::{AccountSlot, UA_WEB};
use http::{LiveApi, NavApi};

/// One live room card for the recommend grid.
#[derive(Debug, Clone)]
pub struct LiveRoomCardDto {
    pub room_id: i64,
    pub uid: i64,
    pub title: String,
    pub uname: String,
    pub face: String,
    pub cover: String,
    pub online: i64,
    pub area_name: String,
}

/// Paginated live recommend page.
#[derive(Debug, Clone)]
pub struct LiveRecommendPageDto {
    pub items: Vec<LiveRoomCardDto>,
    pub page: i32,
    pub has_more: bool,
}

/// Room metadata for the watch page.
#[derive(Debug, Clone)]
pub struct LiveRoomDto {
    pub room_id: i64,
    pub short_id: i64,
    pub uid: i64,
    pub title: String,
    pub cover: String,
    pub uname: String,
    pub face: String,
    pub online: i64,
    /// 0 offline · 1 live · 2 round.
    pub live_status: i32,
    pub area_name: String,
}

/// One live chat line (history REST; WS later).
#[derive(Debug, Clone)]
pub struct LiveDanmakuItemDto {
    pub uid: i64,
    pub uname: String,
    pub text: String,
    pub timeline_ms: i64,
}

/// Web live recommend (`getUserRecommend`). Optional login.
pub async fn live_recommend(page: i32, page_size: u32) -> Result<LiveRecommendPageDto, AppError> {
    let app = CoreApp::global()?;
    let buvid = app.store.buvid3();
    let account = {
        let reg = app.accounts.read();
        reg.account_for(AccountSlot::Main)
            .or_else(|| reg.active_main())
            .cloned()
    };
    let http = app.http();
    let page = if page <= 0 { 1 } else { page };
    let page_size = if page_size == 0 { 20 } else { page_size };

    let feed = LiveApi::recommend(
        &http,
        account.as_ref(),
        Some(buvid.as_str()),
        page,
        page_size,
    )
    .await?;

    Ok(LiveRecommendPageDto {
        items: feed
            .items
            .into_iter()
            .map(|it| LiveRoomCardDto {
                room_id: it.room_id,
                uid: it.uid,
                title: it.title,
                uname: it.uname,
                face: it.face,
                cover: it.cover,
                online: it.online,
                area_name: it.area_name,
            })
            .collect(),
        page: feed.page,
        has_more: feed.has_more,
    })
}

/// Room metadata (`getH5InfoByRoom`). Optional login.
pub async fn live_room(room_id: i64) -> Result<LiveRoomDto, AppError> {
    if room_id <= 0 {
        return Err(AppError::new(
            ErrorKind::InvalidArgument,
            "room_id must be > 0",
        ));
    }
    let app = CoreApp::global()?;
    let buvid = app.store.buvid3();
    let account = {
        let reg = app.accounts.read();
        reg.account_for(AccountSlot::Main)
            .or_else(|| reg.active_main())
            .cloned()
    };
    let http = app.http();
    let info = LiveApi::room_info(&http, account.as_ref(), Some(buvid.as_str()), room_id).await?;

    Ok(LiveRoomDto {
        room_id: info.room_id,
        short_id: info.short_id,
        uid: info.uid,
        title: info.title,
        cover: info.cover,
        uname: info.uname,
        face: info.face,
        online: info.online,
        live_status: info.live_status,
        area_name: info.area_name,
    })
}

/// Resolve live playurl → [`MediaSourceDto`] (segment/muxed FLV or HLS).
///
/// - `room_id`: real room id
/// - `qn`: preferred quality (0 = 原画 10000)
///
/// `MediaSourceDto.cid` carries `room_id`; `aid`/`bvid` are empty.
pub async fn live_play_url(room_id: i64, qn: u32) -> Result<MediaSourceDto, AppError> {
    if room_id <= 0 {
        return Err(AppError::new(
            ErrorKind::InvalidArgument,
            "room_id must be > 0",
        ));
    }
    let app = CoreApp::global()?;
    ensure_wbi(&app).await?;

    let preferred = if qn == 0 { 10000 } else { qn };
    let buvid = app.store.buvid3();
    let account = {
        let reg = app.accounts.read();
        reg.account_for(AccountSlot::Video)
            .or_else(|| reg.active_main())
            .cloned()
    };
    let wbi = app.wbi.read().clone();
    let http = app.http();

    let source = LiveApi::play_url(
        &http,
        account.as_ref(),
        Some(buvid.as_str()),
        &wbi,
        room_id,
        preferred,
    )
    .await?;

    let videos: Vec<StreamDto> = source
        .streams
        .into_iter()
        .map(|s| StreamDto {
            id: s.id,
            codec: s.codec,
            bandwidth: 0,
            width: None,
            height: None,
            fps: None,
            quality_label: s.quality_label,
            qn: Some(s.qn),
            language: None,
            role: Some(format!("{}/{}", s.protocol, s.format)),
            url: s.url,
            backup_urls: s.backup_urls,
        })
        .collect();

    if videos.is_empty() {
        return Err(AppError::new(ErrorKind::NotFound, "无可播放的直播流"));
    }

    let recommended = source.default_stream_id;
    let recommended = if videos.iter().any(|v| v.id == recommended) {
        recommended
    } else {
        videos[0].id.clone()
    };

    Ok(MediaSourceDto {
        aid: 0,
        bvid: String::new(),
        cid: room_id,
        format: MediaFormatDto::Segment,
        videos,
        audios: vec![],
        recommended_video_id: recommended,
        recommended_audio_id: String::new(),
        duration_ms: 0,
        headers: vec![
            HeaderDto {
                key: "Referer".into(),
                value: format!("https://live.bilibili.com/{room_id}"),
            },
            HeaderDto {
                key: "User-Agent".into(),
                value: UA_WEB.into(),
            },
            HeaderDto {
                key: "Origin".into(),
                value: "https://live.bilibili.com".into(),
            },
        ],
        subtitles: vec![],
        requested_qn: source.requested_qn,
    })
}

/// Recent room chat (history REST). Optional login.
pub async fn live_dm_history(room_id: i64) -> Result<Vec<LiveDanmakuItemDto>, AppError> {
    if room_id <= 0 {
        return Err(AppError::new(
            ErrorKind::InvalidArgument,
            "room_id must be > 0",
        ));
    }
    let app = CoreApp::global()?;
    let buvid = app.store.buvid3();
    let account = {
        let reg = app.accounts.read();
        reg.account_for(AccountSlot::Main)
            .or_else(|| reg.active_main())
            .cloned()
    };
    let http = app.http();
    let items =
        LiveApi::dm_history(&http, account.as_ref(), Some(buvid.as_str()), room_id).await?;
    Ok(items
        .into_iter()
        .map(|it| LiveDanmakuItemDto {
            uid: it.uid,
            uname: it.uname,
            text: it.text,
            timeline_ms: it.timeline_ms,
        })
        .collect())
}

/// Send live room danmaku. Requires login.
pub async fn live_send_msg(room_id: i64, msg: String) -> Result<(), AppError> {
    if room_id <= 0 {
        return Err(AppError::new(
            ErrorKind::InvalidArgument,
            "room_id must be > 0",
        ));
    }
    let app = CoreApp::global()?;
    let account = {
        let reg = app.accounts.read();
        reg.account_for(AccountSlot::Main)
            .or_else(|| reg.active_main())
            .cloned()
            .ok_or_else(|| AppError::new(ErrorKind::Unauthenticated, "未登录或登录已失效"))?
    };
    let buvid = app.store.buvid3();
    let http = app.http();
    LiveApi::send_msg(
        &http,
        &account,
        Some(buvid.as_str()),
        room_id,
        &msg,
        16_777_215,
        25,
        1,
    )
    .await?;
    Ok(())
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
