//! Watch-page engagement FFI (relation · like · coin · fav · follow).

use crate::app::CoreApp;
use crate::error::{AppError, ErrorKind};
use auth::AccountSlot;
use domain::default_fav_folder_id;
use http::{EngagementApi, UserApi};

/// Viewer relationship to an archive (+ follow flag for its UP).
#[derive(Debug, Clone)]
pub struct ArchiveRelationDto {
    pub liked: bool,
    pub disliked: bool,
    /// Coins already cast (0..=2).
    pub coin: i32,
    pub favorited: bool,
    pub following: bool,
}

/// Current engagement flags. Requires login; empty defaults when unauthenticated.
pub async fn video_relation(aid: i64, bvid: String) -> Result<ArchiveRelationDto, AppError> {
    let app = CoreApp::global()?;
    let Some(account) = main_account(&app) else {
        return Ok(ArchiveRelationDto::default_empty());
    };
    let buvid = app.store.buvid3();
    let http = app.http();
    let rel = EngagementApi::archive_relation(
        &http,
        &account,
        Some(buvid.as_str()),
        aid,
        &bvid,
    )
    .await?;
    Ok(rel.into())
}

/// Toggle like. `like=true` 点赞, `false` 取消.
pub async fn video_like(aid: i64, bvid: String, like: bool) -> Result<ArchiveRelationDto, AppError> {
    let app = CoreApp::global()?;
    let account = require_main(&app)?;
    let buvid = app.store.buvid3();
    let http = app.http();
    EngagementApi::archive_like(
        &http,
        &account,
        Some(buvid.as_str()),
        aid,
        like,
        &bvid,
    )
    .await?;
    let mut rel = refresh_relation_soft(&http, &account, buvid.as_str(), aid, &bvid).await;
    rel.liked = like;
    if like {
        rel.disliked = false;
    }
    Ok(rel)
}

/// Cast coins. `multiply` clamped to 1..=2. Optionally like at the same time.
pub async fn video_coin(
    aid: i64,
    bvid: String,
    multiply: i32,
    also_like: bool,
) -> Result<ArchiveRelationDto, AppError> {
    let app = CoreApp::global()?;
    let account = require_main(&app)?;
    let buvid = app.store.buvid3();
    let http = app.http();
    EngagementApi::archive_coin(
        &http,
        &account,
        Some(buvid.as_str()),
        aid,
        multiply,
        also_like,
        &bvid,
    )
    .await?;
    let mut rel = refresh_relation_soft(&http, &account, buvid.as_str(), aid, &bvid).await;
    if rel.coin < multiply {
        rel.coin = multiply.clamp(1, 2);
    }
    if also_like {
        rel.liked = true;
        rel.disliked = false;
    }
    Ok(rel)
}

/// Favorite into the default folder, or unfav-all when `favorite=false`.
pub async fn video_favorite(
    aid: i64,
    bvid: String,
    favorite: bool,
) -> Result<ArchiveRelationDto, AppError> {
    let app = CoreApp::global()?;
    let account = require_main(&app)?;
    let buvid = app.store.buvid3();
    let http = app.http();
    let mid = account.mid;

    if favorite {
        let folders =
            UserApi::fav_folders(&http, &account, Some(buvid.as_str()), mid.get(), None).await?;
        let pairs: Vec<(i64, i32)> = folders
            .folders
            .iter()
            .map(|f| (f.id, f.attr))
            .collect();
        let folder_id = default_fav_folder_id(&pairs).ok_or_else(|| {
            AppError::new(ErrorKind::InvalidArgument, "没有可用的收藏夹")
        })?;
        EngagementApi::fav_resource_deal(
            &http,
            &account,
            Some(buvid.as_str()),
            aid,
            &folder_id.to_string(),
            "",
        )
        .await?;
    } else {
        EngagementApi::fav_resource_unfav_all(&http, &account, Some(buvid.as_str()), aid)
            .await?;
    }

    // Relation refresh may lag; synthesize fav bit if needed.
    let mut rel = refresh_relation_soft(&http, &account, buvid.as_str(), aid, &bvid).await;
    rel.favorited = favorite;
    Ok(rel)
}

/// Add / remove an archive from specific favorite folders (`media_id`s).
///
/// Empty both lists is an error. Prefer this for multi-folder picker; short-press
/// toggle still uses [`video_favorite`].
pub async fn video_favorite_deal(
    aid: i64,
    bvid: String,
    add_media_ids: Vec<i64>,
    del_media_ids: Vec<i64>,
) -> Result<ArchiveRelationDto, AppError> {
    let app = CoreApp::global()?;
    let account = require_main(&app)?;
    let buvid = app.store.buvid3();
    let http = app.http();

    let add: Vec<String> = add_media_ids
        .into_iter()
        .filter(|id| *id > 0)
        .map(|id| id.to_string())
        .collect();
    let del: Vec<String> = del_media_ids
        .into_iter()
        .filter(|id| *id > 0)
        .map(|id| id.to_string())
        .collect();
    if add.is_empty() && del.is_empty() {
        return Err(AppError::new(
            ErrorKind::InvalidArgument,
            "请选择要加入或移出的收藏夹",
        ));
    }

    EngagementApi::fav_resource_deal(
        &http,
        &account,
        Some(buvid.as_str()),
        aid,
        &add.join(","),
        &del.join(","),
    )
    .await?;

    let mut rel = refresh_relation_soft(&http, &account, buvid.as_str(), aid, &bvid).await;
    if !add.is_empty() {
        rel.favorited = true;
    }
    Ok(rel)
}

/// Follow / unfollow UP (`mid`).
pub async fn relation_follow(mid: i64, follow: bool) -> Result<(), AppError> {
    let app = CoreApp::global()?;
    let account = require_main(&app)?;
    let buvid = app.store.buvid3();
    let http = app.http();
    EngagementApi::relation_modify(&http, &account, Some(buvid.as_str()), mid, follow).await?;
    Ok(())
}

impl ArchiveRelationDto {
    fn default_empty() -> Self {
        Self {
            liked: false,
            disliked: false,
            coin: 0,
            favorited: false,
            following: false,
        }
    }
}

impl From<domain::ArchiveRelation> for ArchiveRelationDto {
    fn from(r: domain::ArchiveRelation) -> Self {
        Self {
            liked: r.liked,
            disliked: r.disliked,
            coin: r.coin,
            favorited: r.favorited,
            following: r.following,
        }
    }
}

async fn refresh_relation_soft(
    http: &http::BiliClient,
    account: &auth::Account,
    buvid: &str,
    aid: i64,
    bvid: &str,
) -> ArchiveRelationDto {
    match EngagementApi::archive_relation(http, account, Some(buvid), aid, bvid).await {
        Ok(rel) => rel.into(),
        Err(_) => ArchiveRelationDto::default_empty(),
    }
}

fn main_account(app: &CoreApp) -> Option<auth::Account> {
    let reg = app.accounts.read();
    reg.account_for(AccountSlot::Main)
        .or_else(|| reg.active_main())
        .cloned()
}

fn require_main(app: &CoreApp) -> Result<auth::Account, AppError> {
    main_account(app)
        .ok_or_else(|| AppError::new(ErrorKind::Unauthenticated, "未登录或登录已失效"))
}
