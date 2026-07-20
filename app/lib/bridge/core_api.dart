import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../l10n/app_localizations.dart';
import 'frb/api/auth.dart' as frb_auth;
import 'frb/api/dynamics.dart' as frb_dynamics;
import 'frb/api/engagement.dart' as frb_engagement;
import 'frb/api/feed.dart' as frb_feed;
import 'frb/api/search.dart' as frb_search;
import 'frb/api/settings.dart' as frb_settings;
import 'frb/api/simple.dart' as frb;
import 'frb/api/social.dart' as frb_social;
import 'frb/api/user.dart' as frb_user;
import 'frb/api/video.dart' as frb_video;
import 'frb/auth_service.dart';
import 'frb/error.dart';
import 'frb/frb_generated.dart';

export 'frb/api/simple.dart' show ApiVersion, BootstrapConfig;
export 'frb/api/dynamics.dart' show DynamicItemDto, DynamicPageDto;
export 'frb/api/feed.dart'
    show FeedItemDto, PopularFeedDto, RecommendFeedDto;
export 'frb/api/search.dart'
    show SearchSuggestDto, SearchVideoItemDto, SearchVideoPageDto;
export 'frb/api/settings.dart' show SettingsDto;
export 'frb/api/engagement.dart' show ArchiveRelationDto;
export 'frb/api/social.dart'
    show DanmakuItemDto, DanmakuSegmentDto, ReplyDto, ReplyListDto;
export 'frb/api/user.dart'
    show
        FavFolderDto,
        FavFolderListDto,
        FavResourceItemDto,
        FavResourcePageDto,
        HistoryItemDto,
        HistoryPageDto,
        ToViewItemDto,
        ToViewPageDto;
export 'frb/api/video.dart'
    show
        HeaderDto,
        MediaFormatDto,
        MediaSourceDto,
        StreamDto,
        SubtitleTrackDto,
        VideoDetailDto,
        VideoPageDto,
        VideoStatDto;
export 'frb/auth_service.dart'
    show
        AccountPublicDto,
        CaptchaDto,
        PasswordLoginDto,
        PasswordLoginResultDto,
        PasswordLoginResultKind,
        PasswordRiskDto,
        PasswordRiskSendSmsDto,
        PasswordRiskSendSmsResultDto,
        PasswordRiskVerifyDto,
        QrPollDto,
        QrStartDto,
        QrStatusKind,
        SlotDto,
        SmsLoginDto,
        SmsSendDto,
        SmsSendDtoResult;
export 'frb/error.dart' show AppError, ErrorKind;

/// Thin facade over generated FRB bindings.
class CoreApi {
  CoreApi._();

  static final CoreApi instance = CoreApi._();

