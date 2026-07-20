// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'NextPili';

  @override
  String get retry => 'Retry';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get done => 'Done';

  @override
  String get back => 'Back';

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get refresh => 'Refresh';

  @override
  String get loadMore => 'Load more';

  @override
  String get noMore => 'No more';

  @override
  String get login => 'Sign in';

  @override
  String get logout => 'Sign out';

  @override
  String get user => 'User';

  @override
  String get live => 'Live';

  @override
  String get account => 'Account';

  @override
  String get goLogin => 'Sign in';

  @override
  String get emptyContent => 'Nothing here yet\nPull to refresh';

  @override
  String get loading => 'Loading…';

  @override
  String get loadFailed => 'Couldn’t load';

  @override
  String get errorNetworkUnavailable =>
      'Network unavailable. Check your connection and try again.';

  @override
  String get errorSessionExpired => 'Session expired. Sign in again.';

  @override
  String get errorCsrf => 'Security check failed. Try again.';

  @override
  String get errorRiskControl => 'This action is restricted. Try again later.';

  @override
  String get errorNotFound => 'This content is unavailable.';

  @override
  String get errorRateLimited => 'Too many requests. Try again later.';

  @override
  String get errorGeneric => 'Something went wrong. Try again later.';

  @override
  String get errorPlayFailed => 'Can’t play this video. Try another quality.';

  @override
  String get errorPlayUrlFailed => 'Couldn’t get a playable stream.';

  @override
  String get playUrlFetching => 'Getting stream…';

  @override
  String get navHome => 'Home';

  @override
  String get navSearch => 'Search';

  @override
  String get navDynamics => 'Feed';

  @override
  String get navLibrary => 'Library';

  @override
  String get navSettings => 'Settings';

  @override
  String get dynamicsTitle => 'Following';

  @override
  String get dynamicsEmpty => 'No posts from people you follow';

  @override
  String get dynamicsNeedLogin => 'Sign in to see following updates';

  @override
  String get libraryTabHistory => 'History';

  @override
  String get libraryTabToview => 'Watch later';

  @override
  String get libraryTabFav => 'Favorites';

  @override
  String get libraryHistoryEmpty => 'No watch history yet';

  @override
  String get libraryToviewEmpty => 'Watch later is empty';

  @override
  String get libraryFavEmpty => 'No favorites yet';

  @override
  String get homeTabRecommend => 'For you';

  @override
  String get homeTabPopular => 'Popular';

  @override
  String get searchTitle => 'Search';

  @override
  String get searchHint => 'Search videos';

  @override
  String get searchIdle => 'Type a keyword to search';

  @override
  String get searchEmpty => 'No videos found';

  @override
  String searchResultHint(String keyword) {
    return 'Results for “$keyword”';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAccountTitle => 'Account & sign-in';

  @override
  String get settingsAccountSubtitle =>
      'Sign in / register · QR on desktop/tablet';

  @override
  String get settingsDefaultQuality => 'Default quality';

  @override
  String get settingsProxyTitle => 'HTTP proxy';

  @override
  String get settingsProxyHelper =>
      'Leave empty and save to clear; supports http / https / socks5';

  @override
  String get settingsProxySave => 'Save proxy';

  @override
  String get settingsQualityUpdated => 'Default quality updated';

  @override
  String get settingsProxyCleared => 'Proxy cleared';

  @override
  String get settingsProxySaved => 'Proxy saved';

  @override
  String settingsQnLabel(int qn) {
    return 'qn $qn';
  }

  @override
  String settingsQnWithLabel(String label, int qn) {
    return '$label · qn $qn';
  }

  @override
  String get qualityDolbyVision => 'Dolby Vision';

  @override
  String get videoDetailTitle => 'Video';

  @override
  String get videoDesc => 'Description';

  @override
  String get videoDescEmpty => 'No description';

  @override
  String videoPartsCount(int count) {
    return 'Parts ($count)';
  }

  @override
  String get videoPartsEmpty => 'No parts';

  @override
  String videoPartFallback(int page) {
    return 'P$page';
  }

  @override
  String get replyTitle => 'Comments';

  @override
  String replyTitleWithCount(int count) {
    return 'Comments ($count)';
  }

  @override
  String get replySortHeat => 'Top';

  @override
  String get replySortTime => 'Newest';

  @override
  String get replyEmpty => 'No comments yet';

  @override
  String replyChildrenCount(int count) {
    return '$count replies';
  }

  @override
  String get playerDanmakuOn => 'Show danmaku';

  @override
  String get playerDanmakuOff => 'Hide danmaku';

  @override
  String get playerDanmakuClosed => 'Danmaku off';

  @override
  String get playerQuality => 'Quality';

  @override
  String get playerFullscreen => 'Fullscreen';

  @override
  String get authTitle => 'Account & sign-in';

  @override
  String get authTabSms => 'Sign in / Register';

  @override
  String get authTabPassword => 'Password';

  @override
  String get authTabQr => 'QR code';

  @override
  String get authSavedAccounts => 'Saved accounts';

  @override
  String get authNoAccounts => 'No accounts';

  @override
  String get authAccountLoggedIn => 'Signed in';

  @override
  String get authAccountInvalid => 'Expired';

  @override
  String authAccountSubtitle(String mid, String status) {
    return 'mid $mid · $status';
  }

  @override
  String get authMobileOnlyHint =>
      'Phone: SMS / password; QR sign-in on desktop / tablet';

  @override
  String authDeviceBuvid(String buvid) {
    return 'Device buvid3: $buvid';
  }

  @override
  String get authLoggedOut => 'Signed out';

  @override
  String authLoginSuccessNamed(String name) {
    return 'Signed in as $name';
  }

  @override
  String get authLoginSuccess => 'Signed in';

  @override
  String get authVerify => 'Verify';

  @override
  String get authSmsIntro =>
      'Sign in or register with your phone number and SMS code. New numbers create an account automatically. Account data stays on this device.';

  @override
  String get authCountryCode => 'Country';

  @override
  String get authCountryChina => '+86 China';

  @override
  String get authPhone => 'Phone number';

  @override
  String get authGetCaptcha => 'Get captcha';

  @override
  String get authOpenGeeHelper => 'Open GeeTest helper';

  @override
  String get authGeeSeccodeOptionalDefault =>
      'gee_seccode (optional, default validate|jordan)';

  @override
  String get authGeeSeccodeOptional => 'gee_seccode (optional)';

  @override
  String get authSendSmsCode => 'Send SMS code';

  @override
  String get authSendCode => 'Send code';

  @override
  String get authSending => 'Sending…';

  @override
  String get authProcessing => 'Signing in…';

  @override
  String get authLoginOrRegister => 'Sign in / Register';

  @override
  String get authLoggingInOrRegistering => 'Signing in…';

  @override
  String get authCaptchaKeyReady => 'Captcha complete';

  @override
  String get authSmsCode => 'SMS code';

  @override
  String get authSmsHintInitial => 'Complete captcha to send SMS';

  @override
  String get authSmsHintFetching => 'Fetching captcha…';

  @override
  String get authSmsHintCompleteGee => 'Finish captcha, then send SMS';

  @override
  String get authSmsHintFetchFailed => 'Couldn’t get captcha. Try again.';

  @override
  String get authSmsHintSent =>
      'SMS sent — enter the code to sign in or register';

  @override
  String get authNeedCaptchaFirst => 'Complete captcha first';

  @override
  String get authCannotOpenGeePage =>
      'Could not open verification page; complete GeeTest manually';

  @override
  String get authCannotOpenGeePageShort => 'Could not open verification page';

  @override
  String get authCopiedGeeParams =>
      'Verification params copied — paste the result after verifying';

  @override
  String get authCopiedGeeParamsShort => 'Verification params copied';

  @override
  String get authNeedGeeValidate => 'Enter the captcha result';

  @override
  String get authCodeSent => 'Code sent';

  @override
  String get authNeedSendSmsFirst => 'Send SMS code first';

  @override
  String get authNeedSmsCode => 'Enter the SMS code';

  @override
  String get authPwdIntro =>
      'Sign in with phone or email and password. Password is used only for this sign-in and is never stored.';

  @override
  String get authUsername => 'Account';

  @override
  String get authPassword => 'Password';

  @override
  String get authLoggingIn => 'Signing in…';

  @override
  String get authPwdHintInitial => 'Complete captcha to sign in';

  @override
  String get authPwdHintFetching => 'Fetching captcha…';

  @override
  String get authPwdHintCompleteGee => 'Finish captcha, then sign in';

  @override
  String get authPwdHintFetchFailed => 'Couldn’t get captcha. Try again.';

  @override
  String get authQrIntro =>
      'Scan with the bilibili mobile app. Refresh if the code expires.';

  @override
  String get authQrNotStarted => 'Not started';

  @override
  String get authQrRequesting => 'Getting QR…';

  @override
  String get authQrScanHint => 'Scan with the mobile app';

  @override
  String get authQrRequestFailed => 'Couldn’t get QR code';

  @override
  String get authQrScanned => 'Scanned — confirm on phone';

  @override
  String get authQrExpired => 'QR expired';

  @override
  String get authQrRefreshing => 'Refreshing…';

  @override
  String get authQrTapRefresh => 'Refresh QR';

  @override
  String get authQrReacquire => 'Refresh';

  @override
  String get authRiskTitle => 'Verify your phone number';

  @override
  String get authRiskPhoneHint =>
      'Use the bound phone number for SMS verification';

  @override
  String get authRiskHintInitial => 'Complete captcha, then send SMS';

  @override
  String get authRiskHintFetching => 'Fetching captcha…';

  @override
  String get authRiskHintCompleteGee => 'Finish captcha, then send code';

  @override
  String get authRiskHintFetchFailed => 'Couldn’t get captcha. Try again.';

  @override
  String get authRiskHintSent => 'SMS sent — enter the code';

  @override
  String get authQrPanelTitle => 'Scan QR code';

  @override
  String get authQrPanelHint => 'Scan with the bilibili app to sign in';

  @override
  String get authRegister => 'Register';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authAccountLabel => 'Account';

  @override
  String get authAccountHint => 'Phone or email';

  @override
  String get authPasswordHint => 'Enter password';

  @override
  String get authPhoneHint => 'Phone number';

  @override
  String get authSmsCodeHint => 'SMS code';

  @override
  String get authCaptchaSection => 'Captcha';

  @override
  String get authTermsFooter =>
      'SMS is both sign-in and registration: new phone numbers create an account automatically. By continuing you agree to the Terms and Privacy Policy.';

  @override
  String get authShowPassword => 'Show password';

  @override
  String get authHidePassword => 'Hide password';

  @override
  String get authOpenExternalForgot => 'Open password recovery in browser';

  @override
  String get statLike => 'Like';

  @override
  String get statCoin => 'Coins';

  @override
  String get statFavorite => 'Favorites';

  @override
  String get statShare => 'Shares';

  @override
  String get statReply => 'Comments';

  @override
  String get statView => 'Views';

  @override
  String get statDanmaku => 'Danmaku';

  @override
  String get follow => 'Follow';

  @override
  String get following => 'Following';

  @override
  String get followSuccess => 'Followed';

  @override
  String get unfollowSuccess => 'Unfollowed';

  @override
  String get actionComingSoon => 'Coming soon';

  @override
  String get loginRequiredTitle => 'Sign in required';

  @override
  String get loginRequiredBody => 'Sign in to like, coin, favorite, or follow';

  @override
  String get coinDialogTitle => 'Cast coins';

  @override
  String get coinOne => '1 coin';

  @override
  String get coinTwo => '2 coins';

  @override
  String get coinAlreadyMax => 'Already cast 2 coins';

  @override
  String get favoriteAdded => 'Added to favorites';

  @override
  String get favoriteRemoved => 'Removed from favorites';

  @override
  String get undo => 'Undo';

  @override
  String get favFolderPickerTitle => 'Choose folders';

  @override
  String get favFolderPickerHint => 'Check folders to add; uncheck to remove';

  @override
  String get favFolderPickerEmpty => 'No favorite folders yet';

  @override
  String favFolderMediaCount(int count) {
    return '$count items';
  }

  @override
  String get statFavoriteLongPress => 'Long-press to choose folders';

  @override
  String get linkCopied => 'Link copied';

  @override
  String get videoRelated => 'Related';

  @override
  String get videoWatchTitle => 'Watch';

  @override
  String bootCoreFailed(String message) {
    return 'Could not start Core:\n$message';
  }
}
