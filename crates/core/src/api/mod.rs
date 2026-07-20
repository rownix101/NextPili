//! Public FFI API surface (hand-written; FRB generates bindings from these).

pub mod auth;
pub mod dynamics;
pub mod engagement;
pub mod feed;
pub mod live;
pub mod pgc;
pub mod search;
pub mod settings;
pub mod simple;
pub mod social;
pub mod user;
pub mod video;

pub use auth::{
    device_buvid3, list_accounts, login_captcha, login_password, login_password_risk_captcha,
    login_password_risk_send_sms, login_password_risk_verify, login_qr_poll, login_qr_start,
    login_sms, login_sms_send, logout, new_login_session_id, set_account_slot, AccountPublicDto,
    CaptchaDto, PasswordLoginDto, PasswordLoginResultDto, PasswordLoginResultKind, PasswordRiskDto,
    PasswordRiskSendSmsDto, PasswordRiskSendSmsResultDto, PasswordRiskVerifyDto, QrPollDto,
    QrStartDto, QrStatusKind, SlotDto, SmsLoginDto, SmsSendDto, SmsSendDtoResult,
};
pub use dynamics::{dynamics_feed, DynamicItemDto, DynamicPageDto};
pub use engagement::{
    relation_follow, video_coin, video_favorite, video_favorite_deal, video_like, video_relation,
    ArchiveRelationDto,
};
pub use feed::{
    feed_popular, feed_recommend, FeedItemDto, PopularFeedDto, RecommendFeedDto,
};
pub use live::{
    live_dm_history, live_play_url, live_recommend, live_room, live_send_msg, LiveDanmakuItemDto,
    LiveRecommendPageDto, LiveRoomCardDto, LiveRoomDto,
};
pub use pgc::{
    pgc_play_url, pgc_rank, pgc_season, PgcEpisodeDto, PgcRankItemDto, PgcRankPageDto, PgcSeasonDto,
};
pub use search::{
    search_suggest, search_video, SearchSuggestDto, SearchVideoItemDto, SearchVideoPageDto,
};
pub use settings::{get_settings, update_settings, SettingsDto};
pub use simple::{api_version, bootstrap, ping, ApiVersion, BootstrapConfig};
pub use social::{
    danmaku_post, danmaku_segments, reply_add, reply_list, DanmakuItemDto, DanmakuSegmentDto,
    ReplyDto, ReplyListDto,
};
pub use user::{
    fav_folders, fav_resources, history_list, toview_list, FavFolderDto, FavFolderListDto,
    FavResourceItemDto, FavResourcePageDto, HistoryItemDto, HistoryPageDto, ToViewItemDto,
    ToViewPageDto,
};
pub use video::{
    play_url, playback_start, playback_stop, subtitle_vtt, video_detail, HeaderDto, MediaFormatDto,
    MediaSourceDto, StreamDto, SubtitleTrackDto, VideoDetailDto, VideoPageDto, VideoStatDto,
};
