//! PGC (bangumi) FFI: rank · season · playurl.

use crate::api::video::{HeaderDto, MediaFormatDto, MediaSourceDto, StreamDto, SubtitleTrackDto};
use crate::app::CoreApp;
use crate::error::{AppError, ErrorKind};
use auth::AccountSlot;
use domain::id::Cid;
use http::{NavApi, PgcApi, PgcPlayUrlParams, PLAYURL_FNVAL_DASH};
use media::{MediaFormat, MediaSource};

/// Rank list card.
#[derive(Debug, Clone)]
pub struct PgcRankItemDto {
    pub season_id: i64,
    pub title: String,
    pub cover: String,
    pub badge: String,
    pub index_show: String,
    pub rating: String,
    pub order: i32,
}

/// Rank page.
#[derive(Debug, Clone)]
pub struct PgcRankPageDto {
    pub items: Vec<PgcRankItemDto>,
    pub season_type: i32,
    pub note: String,
}

/// Episode row.
#[derive(Debug, Clone)]
pub struct PgcEpisodeDto {
    pub ep_id: i64,
    pub aid: i64,
    pub bvid: String,
    pub cid: i64,
    pub title: String,
    pub long_title: String,
    pub cover: String,
    pub duration_ms: i64,
    pub badge: String,
}

/// Season detail.
#[derive(Debug, Clone)]
pub struct PgcSeasonDto {
    pub season_id: i64,
    pub season_title: String,
    pub title: String,
    pub cover: String,
    pub evaluate: String,
    pub season_type: i32,
    pub type_name: String,
    pub rating_score: String,
    pub episodes: Vec<PgcEpisodeDto>,
    pub default_ep_id: i64,
}

/// PGC web rank (`/pgc/web/rank/list`, WBI).
///
/// `season_type`: 1 番剧 · 2 电影 · 3 纪录片 · 4 国创 · 5 电视剧 · 7 综艺.
/// `day`: 3 | 7 (0 → 3).
pub async fn pgc_rank(season_type: i32, day: i32) -> Result<PgcRankPageDto, AppError> {
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
    let http = app.http();
    let page = PgcApi::rank_list(
        &http,
        account.as_ref(),
        Some(buvid.as_str()),
        &wbi,
        season_type,
        day,
    )
    .await?;

    Ok(PgcRankPageDto {
        items: page
            .items
            .into_iter()
            .map(|it| PgcRankItemDto {
                season_id: it.season_id,
                title: it.title,
                cover: it.cover,
                badge: it.badge,
                index_show: it.index_show,
                rating: it.rating,
                order: it.order,
            })
            .collect(),
        season_type: page.season_type,
        note: page.note,
    })
}

/// Season detail by `season_id` and/or `ep_id` (at least one > 0).
pub async fn pgc_season(season_id: i64, ep_id: i64) -> Result<PgcSeasonDto, AppError> {
    if season_id <= 0 && ep_id <= 0 {
        return Err(AppError::new(
            ErrorKind::InvalidArgument,
            "season_id or ep_id required",
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
    let s = PgcApi::season(
        &http,
        account.as_ref(),
        Some(buvid.as_str()),
        season_id,
        ep_id,
    )
    .await?;

    Ok(PgcSeasonDto {
        season_id: s.season_id,
        season_title: s.season_title,
        title: s.title,
        cover: s.cover,
        evaluate: s.evaluate,
        season_type: s.season_type,
        type_name: s.type_name,
        rating_score: s.rating_score,
        episodes: s
            .episodes
            .into_iter()
            .map(|e| PgcEpisodeDto {
                ep_id: e.ep_id,
                aid: e.aid,
                bvid: e.bvid,
                cid: e.cid,
                title: e.title,
                long_title: e.long_title,
                cover: e.cover,
                duration_ms: e.duration_ms.get(),
                badge: e.badge,
            })
            .collect(),
        default_ep_id: s.default_ep_id,
    })
}

/// PGC playurl → [`MediaSourceDto`].
///
/// - `ep_id`: episode id
/// - `cid`: episode cid
/// - `qn`: preferred quality (0 = store preferred / 80)
/// - `fnval`: dash mask (0 = default)
pub async fn pgc_play_url(
    ep_id: i64,
    cid: i64,
    qn: u32,
    fnval: u32,
) -> Result<MediaSourceDto, AppError> {
    if ep_id <= 0 {
        return Err(AppError::new(ErrorKind::InvalidArgument, "ep_id must be > 0"));
    }
    let app = CoreApp::global()?;
    let cid = Cid::new(cid).map_err(AppError::from)?;

    let preferred = if qn == 0 {
        let q = app.store.settings().preferred_qn;
        if q == 0 {
            80
        } else {
            q
        }
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
    let http = app.http();
    let data = PgcApi::play_url(
        &http,
        account.as_ref(),
        Some(buvid.as_str()),
        &PgcPlayUrlParams {
            ep_id,
            cid,
            qn: preferred,
            fnval,
        },
    )
    .await?;

    let source = app
        .media
        .parse_playurl_data(cid, &data, Some(preferred))
        .map_err(|e| AppError::new(ErrorKind::Parse, e.to_string()))?;

    let aid = data
        .get("aid")
        .and_then(|v| v.as_i64())
        .or_else(|| data.get("avid").and_then(|v| v.as_i64()))
        .unwrap_or(0);
    let bvid = data
        .get("bvid")
        .and_then(|v| v.as_str())
        .unwrap_or("")
        .to_string();

    Ok(map_source(aid, bvid, source))
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
