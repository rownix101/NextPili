import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'frb/api/auth.dart' as frb_auth;
import 'frb/api/feed.dart' as frb_feed;
import 'frb/api/simple.dart' as frb;
import 'frb/api/video.dart' as frb_video;
import 'frb/auth_service.dart';
import 'frb/error.dart';
import 'frb/frb_generated.dart';

export 'frb/api/simple.dart' show ApiVersion, BootstrapConfig;
export 'frb/api/feed.dart'
    show FeedItemDto, PopularFeedDto, RecommendFeedDto;
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
}

/// Map FRB [AppError] / any into a short UI message.
String errorMessage(Object error) {
  if (error is AppError) {
    return error.message;
  }
  if (error is AnyhowException) {
    return error.message;
  }
  return error.toString();
}

/// Convert FRB [PlatformInt64] to Dart [int].
int i64(PlatformInt64 v) => v.toInt();
