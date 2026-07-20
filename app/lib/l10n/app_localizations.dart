import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('zh'),
    Locale('en'),
  ];

  /// 应用名称
  ///
  /// In zh, this message translates to:
  /// **'NextPili'**
  String get appTitle;

  /// 通用重试按钮
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确认'**
  String get confirm;

  /// No description provided for @done.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get done;

  /// No description provided for @back.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get back;

  /// No description provided for @play.
  ///
  /// In zh, this message translates to:
  /// **'播放'**
  String get play;

  /// No description provided for @pause.
  ///
  /// In zh, this message translates to:
  /// **'暂停'**
  String get pause;

  /// No description provided for @refresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get refresh;

  /// No description provided for @loadMore.
  ///
  /// In zh, this message translates to:
  /// **'加载更多'**
  String get loadMore;

  /// No description provided for @noMore.
  ///
  /// In zh, this message translates to:
  /// **'没有更多了'**
  String get noMore;

  /// No description provided for @login.
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get login;

  /// No description provided for @logout.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get logout;

  /// No description provided for @user.
  ///
  /// In zh, this message translates to:
  /// **'用户'**
  String get user;

  /// No description provided for @live.
  ///
  /// In zh, this message translates to:
  /// **'直播'**
  String get live;

  /// No description provided for @account.
  ///
  /// In zh, this message translates to:
  /// **'账号'**
  String get account;

  /// No description provided for @goLogin.
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get goLogin;

  /// No description provided for @emptyContent.
  ///
  /// In zh, this message translates to:
  /// **'暂无内容\n下拉可刷新'**
  String get emptyContent;

  /// No description provided for @loading.
  ///
  /// In zh, this message translates to:
  /// **'加载中…'**
  String get loading;

  /// No description provided for @loadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载失败'**
  String get loadFailed;

  /// 网络/超时错误
  ///
  /// In zh, this message translates to:
  /// **'网络不可用，请检查连接后重试'**
  String get errorNetworkUnavailable;

  /// 未登录或会话失效
  ///
  /// In zh, this message translates to:
  /// **'登录已失效，请重新登录'**
  String get errorSessionExpired;

  /// No description provided for @errorCsrf.
  ///
  /// In zh, this message translates to:
  /// **'安全校验失败，请重试'**
  String get errorCsrf;

  /// No description provided for @errorRiskControl.
  ///
  /// In zh, this message translates to:
  /// **'操作被限制，请稍后再试'**
  String get errorRiskControl;

  /// No description provided for @errorNotFound.
  ///
  /// In zh, this message translates to:
  /// **'内容不存在或已删除'**
  String get errorNotFound;

  /// No description provided for @errorRateLimited.
  ///
  /// In zh, this message translates to:
  /// **'请求过于频繁，请稍后再试'**
  String get errorRateLimited;

  /// No description provided for @errorGeneric.
  ///
  /// In zh, this message translates to:
  /// **'出了点问题，请稍后重试'**
  String get errorGeneric;

  /// No description provided for @errorPlayFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法播放此视频，可尝试切换清晰度'**
  String get errorPlayFailed;

  /// No description provided for @errorPlayUrlFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法获取播放地址'**
  String get errorPlayUrlFailed;

  /// No description provided for @playUrlFetching.
  ///
  /// In zh, this message translates to:
  /// **'正在获取播放地址…'**
  String get playUrlFetching;

  /// No description provided for @navHome.
  ///
  /// In zh, this message translates to:
  /// **'首页'**
  String get navHome;

  /// No description provided for @navLive.
  ///
  /// In zh, this message translates to:
  /// **'直播'**
  String get navLive;

  /// No description provided for @navPgc.
  ///
  /// In zh, this message translates to:
  /// **'番剧'**
  String get navPgc;

  /// No description provided for @navSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get navSearch;

  /// No description provided for @navDynamics.
  ///
  /// In zh, this message translates to:
  /// **'动态'**
  String get navDynamics;

  /// No description provided for @navLibrary.
  ///
  /// In zh, this message translates to:
  /// **'我的'**
  String get navLibrary;

  /// No description provided for @navSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get navSettings;

  /// No description provided for @pgcTitle.
  ///
  /// In zh, this message translates to:
  /// **'番剧'**
  String get pgcTitle;

  /// No description provided for @pgcEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无榜单内容'**
  String get pgcEmpty;

  /// No description provided for @pgcNoEpisode.
  ///
  /// In zh, this message translates to:
  /// **'暂无可播放剧集'**
  String get pgcNoEpisode;

  /// No description provided for @pgcTabAnime.
  ///
  /// In zh, this message translates to:
  /// **'番剧'**
  String get pgcTabAnime;

  /// No description provided for @pgcTabGuochuang.
  ///
  /// In zh, this message translates to:
  /// **'国创'**
  String get pgcTabGuochuang;

  /// No description provided for @pgcTabMovie.
  ///
  /// In zh, this message translates to:
  /// **'电影'**
  String get pgcTabMovie;

  /// No description provided for @pgcTabTv.
  ///
  /// In zh, this message translates to:
  /// **'电视剧'**
  String get pgcTabTv;

  /// No description provided for @pgcTabDoc.
  ///
  /// In zh, this message translates to:
  /// **'纪录片'**
  String get pgcTabDoc;

  /// No description provided for @pgcTabVariety.
  ///
  /// In zh, this message translates to:
  /// **'综艺'**
  String get pgcTabVariety;

  /// No description provided for @pgcRating.
  ///
  /// In zh, this message translates to:
  /// **'评分 {score}'**
  String pgcRating(String score);

  /// No description provided for @pgcEpisodesCount.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 话'**
  String pgcEpisodesCount(int count);

  /// No description provided for @pgcEpisodeLabel.
  ///
  /// In zh, this message translates to:
  /// **'第 {index} 话 {title}'**
  String pgcEpisodeLabel(String index, String title);

  /// No description provided for @pgcEpisodeFallback.
  ///
  /// In zh, this message translates to:
  /// **'剧集 {id}'**
  String pgcEpisodeFallback(String id);

  /// No description provided for @liveTitle.
  ///
  /// In zh, this message translates to:
  /// **'直播'**
  String get liveTitle;

  /// No description provided for @liveEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无直播推荐'**
  String get liveEmpty;

  /// No description provided for @liveBadge.
  ///
  /// In zh, this message translates to:
  /// **'直播中'**
  String get liveBadge;

  /// No description provided for @liveOffline.
  ///
  /// In zh, this message translates to:
  /// **'未开播'**
  String get liveOffline;

  /// No description provided for @liveRound.
  ///
  /// In zh, this message translates to:
  /// **'轮播中'**
  String get liveRound;

  /// No description provided for @liveOnline.
  ///
  /// In zh, this message translates to:
  /// **'{count} 人气'**
  String liveOnline(String count);

  /// No description provided for @liveChatTitle.
  ///
  /// In zh, this message translates to:
  /// **'弹幕'**
  String get liveChatTitle;

  /// No description provided for @liveChatEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无弹幕'**
  String get liveChatEmpty;

  /// No description provided for @liveChatHint.
  ///
  /// In zh, this message translates to:
  /// **'发送弹幕'**
  String get liveChatHint;

  /// No description provided for @liveChatSend.
  ///
  /// In zh, this message translates to:
  /// **'发送'**
  String get liveChatSend;

  /// No description provided for @liveChatSent.
  ///
  /// In zh, this message translates to:
  /// **'已发送'**
  String get liveChatSent;

  /// No description provided for @liveChatEmptyMessage.
  ///
  /// In zh, this message translates to:
  /// **'请输入弹幕内容'**
  String get liveChatEmptyMessage;

  /// No description provided for @dynamicsTitle.
  ///
  /// In zh, this message translates to:
  /// **'动态'**
  String get dynamicsTitle;

  /// No description provided for @dynamicsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无关注动态'**
  String get dynamicsEmpty;

  /// No description provided for @dynamicsNeedLogin.
  ///
  /// In zh, this message translates to:
  /// **'登录后查看关注动态'**
  String get dynamicsNeedLogin;

  /// No description provided for @libraryTabHistory.
  ///
  /// In zh, this message translates to:
  /// **'历史'**
  String get libraryTabHistory;

  /// No description provided for @libraryTabToview.
  ///
  /// In zh, this message translates to:
  /// **'稍后再看'**
  String get libraryTabToview;

  /// No description provided for @libraryTabFav.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get libraryTabFav;

  /// No description provided for @libraryHistoryEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无观看历史'**
  String get libraryHistoryEmpty;

  /// No description provided for @libraryToviewEmpty.
  ///
  /// In zh, this message translates to:
  /// **'稍后再看是空的'**
  String get libraryToviewEmpty;

  /// No description provided for @libraryFavEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无收藏'**
  String get libraryFavEmpty;

  /// No description provided for @homeTabRecommend.
  ///
  /// In zh, this message translates to:
  /// **'推荐'**
  String get homeTabRecommend;

  /// No description provided for @homeTabPopular.
  ///
  /// In zh, this message translates to:
  /// **'热门'**
  String get homeTabPopular;

  /// No description provided for @searchTitle.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get searchTitle;

  /// No description provided for @searchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索视频'**
  String get searchHint;

  /// No description provided for @searchIdle.
  ///
  /// In zh, this message translates to:
  /// **'输入关键词开始搜索'**
  String get searchIdle;

  /// No description provided for @searchEmpty.
  ///
  /// In zh, this message translates to:
  /// **'没有找到相关视频'**
  String get searchEmpty;

  /// No description provided for @searchResultHint.
  ///
  /// In zh, this message translates to:
  /// **'「{keyword}」的结果'**
  String searchResultHint(String keyword);

  /// No description provided for @settingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingsTitle;

  /// No description provided for @settingsAccountTitle.
  ///
  /// In zh, this message translates to:
  /// **'账号与登录'**
  String get settingsAccountTitle;

  /// No description provided for @settingsAccountSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'登录/注册 · 桌面/平板扫码'**
  String get settingsAccountSubtitle;

  /// No description provided for @settingsDefaultQuality.
  ///
  /// In zh, this message translates to:
  /// **'默认清晰度'**
  String get settingsDefaultQuality;

  /// No description provided for @settingsProxyTitle.
  ///
  /// In zh, this message translates to:
  /// **'HTTP 代理'**
  String get settingsProxyTitle;

  /// No description provided for @settingsProxyHelper.
  ///
  /// In zh, this message translates to:
  /// **'留空并保存可清除；支持 http / https / socks5'**
  String get settingsProxyHelper;

  /// No description provided for @settingsProxySave.
  ///
  /// In zh, this message translates to:
  /// **'保存代理'**
  String get settingsProxySave;

  /// No description provided for @settingsQualityUpdated.
  ///
  /// In zh, this message translates to:
  /// **'默认清晰度已更新'**
  String get settingsQualityUpdated;

  /// No description provided for @settingsProxyCleared.
  ///
  /// In zh, this message translates to:
  /// **'已清除代理'**
  String get settingsProxyCleared;

  /// No description provided for @settingsProxySaved.
  ///
  /// In zh, this message translates to:
  /// **'代理已保存'**
  String get settingsProxySaved;

  /// No description provided for @settingsQnLabel.
  ///
  /// In zh, this message translates to:
  /// **'qn {qn}'**
  String settingsQnLabel(int qn);

  /// No description provided for @settingsQnWithLabel.
  ///
  /// In zh, this message translates to:
  /// **'{label} · qn {qn}'**
  String settingsQnWithLabel(String label, int qn);

  /// 清晰度选项：杜比视界
  ///
  /// In zh, this message translates to:
  /// **'杜比视界'**
  String get qualityDolbyVision;

  /// No description provided for @videoDetailTitle.
  ///
  /// In zh, this message translates to:
  /// **'稿件详情'**
  String get videoDetailTitle;

  /// No description provided for @videoDesc.
  ///
  /// In zh, this message translates to:
  /// **'简介'**
  String get videoDesc;

  /// No description provided for @videoDescEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无简介'**
  String get videoDescEmpty;

  /// 截断文案展开控件
  ///
  /// In zh, this message translates to:
  /// **'展开'**
  String get expand;

  /// 截断文案收起控件
  ///
  /// In zh, this message translates to:
  /// **'收起'**
  String get collapse;

  /// No description provided for @videoPartsCount.
  ///
  /// In zh, this message translates to:
  /// **'分 P（{count}）'**
  String videoPartsCount(int count);

  /// No description provided for @videoPartsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无分 P'**
  String get videoPartsEmpty;

  /// No description provided for @videoPartFallback.
  ///
  /// In zh, this message translates to:
  /// **'P{page}'**
  String videoPartFallback(int page);

  /// No description provided for @replyTitle.
  ///
  /// In zh, this message translates to:
  /// **'评论'**
  String get replyTitle;

  /// No description provided for @replyTitleWithCount.
  ///
  /// In zh, this message translates to:
  /// **'评论（{count}）'**
  String replyTitleWithCount(int count);

  /// No description provided for @replySortHeat.
  ///
  /// In zh, this message translates to:
  /// **'热度'**
  String get replySortHeat;

  /// No description provided for @replySortTime.
  ///
  /// In zh, this message translates to:
  /// **'时间'**
  String get replySortTime;

  /// No description provided for @replyEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无评论'**
  String get replyEmpty;

  /// No description provided for @replyChildrenCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 条回复'**
  String replyChildrenCount(int count);

  /// No description provided for @replyHint.
  ///
  /// In zh, this message translates to:
  /// **'写一条友善的评论'**
  String get replyHint;

  /// No description provided for @replySend.
  ///
  /// In zh, this message translates to:
  /// **'发送'**
  String get replySend;

  /// No description provided for @replySent.
  ///
  /// In zh, this message translates to:
  /// **'评论已发送'**
  String get replySent;

  /// No description provided for @replyEmptyMessage.
  ///
  /// In zh, this message translates to:
  /// **'请输入评论内容'**
  String get replyEmptyMessage;

  /// No description provided for @playerDanmakuOn.
  ///
  /// In zh, this message translates to:
  /// **'打开弹幕'**
  String get playerDanmakuOn;

  /// No description provided for @playerDanmakuOff.
  ///
  /// In zh, this message translates to:
  /// **'关闭弹幕'**
  String get playerDanmakuOff;

  /// No description provided for @playerDanmakuClosed.
  ///
  /// In zh, this message translates to:
  /// **'弹幕已关闭'**
  String get playerDanmakuClosed;

  /// No description provided for @playerDanmakuHint.
  ///
  /// In zh, this message translates to:
  /// **'发条弹幕'**
  String get playerDanmakuHint;

  /// No description provided for @playerDanmakuSend.
  ///
  /// In zh, this message translates to:
  /// **'发送'**
  String get playerDanmakuSend;

  /// No description provided for @playerDanmakuSent.
  ///
  /// In zh, this message translates to:
  /// **'弹幕已发送'**
  String get playerDanmakuSent;

  /// No description provided for @playerDanmakuEmpty.
  ///
  /// In zh, this message translates to:
  /// **'请输入弹幕内容'**
  String get playerDanmakuEmpty;

  /// No description provided for @playerQuality.
  ///
  /// In zh, this message translates to:
  /// **'清晰度'**
  String get playerQuality;

  /// 播放器倍速菜单
  ///
  /// In zh, this message translates to:
  /// **'倍速'**
  String get playerSpeed;

  /// 播放器音轨菜单
  ///
  /// In zh, this message translates to:
  /// **'音轨'**
  String get playerAudio;

  /// 播放器字幕菜单
  ///
  /// In zh, this message translates to:
  /// **'字幕'**
  String get playerSubtitle;

  /// 关闭字幕选项
  ///
  /// In zh, this message translates to:
  /// **'关闭字幕'**
  String get playerSubtitleOff;

  /// No description provided for @playerFullscreen.
  ///
  /// In zh, this message translates to:
  /// **'全屏'**
  String get playerFullscreen;

  /// No description provided for @authTitle.
  ///
  /// In zh, this message translates to:
  /// **'账号与登录'**
  String get authTitle;

  /// No description provided for @authTabSms.
  ///
  /// In zh, this message translates to:
  /// **'登录/注册'**
  String get authTabSms;

  /// No description provided for @authTabPassword.
  ///
  /// In zh, this message translates to:
  /// **'密码登录'**
  String get authTabPassword;

  /// No description provided for @authTabQr.
  ///
  /// In zh, this message translates to:
  /// **'扫码登录'**
  String get authTabQr;

  /// No description provided for @authSavedAccounts.
  ///
  /// In zh, this message translates to:
  /// **'已保存账号'**
  String get authSavedAccounts;

  /// No description provided for @authNoAccounts.
  ///
  /// In zh, this message translates to:
  /// **'暂无账号'**
  String get authNoAccounts;

  /// No description provided for @authAccountLoggedIn.
  ///
  /// In zh, this message translates to:
  /// **'已登录'**
  String get authAccountLoggedIn;

  /// No description provided for @authAccountInvalid.
  ///
  /// In zh, this message translates to:
  /// **'已失效'**
  String get authAccountInvalid;

  /// No description provided for @authAccountSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'mid {mid} · {status}'**
  String authAccountSubtitle(String mid, String status);

  /// No description provided for @authMobileOnlyHint.
  ///
  /// In zh, this message translates to:
  /// **'手机端可用短信或密码登录；扫码登录在桌面/平板可用'**
  String get authMobileOnlyHint;

  /// No description provided for @authDeviceBuvid.
  ///
  /// In zh, this message translates to:
  /// **'设备 buvid3：{buvid}'**
  String authDeviceBuvid(String buvid);

  /// No description provided for @authLoggedOut.
  ///
  /// In zh, this message translates to:
  /// **'已退出登录'**
  String get authLoggedOut;

  /// No description provided for @authLoginSuccessNamed.
  ///
  /// In zh, this message translates to:
  /// **'已登录：{name}'**
  String authLoginSuccessNamed(String name);

  /// No description provided for @authLoginSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已登录'**
  String get authLoginSuccess;

  /// 风控短信验证主按钮
  ///
  /// In zh, this message translates to:
  /// **'验证'**
  String get authVerify;

  /// No description provided for @authSmsIntro.
  ///
  /// In zh, this message translates to:
  /// **'使用手机号与短信验证码登录或注册。未注册号码将自动创建账号。账号信息仅保存在本机。'**
  String get authSmsIntro;

  /// No description provided for @authCountryCode.
  ///
  /// In zh, this message translates to:
  /// **'区号'**
  String get authCountryCode;

  /// No description provided for @authCountryChina.
  ///
  /// In zh, this message translates to:
  /// **'+86 中国'**
  String get authCountryChina;

  /// No description provided for @authCountrySearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索国家/地区或区号'**
  String get authCountrySearchHint;

  /// No description provided for @authCountrySearchEmpty.
  ///
  /// In zh, this message translates to:
  /// **'无匹配区号'**
  String get authCountrySearchEmpty;

  /// No description provided for @authPhone.
  ///
  /// In zh, this message translates to:
  /// **'手机号'**
  String get authPhone;

  /// No description provided for @authGetCaptcha.
  ///
  /// In zh, this message translates to:
  /// **'获取人机验证'**
  String get authGetCaptcha;

  /// No description provided for @authOpenGeeHelper.
  ///
  /// In zh, this message translates to:
  /// **'打开极验助手'**
  String get authOpenGeeHelper;

  /// No description provided for @authGeeSeccodeOptionalDefault.
  ///
  /// In zh, this message translates to:
  /// **'gee_seccode（可留空，默认 validate|jordan）'**
  String get authGeeSeccodeOptionalDefault;

  /// No description provided for @authGeeSeccodeOptional.
  ///
  /// In zh, this message translates to:
  /// **'gee_seccode（可留空）'**
  String get authGeeSeccodeOptional;

  /// No description provided for @authSendSmsCode.
  ///
  /// In zh, this message translates to:
  /// **'发送短信验证码'**
  String get authSendSmsCode;

  /// No description provided for @authSendCode.
  ///
  /// In zh, this message translates to:
  /// **'发送验证码'**
  String get authSendCode;

  /// No description provided for @authSending.
  ///
  /// In zh, this message translates to:
  /// **'发送中…'**
  String get authSending;

  /// No description provided for @authProcessing.
  ///
  /// In zh, this message translates to:
  /// **'登录中…'**
  String get authProcessing;

  /// No description provided for @authLoginOrRegister.
  ///
  /// In zh, this message translates to:
  /// **'登录/注册'**
  String get authLoginOrRegister;

  /// No description provided for @authLoggingInOrRegistering.
  ///
  /// In zh, this message translates to:
  /// **'登录/注册中…'**
  String get authLoggingInOrRegistering;

  /// No description provided for @authCaptchaKeyReady.
  ///
  /// In zh, this message translates to:
  /// **'人机验证已通过'**
  String get authCaptchaKeyReady;

  /// No description provided for @authSmsCode.
  ///
  /// In zh, this message translates to:
  /// **'短信验证码'**
  String get authSmsCode;

  /// No description provided for @authSmsHintInitial.
  ///
  /// In zh, this message translates to:
  /// **'完成人机验证后可发送短信验证码'**
  String get authSmsHintInitial;

  /// No description provided for @authSmsHintFetching.
  ///
  /// In zh, this message translates to:
  /// **'获取人机验证…'**
  String get authSmsHintFetching;

  /// No description provided for @authSmsHintCompleteGee.
  ///
  /// In zh, this message translates to:
  /// **'请完成人机验证，再发送短信'**
  String get authSmsHintCompleteGee;

  /// No description provided for @authSmsHintFetchFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法获取人机验证，请重试'**
  String get authSmsHintFetchFailed;

  /// No description provided for @authSmsHintSent.
  ///
  /// In zh, this message translates to:
  /// **'短信已发送，请输入验证码完成登录/注册'**
  String get authSmsHintSent;

  /// No description provided for @authNeedCaptchaFirst.
  ///
  /// In zh, this message translates to:
  /// **'请先完成人机验证'**
  String get authNeedCaptchaFirst;

  /// No description provided for @authCannotOpenGeePage.
  ///
  /// In zh, this message translates to:
  /// **'无法打开验证页面，请手动完成极验后填入结果'**
  String get authCannotOpenGeePage;

  /// No description provided for @authCannotOpenGeePageShort.
  ///
  /// In zh, this message translates to:
  /// **'无法打开验证页面'**
  String get authCannotOpenGeePageShort;

  /// No description provided for @authCopiedGeeParams.
  ///
  /// In zh, this message translates to:
  /// **'验证参数已复制，完成验证后粘贴结果'**
  String get authCopiedGeeParams;

  /// No description provided for @authCopiedGeeParamsShort.
  ///
  /// In zh, this message translates to:
  /// **'验证参数已复制'**
  String get authCopiedGeeParamsShort;

  /// No description provided for @authNeedGeeValidate.
  ///
  /// In zh, this message translates to:
  /// **'请填入验证结果'**
  String get authNeedGeeValidate;

  /// No description provided for @authCodeSent.
  ///
  /// In zh, this message translates to:
  /// **'验证码已发送'**
  String get authCodeSent;

  /// No description provided for @authNeedSendSmsFirst.
  ///
  /// In zh, this message translates to:
  /// **'请先发送短信验证码'**
  String get authNeedSendSmsFirst;

  /// No description provided for @authNeedSmsCode.
  ///
  /// In zh, this message translates to:
  /// **'请输入短信验证码'**
  String get authNeedSmsCode;

  /// No description provided for @authPwdIntro.
  ///
  /// In zh, this message translates to:
  /// **'使用手机号或邮箱与密码登录。密码仅用于本次登录，不会保存在本机。'**
  String get authPwdIntro;

  /// No description provided for @authUsername.
  ///
  /// In zh, this message translates to:
  /// **'账号'**
  String get authUsername;

  /// No description provided for @authPassword.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get authPassword;

  /// No description provided for @authLoggingIn.
  ///
  /// In zh, this message translates to:
  /// **'登录中…'**
  String get authLoggingIn;

  /// No description provided for @authPwdHintInitial.
  ///
  /// In zh, this message translates to:
  /// **'完成人机验证后可登录'**
  String get authPwdHintInitial;

  /// No description provided for @authPwdHintFetching.
  ///
  /// In zh, this message translates to:
  /// **'获取人机验证…'**
  String get authPwdHintFetching;

  /// No description provided for @authPwdHintCompleteGee.
  ///
  /// In zh, this message translates to:
  /// **'请完成人机验证，再登录'**
  String get authPwdHintCompleteGee;

  /// No description provided for @authPwdHintFetchFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法获取人机验证，请重试'**
  String get authPwdHintFetchFailed;

  /// No description provided for @authQrIntro.
  ///
  /// In zh, this message translates to:
  /// **'使用 bilibili 手机客户端扫码登录。二维码过期后可刷新。'**
  String get authQrIntro;

  /// No description provided for @authQrNotStarted.
  ///
  /// In zh, this message translates to:
  /// **'未开始'**
  String get authQrNotStarted;

  /// No description provided for @authQrRequesting.
  ///
  /// In zh, this message translates to:
  /// **'获取二维码…'**
  String get authQrRequesting;

  /// No description provided for @authQrScanHint.
  ///
  /// In zh, this message translates to:
  /// **'请使用手机客户端扫码'**
  String get authQrScanHint;

  /// No description provided for @authQrRequestFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法获取二维码'**
  String get authQrRequestFailed;

  /// No description provided for @authQrScanned.
  ///
  /// In zh, this message translates to:
  /// **'已扫码，请在手机上确认'**
  String get authQrScanned;

  /// No description provided for @authQrExpired.
  ///
  /// In zh, this message translates to:
  /// **'二维码已过期'**
  String get authQrExpired;

  /// No description provided for @authQrRefreshing.
  ///
  /// In zh, this message translates to:
  /// **'刷新中…'**
  String get authQrRefreshing;

  /// No description provided for @authQrTapRefresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新二维码'**
  String get authQrTapRefresh;

  /// No description provided for @authQrReacquire.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get authQrReacquire;

  /// No description provided for @authRiskTitle.
  ///
  /// In zh, this message translates to:
  /// **'需要验证手机号'**
  String get authRiskTitle;

  /// No description provided for @authRiskPhoneHint.
  ///
  /// In zh, this message translates to:
  /// **'请使用绑定手机号完成短信验证'**
  String get authRiskPhoneHint;

  /// No description provided for @authRiskHintInitial.
  ///
  /// In zh, this message translates to:
  /// **'完成人机验证后发送短信'**
  String get authRiskHintInitial;

  /// No description provided for @authRiskHintFetching.
  ///
  /// In zh, this message translates to:
  /// **'获取人机验证…'**
  String get authRiskHintFetching;

  /// No description provided for @authRiskHintCompleteGee.
  ///
  /// In zh, this message translates to:
  /// **'完成人机验证后发送验证码'**
  String get authRiskHintCompleteGee;

  /// No description provided for @authRiskHintFetchFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法获取人机验证，请重试'**
  String get authRiskHintFetchFailed;

  /// No description provided for @authRiskHintSent.
  ///
  /// In zh, this message translates to:
  /// **'短信已发送，请输入验证码'**
  String get authRiskHintSent;

  /// No description provided for @authQrPanelTitle.
  ///
  /// In zh, this message translates to:
  /// **'扫描二维码登录'**
  String get authQrPanelTitle;

  /// No description provided for @authQrPanelHint.
  ///
  /// In zh, this message translates to:
  /// **'请使用 bilibili 客户端扫码登录'**
  String get authQrPanelHint;

  /// No description provided for @authRegister.
  ///
  /// In zh, this message translates to:
  /// **'注册'**
  String get authRegister;

  /// No description provided for @authForgotPassword.
  ///
  /// In zh, this message translates to:
  /// **'忘记密码？'**
  String get authForgotPassword;

  /// No description provided for @authAccountLabel.
  ///
  /// In zh, this message translates to:
  /// **'账号'**
  String get authAccountLabel;

  /// No description provided for @authAccountHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入账号'**
  String get authAccountHint;

  /// No description provided for @authPasswordHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入密码'**
  String get authPasswordHint;

  /// No description provided for @authPhoneHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入手机号'**
  String get authPhoneHint;

  /// No description provided for @authSmsCodeHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入验证码'**
  String get authSmsCodeHint;

  /// No description provided for @authCaptchaSection.
  ///
  /// In zh, this message translates to:
  /// **'人机验证'**
  String get authCaptchaSection;

  /// No description provided for @authTermsFooter.
  ///
  /// In zh, this message translates to:
  /// **'短信登录与注册为同一流程：未注册手机号将自动创建账号。继续即表示同意用户协议与隐私政策。'**
  String get authTermsFooter;

  /// No description provided for @authShowPassword.
  ///
  /// In zh, this message translates to:
  /// **'显示密码'**
  String get authShowPassword;

  /// No description provided for @authHidePassword.
  ///
  /// In zh, this message translates to:
  /// **'隐藏密码'**
  String get authHidePassword;

  /// No description provided for @authOpenExternalForgot.
  ///
  /// In zh, this message translates to:
  /// **'在浏览器打开找回密码页'**
  String get authOpenExternalForgot;

  /// No description provided for @statLike.
  ///
  /// In zh, this message translates to:
  /// **'点赞'**
  String get statLike;

  /// No description provided for @statCoin.
  ///
  /// In zh, this message translates to:
  /// **'投币'**
  String get statCoin;

  /// No description provided for @statFavorite.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get statFavorite;

  /// No description provided for @statShare.
  ///
  /// In zh, this message translates to:
  /// **'分享'**
  String get statShare;

  /// No description provided for @statReply.
  ///
  /// In zh, this message translates to:
  /// **'评论'**
  String get statReply;

  /// No description provided for @statView.
  ///
  /// In zh, this message translates to:
  /// **'播放'**
  String get statView;

  /// No description provided for @statDanmaku.
  ///
  /// In zh, this message translates to:
  /// **'弹幕'**
  String get statDanmaku;

  /// No description provided for @follow.
  ///
  /// In zh, this message translates to:
  /// **'关注'**
  String get follow;

  /// No description provided for @following.
  ///
  /// In zh, this message translates to:
  /// **'已关注'**
  String get following;

  /// No description provided for @followSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已关注'**
  String get followSuccess;

  /// No description provided for @unfollowSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已取消关注'**
  String get unfollowSuccess;

  /// No description provided for @actionComingSoon.
  ///
  /// In zh, this message translates to:
  /// **'即将支持'**
  String get actionComingSoon;

  /// No description provided for @loginRequiredTitle.
  ///
  /// In zh, this message translates to:
  /// **'需要登录'**
  String get loginRequiredTitle;

  /// No description provided for @loginRequiredBody.
  ///
  /// In zh, this message translates to:
  /// **'登录后即可点赞、投币、收藏、关注、发评论与弹幕'**
  String get loginRequiredBody;

  /// No description provided for @coinDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'投币'**
  String get coinDialogTitle;

  /// No description provided for @coinOne.
  ///
  /// In zh, this message translates to:
  /// **'投 1 枚'**
  String get coinOne;

  /// No description provided for @coinTwo.
  ///
  /// In zh, this message translates to:
  /// **'投 2 枚'**
  String get coinTwo;

  /// No description provided for @coinAlreadyMax.
  ///
  /// In zh, this message translates to:
  /// **'已投满 2 枚硬币'**
  String get coinAlreadyMax;

  /// No description provided for @favoriteAdded.
  ///
  /// In zh, this message translates to:
  /// **'已收藏'**
  String get favoriteAdded;

  /// No description provided for @favoriteRemoved.
  ///
  /// In zh, this message translates to:
  /// **'已取消收藏'**
  String get favoriteRemoved;

  /// No description provided for @undo.
  ///
  /// In zh, this message translates to:
  /// **'撤销'**
  String get undo;

  /// No description provided for @favFolderPickerTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择收藏夹'**
  String get favFolderPickerTitle;

  /// No description provided for @favFolderPickerHint.
  ///
  /// In zh, this message translates to:
  /// **'勾选要加入的收藏夹；取消勾选将移出'**
  String get favFolderPickerHint;

  /// No description provided for @favFolderPickerEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无收藏夹'**
  String get favFolderPickerEmpty;

  /// No description provided for @favFolderMediaCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个内容'**
  String favFolderMediaCount(int count);

  /// No description provided for @statFavoriteLongPress.
  ///
  /// In zh, this message translates to:
  /// **'长按选择收藏夹'**
  String get statFavoriteLongPress;

  /// No description provided for @linkCopied.
  ///
  /// In zh, this message translates to:
  /// **'链接已复制'**
  String get linkCopied;

  /// No description provided for @videoRelated.
  ///
  /// In zh, this message translates to:
  /// **'相关推荐'**
  String get videoRelated;

  /// No description provided for @videoWatchTitle.
  ///
  /// In zh, this message translates to:
  /// **'观看'**
  String get videoWatchTitle;

  /// No description provided for @bootCoreFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法启动 Core：\n{message}'**
  String bootCoreFailed(String message);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
