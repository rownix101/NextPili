import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../bridge/core_api.dart';
import '../../core/adaptive/form_factor.dart';
import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/spacing.dart';
import '../../core/widgets/np_button.dart';
import '../../core/widgets/page_header.dart';
import '../../l10n/l10n.dart';
import 'auth_login_panel.dart';
import 'dial_prefix.dart';
import 'geetest/geetest_result.dart';
import 'geetest/geetest_webview_dialog.dart';
import 'password_risk_dialog.dart';

class AccountsNotifier extends Notifier<List<AccountPublicDto>> {
  @override
  List<AccountPublicDto> build() {
    try {
      return CoreApi.instance.listAccounts();
    } catch (_) {
      return const [];
    }
  }

  void refresh() {
    state = CoreApi.instance.listAccounts();
  }
}

final accountsProvider =
    NotifierProvider<AccountsNotifier, List<AccountPublicDto>>(
  AccountsNotifier.new,
);

/// Passport URLs opened externally for flows we do not host in-app.
const _forgotPasswordUrl =
    'https://passport.bilibili.com/pc/passport/findPassword';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage>
    with SingleTickerProviderStateMixin {
  /// 0 = password, 1 = SMS (matches bilibili web order).
  TabController? _formTabs;

  // QR
  String? _qrUrl;
  String? _authCode;
  String _qrStatus = '';
  QrStatusKind? _qrKind;
  Timer? _pollTimer;
  bool _qrStarting = false;

  // SMS
  final _telController = TextEditingController();
  final _codeController = TextEditingController();
  String? _smsGeeChallenge;
  String? _smsGeeValidate;
  String? _smsGeeSeccode;

  // Password
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _pwdGeeChallenge;
  String? _pwdGeeValidate;
  String? _pwdGeeSeccode;
  CaptchaDto? _pwdCaptcha;
  String _pwdHint = '';
  bool _obscurePassword = true;

  CaptchaDto? _captcha;
  String _loginSessionId = '';
  String? _captchaKey;
  String _smsHint = '';
  /// App SMS `cid` = dialing code (PiliPlus / bilibili App); mainland = 86.
  DialPrefix _dial = kDialPrefixes.first;

  bool _busy = false;
  bool _hintsReady = false;
  bool _qrBootstrapped = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hintsReady) {
      final l10n = context.l10n;
      _qrStatus = l10n.authQrPanelHint;
      _pwdHint = l10n.authPwdHintInitial;
      _smsHint = l10n.authSmsHintInitial;
      _hintsReady = true;
    }
    _formTabs ??= TabController(length: 2, vsync: this);
    if (supportsQrLogin(context) && !_qrBootstrapped) {
      _qrBootstrapped = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ensureQr();
      });
    }
  }

  void _ensureQr() {
    if (_qrStarting || _busy) return;
    if (_qrUrl != null &&
        _qrKind != QrStatusKind.expired &&
        _qrKind != QrStatusKind.error &&
        _qrKind != QrStatusKind.confirmed) {
      return;
    }
    unawaited(_startQr());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _formTabs?.dispose();
    _telController.dispose();
    _codeController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _refreshAccounts() {
    try {
      ref.read(accountsProvider.notifier).refresh();
    } catch (e) {
      _toast(errorMessage(e, context.l10n));
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openExternal(String url, String failToast) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!mounted) return;
    if (!ok) _toast(failToast);
  }

  Future<void> _startQr() async {
    if (_qrStarting) return;
    setState(() {
      _qrStarting = true;
      _busy = true;
      _qrStatus = context.l10n.authQrRequesting;
      _qrKind = null;
      _qrUrl = null;
      _authCode = null;
    });
    _pollTimer?.cancel();
    try {
      final start = await CoreApi.instance.loginQrStart();
      if (!mounted) return;
      setState(() {
        _qrUrl = start.url;
        _authCode = start.authCode;
        _qrStatus = context.l10n.authQrScanHint;
        _qrKind = QrStatusKind.pending;
      });
      _pollTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
        _pollOnce();
      });
    } catch (e) {
      _toast(errorMessage(e, context.l10n));
      if (mounted) {
        setState(() {
          _qrStatus = context.l10n.authQrRequestFailed;
          _qrKind = QrStatusKind.error;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _qrStarting = false;
        });
      }
    }
  }

  Future<void> _pollOnce() async {
    final code = _authCode;
    if (code == null || code.isEmpty) return;
    try {
      final poll = await CoreApi.instance.loginQrPoll(authCode: code);
      if (!mounted) return;
      setState(() {
        final l10n = context.l10n;
        _qrStatus = switch (poll.status) {
          QrStatusKind.pending => l10n.authQrScanHint,
          QrStatusKind.scanned => l10n.authQrScanned,
          QrStatusKind.confirmed => l10n.authLoginSuccess,
          QrStatusKind.expired => l10n.authQrExpired,
          QrStatusKind.error => poll.message,
        };
        _qrKind = poll.status;
      });
      switch (poll.status) {
        case QrStatusKind.confirmed:
          _pollTimer?.cancel();
          _refreshAccounts();
          _toast(context.l10n.authLoginSuccessNamed(poll.account?.name ?? ''));
        case QrStatusKind.expired:
          _pollTimer?.cancel();
          unawaited(_startQr());
        case QrStatusKind.error:
          _pollTimer?.cancel();
        case QrStatusKind.pending:
        case QrStatusKind.scanned:
          break;
      }
    } catch (e) {
      _pollTimer?.cancel();
      if (mounted) {
        setState(() {
          _qrStatus = errorMessage(e, context.l10n);
          _qrKind = QrStatusKind.error;
        });
      }
    }
  }

  Future<GeetestResult?> _runGeetest(String gt, String challenge) {
    return GeetestWebviewDialog.show(
      context: context,
      gt: gt,
      challenge: challenge,
    );
  }

  /// Fetch captcha params + embedded GeeTest (PiliPlus-style).
  Future<void> _solveSmsCaptcha() async {
    setState(() {
      _busy = true;
      _smsHint = context.l10n.authSmsHintFetching;
    });
    try {
      final captcha = await CoreApi.instance.loginCaptcha();
      final session = CoreApi.instance.newLoginSessionId();
      if (!mounted) return;
      setState(() {
        _captcha = captcha;
        _loginSessionId = session;
        _captchaKey = null;
        _smsGeeChallenge = null;
        _smsGeeValidate = null;
        _smsGeeSeccode = null;
        _smsHint = context.l10n.authSmsHintCompleteGee;
      });
      final result = await _runGeetest(captcha.gt, captcha.challenge);
      if (!mounted) return;
      if (result == null) {
        setState(() => _smsHint = context.l10n.authSmsHintCompleteGee);
        return;
      }
      setState(() {
        _smsGeeChallenge = result.challenge;
        _smsGeeValidate = result.validate;
        _smsGeeSeccode = result.seccode;
        _smsHint = context.l10n.authCaptchaKeyReady;
      });
      _toast(context.l10n.authCaptchaKeyReady);
    } catch (e) {
      _toast(errorMessage(e, context.l10n));
      if (mounted) {
        setState(() => _smsHint = context.l10n.authSmsHintFetchFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendSms() async {
    final tel = _telController.text.trim();
    var captcha = _captcha;
    var validate = _smsGeeValidate;
    var seccode = _smsGeeSeccode;
    var challenge = _smsGeeChallenge;

    if (captcha == null ||
        validate == null ||
        validate.isEmpty ||
        seccode == null ||
        seccode.isEmpty) {
      await _solveSmsCaptcha();
      captcha = _captcha;
      validate = _smsGeeValidate;
      seccode = _smsGeeSeccode;
      challenge = _smsGeeChallenge;
      if (captcha == null ||
          validate == null ||
          validate.isEmpty ||
          seccode == null ||
          seccode.isEmpty) {
        return;
      }
    }

    setState(() => _busy = true);
    try {
      final result = await CoreApi.instance.loginSmsSend(
        SmsSendDto(
          cid: _dial.countryId,
          tel: tel,
          token: captcha.token,
          geeChallenge: challenge ?? captcha.challenge,
          geeValidate: validate,
          geeSeccode: seccode,
          loginSessionId: _loginSessionId,
        ),
      );
      if (!mounted) return;
      setState(() {
        _captchaKey = result.captchaKey;
        _loginSessionId = result.loginSessionId;
        _smsHint = context.l10n.authSmsHintSent;
      });
      _toast(context.l10n.authCodeSent);
    } catch (e) {
      _toast(errorMessage(e, context.l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loginSms() async {
    final key = _captchaKey;
    if (key == null || key.isEmpty) {
      _toast(context.l10n.authNeedSendSmsFirst);
      return;
    }
    setState(() => _busy = true);
    try {
      final acc = await CoreApi.instance.loginSms(
        SmsLoginDto(
          cid: _dial.countryId,
          tel: _telController.text.trim(),
          code: _codeController.text.trim(),
          captchaKey: key,
          loginSessionId: _loginSessionId,
        ),
      );
      if (!mounted) return;
      _refreshAccounts();
      _toast(context.l10n.authLoginSuccessNamed(acc.name));
      _codeController.clear();
    } catch (e) {
      _toast(errorMessage(e, context.l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _solvePwdCaptcha() async {
    setState(() {
      _busy = true;
      _pwdHint = context.l10n.authPwdHintFetching;
    });
    try {
      final captcha = await CoreApi.instance.loginCaptcha();
      if (!mounted) return;
      setState(() {
        _pwdCaptcha = captcha;
        _pwdGeeChallenge = null;
        _pwdGeeValidate = null;
        _pwdGeeSeccode = null;
        _pwdHint = context.l10n.authPwdHintCompleteGee;
      });
      final result = await _runGeetest(captcha.gt, captcha.challenge);
      if (!mounted) return;
      if (result == null) {
        setState(() => _pwdHint = context.l10n.authPwdHintCompleteGee);
        return;
      }
      setState(() {
        _pwdGeeChallenge = result.challenge;
        _pwdGeeValidate = result.validate;
        _pwdGeeSeccode = result.seccode;
        _pwdHint = context.l10n.authCaptchaKeyReady;
      });
      _toast(context.l10n.authCaptchaKeyReady);
    } catch (e) {
      _toast(errorMessage(e, context.l10n));
      if (mounted) {
        setState(() => _pwdHint = context.l10n.authPwdHintFetchFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loginPassword() async {
    var captcha = _pwdCaptcha;
    var validate = _pwdGeeValidate;
    var seccode = _pwdGeeSeccode;
    var challenge = _pwdGeeChallenge;

    if (captcha == null ||
        validate == null ||
        validate.isEmpty ||
        seccode == null ||
        seccode.isEmpty) {
      await _solvePwdCaptcha();
      captcha = _pwdCaptcha;
      validate = _pwdGeeValidate;
      seccode = _pwdGeeSeccode;
      challenge = _pwdGeeChallenge;
      if (captcha == null ||
          validate == null ||
          validate.isEmpty ||
          seccode == null ||
          seccode.isEmpty) {
        return;
      }
    }

    setState(() => _busy = true);
    try {
      final result = await CoreApi.instance.loginPassword(
        PasswordLoginDto(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          token: captcha.token,
          geeChallenge: challenge ?? captcha.challenge,
          geeValidate: validate,
          geeSeccode: seccode,
        ),
      );
      if (!mounted) return;
      switch (result.kind) {
        case PasswordLoginResultKind.success:
          final acc = result.account;
          _refreshAccounts();
          _toast(context.l10n.authLoginSuccessNamed(acc?.name ?? ''));
          _passwordController.clear();
          setState(() => _pwdHint = context.l10n.authLoginSuccess);
        case PasswordLoginResultKind.needPhoneVerify:
          final risk = result.risk;
          if (risk == null) {
            _toast(result.message);
            return;
          }
          setState(() => _pwdHint = result.message);
          final acc = await showPasswordRiskDialog(
            context: context,
            risk: risk,
            message: result.message,
          );
          if (!mounted) return;
          if (acc != null) {
            _refreshAccounts();
            _toast(context.l10n.authLoginSuccessNamed(acc.name));
            _passwordController.clear();
            setState(() => _pwdHint = context.l10n.authLoginSuccess);
          }
      }
    } catch (e) {
      _toast(errorMessage(e, context.l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _logout(String? id) {
    try {
      CoreApi.instance.logout(accountId: id);
      _refreshAccounts();
      _toast(context.l10n.authLoggedOut);
    } catch (e) {
      _toast(errorMessage(e, context.l10n));
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final showQr = supportsQrLogin(context);
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 840;
    final formTabs = _formTabs;
    final pagePadH = AppSpacing.pagePaddingH(width);
    final smsGeeReady =
        _smsGeeValidate != null && _smsGeeValidate!.isNotEmpty;
    final pwdGeeReady =
        _pwdGeeValidate != null && _pwdGeeValidate!.isNotEmpty;

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: PageHeader(
        title: l10n.authTitle,
        showBack: true,
      ),
      body: formTabs == null
          ? const SizedBox.shrink()
          : LayoutBuilder(
              builder: (context, constraints) {
                final panelMaxW = showQr && wide ? 900.0 : 480.0;
                final panelH = showQr && wide
                    ? 520.0
                    : (showQr ? 720.0 : 540.0);

                return ListView(
                  padding: EdgeInsets.fromLTRB(
                    pagePadH,
                    AppSpacing.md,
                    pagePadH,
                    AppSpacing.lg,
                  ),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: panelMaxW),
                        child: SizedBox(
                          height: panelH,
                          child: AuthLoginPanel(
                            showQr: showQr,
                            wide: wide,
                            formTabController: formTabs,
                            busy: _busy && !_qrStarting,
                            qrBusy: _busy || _qrStarting,
                            qrUrl: _qrUrl,
                            qrStatus: _qrStatus,
                            qrKind: _qrKind,
                            onRefreshQr: _startQr,
                            usernameController: _usernameController,
                            passwordController: _passwordController,
                            obscurePassword: _obscurePassword,
                            onToggleObscure: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            pwdCaptcha: _pwdCaptcha,
                            pwdGeeReady: pwdGeeReady,
                            pwdHint: _pwdHint,
                            onSolvePwdCaptcha: _solvePwdCaptcha,
                            onPasswordLogin: _loginPassword,
                            onRegister: () => formTabs.animateTo(1),
                            onForgotPassword: () => _openExternal(
                              _forgotPasswordUrl,
                              l10n.authOpenExternalForgot,
                            ),
                            telController: _telController,
                            codeController: _codeController,
                            smsCaptcha: _captcha,
                            smsGeeReady: smsGeeReady,
                            captchaKey: _captchaKey,
                            smsHint: _smsHint,
                            dial: _dial,
                            onDialChanged: (v) => setState(() => _dial = v),
                            onSolveSmsCaptcha: _solveSmsCaptcha,
                            onSendSms: _sendSms,
                            onSmsLogin: _loginSms,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: panelMaxW),
                        child: _AccountsSection(
                          accounts: accounts,
                          onRefresh: _refreshAccounts,
                          onLogout: _logout,
                          showMobileHint: !showQr,
                          buvid: _safeBuvid(),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  String _safeBuvid() {
    try {
      final b = CoreApi.instance.deviceBuvid3();
      if (b.length <= 12) return b;
      return '${b.substring(0, 8)}…${b.substring(b.length - 5)}';
    } catch (_) {
      return '—';
    }
  }
}

class _AccountsSection extends StatelessWidget {
  const _AccountsSection({
    required this.accounts,
    required this.onRefresh,
    required this.onLogout,
    required this.showMobileHint,
    required this.buvid,
  });

  final List<AccountPublicDto> accounts;
  final VoidCallback onRefresh;
  final void Function(String? id) onLogout;
  final bool showMobileHint;
  final String buvid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final l10n = context.l10n;

    return Material(
      color: colors.elevated,
      borderRadius: AppShapes.borderLg,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppShapes.borderLg,
          border: Border.all(color: colors.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Text(
                    l10n.authSavedAccounts,
                    style: theme.textTheme.titleSmall,
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: onRefresh,
                    icon: const Icon(AppIcons.refresh, size: 16),
                    label: Text(l10n.refresh),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.borderSubtle),
            if (accounts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Center(
                  child: Text(
                    l10n.authNoAccounts,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.fgSecondary,
                    ),
                  ),
                ),
              )
            else
              ...accounts.map((a) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colors.sunken,
                    child: Text(
                      a.name.isNotEmpty ? a.name.substring(0, 1) : '?',
                    ),
                  ),
                  title: Text(a.name),
                  subtitle: Text(
                    l10n.authAccountSubtitle(
                      '${a.mid}',
                      a.isLogin
                          ? l10n.authAccountLoggedIn
                          : l10n.authAccountInvalid,
                    ),
                  ),
                  trailing: NpIconButton(
                    icon: AppIcons.logout,
                    tooltip: l10n.logout,
                    onPressed: () => onLogout(a.id),
                  ),
                );
              }),
            if (showMobileHint)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: Text(
                  l10n.authMobileOnlyHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.fgSecondary,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Text(
                l10n.authDeviceBuvid(buvid),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.fgMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
