//! Video-facing FFI API (detail + playurl).

use crate::app::CoreApp;
use crate::error::{AppError, ErrorKind};
use auth::AccountSlot;
use domain::id::{Cid, VideoId};
use http::{NavApi, PlayUrlParams, VideoApi, PLAYURL_FNVAL_DASH};
use media::{MediaFormat, MediaSource};

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

/// Single media stream (video or audio).
#[derive(Debug, Clone)]
pub struct StreamDto {
    pub id: String,
    pub codec: String,
    pub bandwidth: u32,
    pub width: Option<u32>,
    pub height: Option<u32>,
    pub fps: Option<u32>,
    pub quality_label: String,
    pub qn: Option<u32>,
    pub language: Option<String>,
    pub role: Option<String>,
    pub url: String,
    pub backup_urls: Vec<String>,
}

/// Subtitle track (placeholder for later).
#[derive(Debug, Clone)]
pub struct SubtitleTrackDto {
    pub id: String,
    pub lang: String,
    pub label: String,
    pub url: String,
}

/// Playable media source for the player adapter.
#[derive(Debug, Clone)]
pub struct MediaSourceDto {
    pub aid: i64,
    pub bvid: String,
    pub cid: i64,
    pub format: MediaFormatDto,
    pub videos: Vec<StreamDto>,
    pub audios: Vec<StreamDto>,
    pub recommended_video_id: String,
    pub recommended_audio_id: String,
    pub duration_ms: i64,
    /// HTTP headers the player must attach (Referer, UA, …).
    pub headers: Vec<HeaderDto>,
    pub subtitles: Vec<SubtitleTrackDto>,
    pub requested_qn: Option<u32>,
}

/// Header key/value pair (FRB-friendly).
#[derive(Debug, Clone)]
pub struct HeaderDto {
    pub key: String,
    pub value: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MediaFormatDto {
    Dash,
    Segment,
    Unknown,
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

    let http = app.http();
    let detail = VideoApi::detail(
        &http,
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

/// Resolve playurl → normalized [`MediaSourceDto`].
///
/// - `id`: bvid / aid string
/// - `cid`: part cid
/// - `qn`: preferred quality (0 = use store preferred_qn)
/// - `fnval`: dash mask (0 = default full dash)
pub async fn play_url(
    id: String,
    cid: i64,
    qn: u32,
    fnval: u32,
) -> Result<MediaSourceDto, AppError> {
    let app = CoreApp::global()?;
    let video_id = VideoId::parse(&id).map_err(AppError::from)?;
    let cid = Cid::new(cid).map_err(AppError::from)?;

    ensure_wbi(&app).await?;

    let preferred = if qn == 0 {
        app.store.settings().preferred_qn
    } else {
        qn
    };
    let fnval = if fnval == 0 {
        PLAYURL_FNVAL_DASH
    } else {
        fnval
    };

    let buvid = app.store.buvid3();
    let account = {
        let reg = app.accounts.read();
        reg.account_for(AccountSlot::Video)
            .or_else(|| reg.active_main())
            .cloned()
    };
    let wbi = app.wbi.read().clone();

    let http = app.http();
    let data = VideoApi::play_url(
        &http,
        account.as_ref(),
        Some(buvid.as_str()),
        &wbi,
        PlayUrlParams {
            id: &video_id,
            cid,
            qn: preferred,
            fnval,
            cur_language: None,
        },
    )
    .await?;

    let source = app
        .media
        .parse_playurl_data(cid, &data, Some(preferred))
        .map_err(|e| AppError::new(ErrorKind::Parse, e.to_string()))?;

    // Prefer ids from playurl payload when present; fall back to request.
    let aid_from_req = match &video_id {
        VideoId::Aid(a) => *a,
        VideoId::Bvid(_) => 0,
    };
    let aid = data
        .get("aid")
        .and_then(|v| v.as_i64())
        .or_else(|| data.get("avid").and_then(|v| v.as_i64()))
        .unwrap_or(aid_from_req);
    let bvid = data
        .get("bvid")
        .and_then(|v| v.as_str())
        .map(str::to_string)
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| match &video_id {
            VideoId::Bvid(b) => b.clone(),
            VideoId::Aid(_) => String::new(),
        });

    Ok(map_source(aid, bvid, source))
}

/// Start playback heartbeat for (aid, bvid, cid). Replaces any previous session.
pub async fn playback_start(aid: i64, bvid: String, cid: i64) -> Result<(), AppError> {
    let app = CoreApp::global()?;
    if cid <= 0 {
        return Err(AppError::new(ErrorKind::InvalidArgument, "cid must be > 0"));
    }
    let buvid = app.store.buvid3();
    let account = {
        let reg = app.accounts.read();
        reg.account_for(AccountSlot::Heartbeat)
            .or_else(|| reg.active_main())
            .cloned()
    };
    app.heartbeat.start(
        app.http(),
        account,
        buvid,
        crate::heartbeat::PlayContext { aid, bvid, cid },
    );
    Ok(())
}

/// Stop playback heartbeat.
#[flutter_rust_bridge::frb(sync)]
pub fn playback_stop() -> Result<(), AppError> {
    let app = CoreApp::global()?;
    app.heartbeat.stop();
    Ok(())
}

fn map_source(aid: i64, bvid: String, s: MediaSource) -> MediaSourceDto {
    MediaSourceDto {
        aid,
        bvid,
        cid: s.cid.get(),
        format: match s.format {
            MediaFormat::Dash => MediaFormatDto::Dash,
            MediaFormat::Segment => MediaFormatDto::Segment,
            MediaFormat::Unknown => MediaFormatDto::Unknown,
        },
        videos: s.video_streams.into_iter().map(map_stream).collect(),
        audios: s.audio_streams.into_iter().map(map_stream).collect(),
        recommended_video_id: s.default_video,
        recommended_audio_id: s.default_audio,
        duration_ms: s.duration_ms,
        headers: s
            .headers
            .into_iter()
            .map(|(key, value)| HeaderDto { key, value })
            .collect(),
        subtitles: s
            .subtitles
            .into_iter()
            .map(|t| SubtitleTrackDto {
                id: t.id,
                lang: t.lang,
                label: t.label,
                url: t.url,
            })
            .collect(),
        requested_qn: s.requested_qn,
    }
}

fn map_stream(s: media::Stream) -> StreamDto {
    StreamDto {
        id: s.id,
        codec: s.codec,
        bandwidth: s.bandwidth,
        width: s.width,
        height: s.height,
        fps: s.fps,
        quality_label: s.quality_label,
        qn: s.qn,
        language: s.language,
        role: s.role,
        url: s.url,
        backup_urls: s.backup_urls,
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
