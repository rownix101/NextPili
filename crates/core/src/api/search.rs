//! Search-facing FFI API (suggest + type=video).

use crate::app::CoreApp;
use crate::error::{AppError, ErrorKind};
use auth::AccountSlot;
use http::{NavApi, SearchApi};

/// Single video hit for search results.
#[derive(Debug, Clone)]
pub struct SearchVideoItemDto {
    pub aid: i64,
    pub bvid: String,
    pub title: String,
    pub cover: String,
    pub owner_name: String,
    pub duration_ms: i64,
    pub play: i64,
}

/// Paginated video search page.
#[derive(Debug, Clone)]
pub struct SearchVideoPageDto {
    pub items: Vec<SearchVideoItemDto>,
    pub page: i32,
    pub num_pages: i32,
    pub num_results: i64,
}

/// Typeahead suggestions.
#[derive(Debug, Clone)]
pub struct SearchSuggestDto {
    pub terms: Vec<String>,
}

/// Search suggestions for `term` (recommend slot when available).
pub async fn search_suggest(term: String) -> Result<SearchSuggestDto, AppError> {
    let app = CoreApp::global()?;
    let buvid = app.store.buvid3();
    let account = {
        let reg = app.accounts.read();
        reg.account_for(AccountSlot::Recommend)
            .or_else(|| reg.active_main())
            .cloned()
    };

    let http = app.http();
    let out = SearchApi::suggest(
        &http,
        account.as_ref(),
        Some(buvid.as_str()),
        &term,
    )
    .await?;

    Ok(SearchSuggestDto { terms: out.terms })
}

/// Classification search: `search_type=video` (WBI · recommend slot).
///
/// `page` starts at 1. Empty keyword → `InvalidArgument`.
pub async fn search_video(keyword: String, page: i32) -> Result<SearchVideoPageDto, AppError> {
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

    let page = SearchApi::search_video(
        &http,
        account.as_ref(),
        Some(buvid.as_str()),
        &wbi,
        &keyword,
        page,
    )
    .await?;

    Ok(SearchVideoPageDto {
        items: page
            .items
            .into_iter()
            .map(|it| SearchVideoItemDto {
                aid: it.aid,
                bvid: it.bvid,
                title: it.title,
                cover: it.cover,
                owner_name: it.owner_name,
                duration_ms: it.duration_ms.get(),
                play: it.play,
            })
            .collect(),
        page: page.page,
        num_pages: page.num_pages,
        num_results: page.num_results,
    })
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