  bool _initialized = false;

  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;
    await RustLib.init();
    _initialized = true;
  }

  String ping() => frb.ping();

  frb.ApiVersion apiVersion() => frb.apiVersion();

  Future<void> bootstrap({
    required String dataDir,
    required String cacheDir,
    String logLevel = 'info',
  }) {
    return frb.bootstrap(
      config: frb.BootstrapConfig(
        dataDir: dataDir,
        cacheDir: cacheDir,
        logLevel: logLevel,
      ),
    );
  }

  /// Resolve platform data/cache dirs and bootstrap core.
  Future<frb.ApiVersion> bootstrapDefault({String logLevel = 'info'}) async {
    final support = await getApplicationSupportDirectory();
    final cache = await getApplicationCacheDirectory();
    final dataDir = p.join(support.path, 'nextpili');
    final cacheDir = p.join(cache.path, 'nextpili');
    await bootstrap(dataDir: dataDir, cacheDir: cacheDir, logLevel: logLevel);
    return apiVersion();
  }

  Future<QrStartDto> loginQrStart({String? localId}) =>
      frb_auth.loginQrStart(localId: localId);

  Future<QrPollDto> loginQrPoll({
    required String authCode,
    String? localId,
  }) =>
      frb_auth.loginQrPoll(authCode: authCode, localId: localId);

  Future<CaptchaDto> loginCaptcha() => frb_auth.loginCaptcha();

  String newLoginSessionId() => frb_auth.newLoginSessionId();

  Future<SmsSendDtoResult> loginSmsSend(SmsSendDto req) =>
      frb_auth.loginSmsSend(req: req);

  Future<AccountPublicDto> loginSms(SmsLoginDto req) =>
      frb_auth.loginSms(req: req);

  Future<PasswordLoginResultDto> loginPassword(PasswordLoginDto req) =>
      frb_auth.loginPassword(req: req);

  Future<CaptchaDto> loginPasswordRiskCaptcha() =>
      frb_auth.loginPasswordRiskCaptcha();

  Future<PasswordRiskSendSmsResultDto> loginPasswordRiskSendSms(
    PasswordRiskSendSmsDto req,
  ) =>
      frb_auth.loginPasswordRiskSendSms(req: req);

  Future<AccountPublicDto> loginPasswordRiskVerify(
    PasswordRiskVerifyDto req,
  ) =>
      frb_auth.loginPasswordRiskVerify(req: req);

  List<AccountPublicDto> listAccounts() => frb_auth.listAccounts();

  void logout({String? accountId}) => frb_auth.logout(accountId: accountId);

  void setAccountSlot({required SlotDto slot, String? accountId}) =>
      frb_auth.setAccountSlot(slot: slot, accountId: accountId);

  String deviceBuvid3() => frb_auth.deviceBuvid3();

  Future<frb_feed.RecommendFeedDto> feedRecommend({
    int freshIdx = 0,
    int ps = 12,
  }) =>
      frb_feed.feedRecommend(freshIdx: freshIdx, ps: ps);

  Future<frb_feed.PopularFeedDto> feedPopular({int pn = 1, int ps = 20}) =>
      frb_feed.feedPopular(pn: pn, ps: ps);

  /// Follow dynamics. First page: `offset = ''`.
  /// `typeFilter`: `all` / `video` / `pgc` / `article`.
  Future<frb_dynamics.DynamicPageDto> dynamicsFeed({
    String offset = '',
    String typeFilter = 'all',
    int page = 1,
  }) =>
      frb_dynamics.dynamicsFeed(
        offset: offset,
        typeFilter: typeFilter,
        page: page,
      );

  Future<frb_search.SearchSuggestDto> searchSuggest({required String term}) =>
      frb_search.searchSuggest(term: term);

  Future<frb_search.SearchVideoPageDto> searchVideo({
    required String keyword,
    int page = 1,
  }) =>
      frb_search.searchVideo(keyword: keyword, page: page);

  /// History cursor. First page: `max=0`, `viewAt=0`, `business=''`.
  Future<frb_user.HistoryPageDto> historyList({
    int max = 0,
    int viewAt = 0,
    String business = '',
    int ps = 20,
  }) =>
      frb_user.historyList(
        max: PlatformInt64Util.from(max),
        viewAt: PlatformInt64Util.from(viewAt),
        business: business,
        ps: ps,
      );

  Future<frb_user.ToViewPageDto> toviewList({int pn = 1, int ps = 20}) =>
      frb_user.toviewList(pn: pn, ps: ps);

  /// Pass [rid] (aid) > 0 to fill each folder's `inFolder` for that archive.
  Future<frb_user.FavFolderListDto> favFolders({int rid = 0}) =>
      frb_user.favFolders(rid: PlatformInt64Util.from(rid));

  Future<frb_user.FavResourcePageDto> favResources({
    required int mediaId,
    int pn = 1,
    int ps = 20,
  }) =>
      frb_user.favResources(
        mediaId: PlatformInt64Util.from(mediaId),
        pn: pn,
        ps: ps,
      );

  Future<frb_video.VideoDetailDto> videoDetail(String id) =>
      frb_video.videoDetail(id: id);

  Future<frb_video.MediaSourceDto> playUrl({
    required String id,
    required int cid,
    int qn = 0,
    int fnval = 0,
  }) =>
      frb_video.playUrl(
        id: id,
        cid: PlatformInt64Util.from(cid),
        qn: qn,
        fnval: fnval,
      );

  Future<void> playbackStart({
    required int aid,
    required String bvid,
    required int cid,
  }) =>
      frb_video.playbackStart(
        aid: PlatformInt64Util.from(aid),
        bvid: bvid,
        cid: PlatformInt64Util.from(cid),
      );

  void playbackStop() => frb_video.playbackStop();

  /// Main-floor comments. `oid` is video **aid**. `mode`: 0/3 heat, 2 time.
  Future<frb_social.ReplyListDto> replyList({
    required int oid,
    int type = 1,
    int mode = 3,
    String nextOffset = '',
  }) =>
      frb_social.replyList(
        oid: PlatformInt64Util.from(oid),
        type: type,
        mode: mode,
        nextOffset: nextOffset,
      );

  /// One ~6 min danmaku segment (`segmentIndex` is 1-based).
  Future<frb_social.DanmakuSegmentDto> danmakuSegments({
    required int aid,
    required int cid,
    int segmentIndex = 1,
  }) =>
      frb_social.danmakuSegments(
        aid: PlatformInt64Util.from(aid),
        cid: PlatformInt64Util.from(cid),
        segmentIndex: segmentIndex,
      );

  /// Viewer like/coin/fav/follow flags for an archive.
  Future<frb_engagement.ArchiveRelationDto> videoRelation({
    required int aid,
    required String bvid,
  }) =>
      frb_engagement.videoRelation(
        aid: PlatformInt64Util.from(aid),
        bvid: bvid,
      );

  Future<frb_engagement.ArchiveRelationDto> videoLike({
    required int aid,
    required String bvid,
    required bool like,
  }) =>
      frb_engagement.videoLike(
        aid: PlatformInt64Util.from(aid),
        bvid: bvid,
        like: like,
      );

  Future<frb_engagement.ArchiveRelationDto> videoCoin({
    required int aid,
    required String bvid,
    int multiply = 1,
    bool alsoLike = false,
  }) =>
      frb_engagement.videoCoin(
        aid: PlatformInt64Util.from(aid),
        bvid: bvid,
        multiply: multiply,
        alsoLike: alsoLike,
      );

  Future<frb_engagement.ArchiveRelationDto> videoFavorite({
    required int aid,
    required String bvid,
    required bool favorite,
  }) =>
      frb_engagement.videoFavorite(
        aid: PlatformInt64Util.from(aid),
        bvid: bvid,
        favorite: favorite,
      );

  /// Add / remove [aid] from specific favorite folders.
  Future<frb_engagement.ArchiveRelationDto> videoFavoriteDeal({
    required int aid,
    required String bvid,
    required List<int> addMediaIds,
    required List<int> delMediaIds,
  }) =>
      frb_engagement.videoFavoriteDeal(
        aid: PlatformInt64Util.from(aid),
        bvid: bvid,
        addMediaIds: Int64List.fromList(addMediaIds),
        delMediaIds: Int64List.fromList(delMediaIds),
      );

  Future<void> relationFollow({
    required int mid,
    required bool follow,
  }) =>
      frb_engagement.relationFollow(
        mid: PlatformInt64Util.from(mid),
        follow: follow,
      );

  frb_settings.SettingsDto getSettings() => frb_settings.getSettings();

  /// Patch settings. Pass `proxy: ''` to clear proxy.
  frb_settings.SettingsDto updateSettings({
    int? preferredQn,
    String? proxy,
    String? locale,
  }) =>
      frb_settings.updateSettings(
        preferredQn: preferredQn,
        proxy: proxy,
        locale: locale,
      );
}

/// Map FRB [AppError] / any into user-facing copy (see docs/ux/copy.md).
String errorMessage(Object error, AppLocalizations l10n) {
  if (error is AppError) {
    return switch (error.kind) {
      ErrorKind.network => l10n.errorNetworkUnavailable,
      ErrorKind.unauthenticated => l10n.errorSessionExpired,
      ErrorKind.csrf => l10n.errorCsrf,
      ErrorKind.riskControl =>
        error.message.trim().isEmpty ? l10n.errorRiskControl : error.message,
      ErrorKind.notFound => l10n.errorNotFound,
      ErrorKind.rateLimited => l10n.errorRateLimited,
      ErrorKind.invalidArgument =>
        error.message.trim().isEmpty ? l10n.errorGeneric : error.message,
      ErrorKind.parse || ErrorKind.storage || ErrorKind.internal =>
        error.message.trim().isEmpty ? l10n.errorGeneric : error.message,
    };
  }
  if (error is AnyhowException) {
    return l10n.errorGeneric;
  }
  return l10n.errorGeneric;
}

/// Convert FRB [PlatformInt64] to Dart [int].
int i64(PlatformInt64 v) => v.toInt();
