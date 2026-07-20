// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'NextPili';

  @override
  String get retry => '重试';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确认';

  @override
  String get done => '完成';

  @override
  String get back => '返回';

  @override
  String get play => '播放';

  @override
  String get pause => '暂停';

  @override
  String get refresh => '刷新';

  @override
  String get loadMore => '加载更多';

  @override
  String get noMore => '没有更多了';

  @override
  String get login => '登录';

  @override
  String get logout => '退出登录';

  @override
  String get user => '用户';

  @override
  String get live => '直播';

  @override
  String get account => '账号';

  @override
  String get goLogin => '登录';

  @override
  String get emptyContent => '暂无内容\n下拉可刷新';

  @override
  String get loading => '加载中…';

  @override
  String get loadFailed => '加载失败';

  @override
  String get errorNetworkUnavailable => '网络不可用，请检查连接后重试';

  @override
  String get errorSessionExpired => '登录已失效，请重新登录';

  @override
  String get errorCsrf => '安全校验失败，请重试';

  @override
  String get errorRiskControl => '操作被限制，请稍后再试';

  @override
  String get errorNotFound => '内容不存在或已删除';

  @override
  String get errorRateLimited => '请求过于频繁，请稍后再试';

  @override
  String get errorGeneric => '出了点问题，请稍后重试';

  @override
  String get errorPlayFailed => '无法播放此视频，可尝试切换清晰度';

  @override
  String get errorPlayUrlFailed => '无法获取播放地址';

  @override
  String get playUrlFetching => '正在获取播放地址…';

  @override
  String get navHome => '首页';

  @override
  String get navLive => '直播';

  @override
  String get navPgc => '番剧';

  @override
  String get navSearch => '搜索';

  @override
  String get navDynamics => '动态';

  @override
  String get navLibrary => '我的';

  @override
  String get navSettings => '设置';

  @override
  String get pgcTitle => '番剧';

  @override
  String get pgcEmpty => '暂无榜单内容';

  @override
  String get pgcNoEpisode => '暂无可播放剧集';

  @override
  String get pgcTabAnime => '番剧';

  @override
  String get pgcTabGuochuang => '国创';

  @override
  String get pgcTabMovie => '电影';

  @override
  String get pgcTabTv => '电视剧';

  @override
  String get pgcTabDoc => '纪录片';

  @override
  String get pgcTabVariety => '综艺';

  @override
  String pgcRating(String score) {
    return '评分 $score';
  }

  @override
  String pgcEpisodesCount(int count) {
    return '共 $count 话';
  }

  @override
  String pgcEpisodeLabel(String index, String title) {
    return '第 $index 话 $title';
  }

  @override
  String pgcEpisodeFallback(String id) {
    return '剧集 $id';
  }

  @override
  String get liveTitle => '直播';

  @override
  String get liveEmpty => '暂无直播推荐';

  @override
  String get liveBadge => '直播中';

  @override
  String get liveOffline => '未开播';

  @override
  String get liveRound => '轮播中';

  @override
  String liveOnline(String count) {
    return '$count 人气';
  }

  @override
  String get liveChatTitle => '弹幕';

  @override
  String get liveChatEmpty => '暂无弹幕';

  @override
  String get liveChatHint => '发送弹幕';

  @override
  String get liveChatSend => '发送';

  @override
  String get liveChatSent => '已发送';

  @override
  String get liveChatEmptyMessage => '请输入弹幕内容';

  @override
  String get dynamicsTitle => '动态';

  @override
  String get dynamicsEmpty => '暂无关注动态';

  @override
  String get dynamicsNeedLogin => '登录后查看关注动态';

  @override
  String get libraryTabHistory => '历史';

  @override
  String get libraryTabToview => '稍后再看';

  @override
  String get libraryTabFav => '收藏';

  @override
  String get libraryHistoryEmpty => '暂无观看历史';

  @override
  String get libraryToviewEmpty => '稍后再看是空的';

  @override
  String get libraryFavEmpty => '暂无收藏';

  @override
  String get homeTabRecommend => '推荐';

  @override
  String get homeTabPopular => '热门';

  @override
  String get homeTabRegion => '分区';

  @override
  String get searchTitle => '搜索';

  @override
  String get searchHint => '搜索视频';

  @override
  String get searchIdle => '输入关键词开始搜索';

  @override
  String get searchEmpty => '没有找到相关视频';

  @override
  String searchResultHint(String keyword) {
    return '「$keyword」的结果';
  }

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsAccountTitle => '账号与登录';

  @override
  String get settingsAccountSubtitle => '登录/注册 · 桌面/平板扫码';

  @override
  String get settingsDefaultQuality => '默认清晰度';

  @override
  String get settingsProxyTitle => 'HTTP 代理';

  @override
  String get settingsProxyHelper => '留空并保存可清除；支持 http / https / socks5';

  @override
  String get settingsProxySave => '保存代理';

  @override
  String get settingsQualityUpdated => '默认清晰度已更新';

  @override
  String get settingsProxyCleared => '已清除代理';

  @override
  String get settingsProxySaved => '代理已保存';

  @override
  String settingsQnLabel(int qn) {
    return 'qn $qn';
  }

  @override
  String settingsQnWithLabel(String label, int qn) {
    return '$label · qn $qn';
  }

  @override
  String get qualityDolbyVision => '杜比视界';

  @override
  String get videoDetailTitle => '稿件详情';

  @override
  String get videoDesc => '简介';

  @override
  String get videoDescEmpty => '暂无简介';

  @override
  String get expand => '展开';

  @override
  String get collapse => '收起';

  @override
  String videoPartsCount(int count) {
    return '分 P（$count）';
  }

  @override
  String get videoPartsEmpty => '暂无分 P';

  @override
  String videoPartFallback(int page) {
    return 'P$page';
  }

  @override
  String get replyTitle => '评论';

  @override
  String replyTitleWithCount(int count) {
    return '评论（$count）';
  }

  @override
  String get replySortHeat => '热度';

  @override
  String get replySortTime => '时间';

  @override
  String get replyEmpty => '暂无评论';

  @override
  String replyChildrenCount(int count) {
    return '$count 条回复';
  }

  @override
  String get replyHint => '写一条友善的评论';

  @override
  String get replySend => '发送';

  @override
  String get replySent => '评论已发送';

  @override
  String get replyEmptyMessage => '请输入评论内容';

  @override
  String get playerDanmakuOn => '打开弹幕';

  @override
  String get playerDanmakuOff => '关闭弹幕';

  @override
  String get playerDanmakuClosed => '弹幕已关闭';

  @override
  String get playerDanmakuHint => '发条弹幕';

  @override
  String get playerDanmakuSend => '发送';

  @override
  String get playerDanmakuSent => '弹幕已发送';

  @override
  String get playerDanmakuEmpty => '请输入弹幕内容';

  @override
  String get playerQuality => '清晰度';

  @override
  String get playerSpeed => '倍速';

  @override
  String get playerAudio => '音轨';

  @override
  String get playerSubtitle => '字幕';

  @override
  String get playerSubtitleOff => '关闭字幕';

  @override
  String get playerFullscreen => '全屏';

  @override
  String get playerFullscreenExit => '退出全屏';

  @override
  String get playerMini => '小窗播放';

  @override
  String get playerRestore => '返回播放页';

  @override
  String get playerClose => '关闭播放';

  @override
  String get authTitle => '账号与登录';

  @override
  String get authTabSms => '登录/注册';

  @override
  String get authTabPassword => '密码登录';

  @override
  String get authTabQr => '扫码登录';

  @override
  String get authSavedAccounts => '已保存账号';

  @override
  String get authNoAccounts => '暂无账号';

  @override
  String get authAccountLoggedIn => '已登录';

  @override
  String get authAccountInvalid => '已失效';

  @override
  String authAccountSubtitle(String mid, String status) {
    return 'mid $mid · $status';
  }

  @override
  String get authMobileOnlyHint => '手机端可用短信或密码登录；扫码登录在桌面/平板可用';

  @override
  String authDeviceBuvid(String buvid) {
    return '设备 buvid3：$buvid';
  }

  @override
  String get authLoggedOut => '已退出登录';

  @override
  String authLoginSuccessNamed(String name) {
    return '已登录：$name';
  }

  @override
  String get authLoginSuccess => '已登录';

  @override
  String get authVerify => '验证';

  @override
  String get authSmsIntro => '使用手机号与短信验证码登录或注册。未注册号码将自动创建账号。账号信息仅保存在本机。';

  @override
  String get authCountryCode => '区号';

  @override
  String get authCountryChina => '+86 中国';

  @override
  String get authCountrySearchHint => '搜索国家/地区或区号';

  @override
  String get authCountrySearchEmpty => '无匹配区号';

  @override
  String get authPhone => '手机号';

  @override
  String get authGetCaptcha => '获取人机验证';

  @override
  String get authOpenGeeHelper => '打开极验助手';

  @override
  String get authGeeSeccodeOptionalDefault =>
      'gee_seccode（可留空，默认 validate|jordan）';

  @override
  String get authGeeSeccodeOptional => 'gee_seccode（可留空）';

  @override
  String get authSendSmsCode => '发送短信验证码';

  @override
  String get authSendCode => '发送验证码';

  @override
  String get authSending => '发送中…';

  @override
  String get authProcessing => '登录中…';

  @override
  String get authLoginOrRegister => '登录/注册';

  @override
  String get authLoggingInOrRegistering => '登录/注册中…';

  @override
  String get authCaptchaKeyReady => '人机验证已通过';

  @override
  String get authSmsCode => '短信验证码';

  @override
  String get authSmsHintInitial => '完成人机验证后可发送短信验证码';

  @override
  String get authSmsHintFetching => '获取人机验证…';

  @override
  String get authSmsHintCompleteGee => '请完成人机验证，再发送短信';

  @override
  String get authSmsHintFetchFailed => '无法获取人机验证，请重试';

  @override
  String get authSmsHintSent => '短信已发送，请输入验证码完成登录/注册';

  @override
  String get authNeedCaptchaFirst => '请先完成人机验证';

  @override
  String get authCannotOpenGeePage => '无法打开验证页面，请手动完成极验后填入结果';

  @override
  String get authCannotOpenGeePageShort => '无法打开验证页面';

  @override
  String get authCopiedGeeParams => '验证参数已复制，完成验证后粘贴结果';

  @override
  String get authCopiedGeeParamsShort => '验证参数已复制';

  @override
  String get authNeedGeeValidate => '请填入验证结果';

  @override
  String get authCodeSent => '验证码已发送';

  @override
  String get authNeedSendSmsFirst => '请先发送短信验证码';

  @override
  String get authNeedSmsCode => '请输入短信验证码';

  @override
  String get authPwdIntro => '使用手机号或邮箱与密码登录。密码仅用于本次登录，不会保存在本机。';

  @override
  String get authUsername => '账号';

  @override
  String get authPassword => '密码';

  @override
  String get authLoggingIn => '登录中…';

  @override
  String get authPwdHintInitial => '完成人机验证后可登录';

  @override
  String get authPwdHintFetching => '获取人机验证…';

  @override
  String get authPwdHintCompleteGee => '请完成人机验证，再登录';

  @override
  String get authPwdHintFetchFailed => '无法获取人机验证，请重试';

  @override
  String get authQrIntro => '使用 bilibili 手机客户端扫码登录。二维码过期后可刷新。';

  @override
  String get authQrNotStarted => '未开始';

  @override
  String get authQrRequesting => '获取二维码…';

  @override
  String get authQrScanHint => '请使用手机客户端扫码';

  @override
  String get authQrRequestFailed => '无法获取二维码';

  @override
  String get authQrScanned => '已扫码，请在手机上确认';

  @override
  String get authQrExpired => '二维码已过期';

  @override
  String get authQrRefreshing => '刷新中…';

  @override
  String get authQrTapRefresh => '刷新二维码';

  @override
  String get authQrReacquire => '刷新';

  @override
  String get authRiskTitle => '需要验证手机号';

  @override
  String get authRiskPhoneHint => '请使用绑定手机号完成短信验证';

  @override
  String get authRiskHintInitial => '完成人机验证后发送短信';

  @override
  String get authRiskHintFetching => '获取人机验证…';

  @override
  String get authRiskHintCompleteGee => '完成人机验证后发送验证码';

  @override
  String get authRiskHintFetchFailed => '无法获取人机验证，请重试';

  @override
  String get authRiskHintSent => '短信已发送，请输入验证码';

  @override
  String get authQrPanelTitle => '扫描二维码登录';

  @override
  String get authQrPanelHint => '请使用 bilibili 客户端扫码登录';

  @override
  String get authRegister => '注册';

  @override
  String get authForgotPassword => '忘记密码？';

  @override
  String get authAccountLabel => '账号';

  @override
  String get authAccountHint => '请输入账号';

  @override
  String get authPasswordHint => '请输入密码';

  @override
  String get authPhoneHint => '请输入手机号';

  @override
  String get authSmsCodeHint => '请输入验证码';

  @override
  String get authCaptchaSection => '人机验证';

  @override
  String get authTermsFooter => '短信登录与注册为同一流程：未注册手机号将自动创建账号。继续即表示同意用户协议与隐私政策。';

  @override
  String get authShowPassword => '显示密码';

  @override
  String get authHidePassword => '隐藏密码';

  @override
  String get authOpenExternalForgot => '在浏览器打开找回密码页';

  @override
  String get statLike => '点赞';

  @override
  String get statCoin => '投币';

  @override
  String get statFavorite => '收藏';

  @override
  String get statShare => '分享';

  @override
  String get statReply => '评论';

  @override
  String get statView => '播放';

  @override
  String get statDanmaku => '弹幕';

  @override
  String get follow => '关注';

  @override
  String get following => '已关注';

  @override
  String get followSuccess => '已关注';

  @override
  String get unfollowSuccess => '已取消关注';

  @override
  String get actionComingSoon => '即将支持';

  @override
  String get loginRequiredTitle => '需要登录';

  @override
  String get loginRequiredBody => '登录后即可点赞、投币、收藏、关注、发评论与弹幕';

  @override
  String get coinDialogTitle => '投币';

  @override
  String get coinOne => '投 1 枚';

  @override
  String get coinTwo => '投 2 枚';

  @override
  String get coinAlreadyMax => '已投满 2 枚硬币';

  @override
  String get favoriteAdded => '已收藏';

  @override
  String get favoriteRemoved => '已取消收藏';

  @override
  String get undo => '撤销';

  @override
  String get favFolderPickerTitle => '选择收藏夹';

  @override
  String get favFolderPickerHint => '勾选要加入的收藏夹；取消勾选将移出';

  @override
  String get favFolderPickerEmpty => '暂无收藏夹';

  @override
  String favFolderMediaCount(int count) {
    return '$count 个内容';
  }

  @override
  String get statFavoriteLongPress => '长按选择收藏夹';

  @override
  String get linkCopied => '链接已复制';

  @override
  String get videoRelated => '相关推荐';

  @override
  String get videoWatchTitle => '观看';

  @override
  String bootCoreFailed(String message) {
    return '无法启动 Core：\n$message';
  }
}
