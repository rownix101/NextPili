import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../bridge/core_api.dart';
import '../../core/adaptive/form_factor.dart';
import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/spacing.dart';
import '../../core/widgets/np_button.dart';
import '../../core/widgets/page_header.dart';
import 'password_risk_dialog.dart';

final accountsProvider = StateProvider<List<AccountPublicDto>>((ref) {
  try {
    return CoreApi.instance.listAccounts();
  } catch (_) {
    return const [];
  }
});

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage>
    with SingleTickerProviderStateMixin {
  TabController? _tabs;

  // QR
  String? _qrUrl;
  String? _authCode;
  String _qrStatus = '未开始';
  QrStatusKind? _qrKind;
  Timer? _pollTimer;
  bool _qrStarting = false;

  // SMS
  final _telController = TextEditingController();
  final _codeController = TextEditingController();
  final _geeValidateController = TextEditingController();
  final _geeSeccodeController = TextEditingController();

  // Password
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pwdGeeValidateController = TextEditingController();
  final _pwdGeeSeccodeController = TextEditingController();
  CaptchaDto? _pwdCaptcha;
  String _pwdHint = '完成人机验证后可登录';

  CaptchaDto? _captcha;
  String _loginSessionId = '';
  String? _captchaKey;
  String _smsHint = '完成人机验证后可发送短信验证码';
  int _cid = 1; // 中国大陆 passport country id

  bool _busy = false;

  int get _qrTabIndex => supportsQrLogin(context) ? 2 : -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wantQr = supportsQrLogin(context);
    final len = wantQr ? 3 : 2;
    if (_tabs == null || _tabs!.length != len) {
      _tabs?.removeListener(_onTabChanged);
      _tabs?.dispose();
      _tabs = TabController(length: len, vsync: this);
      _tabs!.addListener(_onTabChanged);
    }
  }

  void _onTabChanged() {
    final tabs = _tabs;
    if (tabs == null || tabs.indexIsChanging) return;
    if (_qrTabIndex >= 0 && tabs.index == _qrTabIndex) {
      _ensureQr();
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
    _tabs?.dispose();
    _telController.dispose();
    _codeController.dispose();
    _geeValidateController.dispose();
    _geeSeccodeController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _pwdGeeValidateController.dispose();
    _pwdGeeSeccodeController.dispose();
    super.dispose();
  }

  void _refreshAccounts() {
    try {
      ref.read(accountsProvider.notifier).state =
          CoreApi.instance.listAccounts();
    } catch (e) {
      _toast(errorMessage(e));
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _startQr() async {
    if (_qrStarting) return;
    setState(() {
      _qrStarting = true;
      _busy = true;
      _qrStatus = '申请二维码…';
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
        _qrStatus = '请使用手机客户端扫码';
        _qrKind = QrStatusKind.pending;
      });
      _pollTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
        _pollOnce();
      });
    } catch (e) {
      _toast(errorMessage(e));
      if (mounted) {
        setState(() {
          _qrStatus = '申请失败';
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
        _qrStatus = switch (poll.status) {
          QrStatusKind.pending => '请使用手机客户端扫码',
          QrStatusKind.scanned => '已扫码，请在手机上确认',
          QrStatusKind.confirmed => '登录成功',
          QrStatusKind.expired => '二维码已过期',
          QrStatusKind.error => poll.message,
        };
        _qrKind = poll.status;
      });
      switch (poll.status) {
        case QrStatusKind.confirmed:
          _pollTimer?.cancel();
          _refreshAccounts();
          _toast('登录成功：${poll.account?.name ?? ''}');
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
          _qrStatus = errorMessage(e);
          _qrKind = QrStatusKind.error;
        });
      }
    }
  }

  Future<void> _prepareCaptcha() async {
    setState(() {
      _busy = true;
      _smsHint = '获取人机验证参数…';
    });
    try {
      final captcha = await CoreApi.instance.loginCaptcha();
      final session = CoreApi.instance.newLoginSessionId();
      if (!mounted) return;
      setState(() {
        _captcha = captcha;
        _loginSessionId = session;
        _captchaKey = null;
        _geeValidateController.clear();
        _geeSeccodeController.clear();
        _smsHint = '请完成极验（gee_validate / gee_seccode），再发送短信';
      });
    } catch (e) {
      _toast(errorMessage(e));
      setState(() => _smsHint = '获取验证码失败');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openGeeValidator() async {
    final c = _captcha;
    if (c == null) {
      _toast('请先获取人机验证参数');
      return;
    }
    // Community geetest helper used by many third-party clients for desktop flows.
    final uri = Uri.parse(
      'https://kuresaru.github.io/geetest-validator/',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      _toast('无法打开验证页面，请手动完成极验后填入结果');
    } else {
      await Clipboard.setData(
        ClipboardData(
          text: 'gt=${c.gt}\nchallenge=${c.challenge}\ntoken=${c.token}',
        ),
      );
      _toast('已复制 gt/challenge/token，完成验证后粘贴 validate/seccode');
    }
  }

  Future<void> _sendSms() async {
    final tel = _telController.text.trim();
    final captcha = _captcha;
    if (captcha == null) {
      await _prepareCaptcha();
      return;
    }
    final validate = _geeValidateController.text.trim();
    final seccode = _geeSeccodeController.text.trim().isEmpty
        ? (validate.isEmpty ? '' : '$validate|jordan')
        : _geeSeccodeController.text.trim();
    if (validate.isEmpty) {
      _toast('请填入 gee_validate');
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await CoreApi.instance.loginSmsSend(
        SmsSendDto(
          cid: _cid,
          tel: tel,
          token: captcha.token,
          geeChallenge: captcha.challenge,
          geeValidate: validate,
          geeSeccode: seccode,
          loginSessionId: _loginSessionId,
        ),
      );
      if (!mounted) return;
      setState(() {
        _captchaKey = result.captchaKey;
        _loginSessionId = result.loginSessionId;
        _smsHint = '短信已发送，请输入验证码登录';
      });
      _toast('验证码已发送');
    } catch (e) {
      _toast(errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loginSms() async {
    final key = _captchaKey;
    if (key == null || key.isEmpty) {
      _toast('请先发送短信验证码');
      return;
    }
    setState(() => _busy = true);
    try {
      final acc = await CoreApi.instance.loginSms(
        SmsLoginDto(
          cid: _cid,
          tel: _telController.text.trim(),
          code: _codeController.text.trim(),
          captchaKey: key,
          loginSessionId: _loginSessionId,
        ),
      );
      _refreshAccounts();
      _toast('登录成功：${acc.name}');
      _codeController.clear();
    } catch (e) {
      _toast(errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _preparePwdCaptcha() async {
    setState(() {
      _busy = true;
      _pwdHint = '获取人机验证参数…';
    });
    try {
      final captcha = await CoreApi.instance.loginCaptcha();
      if (!mounted) return;
      setState(() {
        _pwdCaptcha = captcha;
        _pwdGeeValidateController.clear();
        _pwdGeeSeccodeController.clear();
        _pwdHint = '请完成极验（gee_validate / gee_seccode），再登录';
      });
    } catch (e) {
      _toast(errorMessage(e));
      setState(() => _pwdHint = '获取验证码失败');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openPwdGeeValidator() async {
    final c = _pwdCaptcha;
    if (c == null) {
      _toast('请先获取人机验证参数');
      return;
    }
    final uri = Uri.parse('https://kuresaru.github.io/geetest-validator/');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      _toast('无法打开验证页面，请手动完成极验后填入结果');
    } else {
      await Clipboard.setData(
        ClipboardData(
          text: 'gt=${c.gt}\nchallenge=${c.challenge}\ntoken=${c.token}',
        ),
      );
      _toast('已复制 gt/challenge/token，完成验证后粘贴 validate/seccode');
    }
  }

  Future<void> _loginPassword() async {
    final captcha = _pwdCaptcha;
    if (captcha == null) {
      await _preparePwdCaptcha();
      return;
    }
    final validate = _pwdGeeValidateController.text.trim();
    final seccode = _pwdGeeSeccodeController.text.trim().isEmpty
        ? (validate.isEmpty ? '' : '$validate|jordan')
        : _pwdGeeSeccodeController.text.trim();
    if (validate.isEmpty) {
      _toast('请填入 gee_validate');
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await CoreApi.instance.loginPassword(
        PasswordLoginDto(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          token: captcha.token,
          geeChallenge: captcha.challenge,
          geeValidate: validate,
          geeSeccode: seccode,
        ),
      );
      if (!mounted) return;
      switch (result.kind) {
        case PasswordLoginResultKind.success:
          final acc = result.account;
          _refreshAccounts();
          _toast('登录成功：${acc?.name ?? ''}');
          _passwordController.clear();
          setState(() => _pwdHint = '登录成功');
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
            _toast('登录成功：${acc.name}');
            _passwordController.clear();
            setState(() => _pwdHint = '登录成功');
          }
      }
    } catch (e) {
      _toast(errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _logout(String? id) {
    try {
      CoreApi.instance.logout(accountId: id);
      _refreshAccounts();
      _toast('已退出');
    } catch (e) {
      _toast(errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final showQr = supportsQrLogin(context);
    final tabs = _tabs;

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: PageHeader(
        title: '账号与登录',
        showBack: true,
        bottom: tabs == null
            ? null
            : TabBar(
                controller: tabs,
                tabs: [
                  const Tab(text: '短信登录'),
                  const Tab(text: '密码登录'),
                  if (showQr) const Tab(text: '扫码登录'),
                ],
              ),
      ),
      body: tabs == null
          ? const SizedBox.shrink()
          : Column(
              children: [
                Expanded(
                  child: TabBarView(
                    controller: tabs,
                    children: [
                      _SmsTab(
                        busy: _busy,
                        telController: _telController,
                        codeController: _codeController,
                        geeValidateController: _geeValidateController,
                        geeSeccodeController: _geeSeccodeController,
                        captcha: _captcha,
                        captchaKey: _captchaKey,
                        hint: _smsHint,
                        cid: _cid,
                        onCidChanged: (v) => setState(() => _cid = v),
                        onPrepareCaptcha: _prepareCaptcha,
                        onOpenGee: _openGeeValidator,
                        onSendSms: _sendSms,
                        onLogin: _loginSms,
                      ),
                      _PasswordTab(
                        busy: _busy,
                        usernameController: _usernameController,
                        passwordController: _passwordController,
                        geeValidateController: _pwdGeeValidateController,
                        geeSeccodeController: _pwdGeeSeccodeController,
                        captcha: _pwdCaptcha,
                        hint: _pwdHint,
                        onPrepareCaptcha: _preparePwdCaptcha,
                        onOpenGee: _openPwdGeeValidator,
                        onLogin: _loginPassword,
                      ),
                      if (showQr)
                        _QrTab(
                          busy: _busy || _qrStarting,
                          qrUrl: _qrUrl,
                          status: _qrStatus,
                          statusKind: _qrKind,
                          onRefresh: _startQr,
                        ),
                    ],
                  ),
                ),
                Divider(height: 1, color: colors.borderSubtle),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md - 4,
                    AppSpacing.md,
                    AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      Text('已保存账号', style: theme.textTheme.titleMedium),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _refreshAccounts,
                        icon: const Icon(AppIcons.refresh, size: 18),
                        label: const Text('刷新'),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 140,
                  child: accounts.isEmpty
                      ? const Center(child: Text('暂无账号'))
                      : ListView.builder(
                          itemCount: accounts.length,
                          itemBuilder: (context, i) {
                            final a = accounts[i];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: colors.sunken,
                                child: Text(
                                  a.name.isNotEmpty
                                      ? a.name.substring(0, 1)
                                      : '?',
                                ),
                              ),
                              title: Text(a.name),
                              subtitle: Text(
                                'mid ${a.mid} · ${a.isLogin ? "已登录" : "失效"}',
                              ),
                              trailing: NpIconButton(
                                icon: AppIcons.logout,
                                tooltip: '退出',
                                onPressed: () => _logout(a.id),
                              ),
                            );
                          },
                        ),
                ),
                if (!showQr)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text(
                      '手机端：短信 / 密码；扫码登录在桌面 / 平板可用',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.fgSecondary,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md - 4),
                  child: Text(
                    '设备 buvid3：${_safeBuvid()}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.fgSecondary,
                    ),
                  ),
                ),
              ],
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

class _SmsTab extends StatelessWidget {
  const _SmsTab({
    required this.busy,
    required this.telController,
    required this.codeController,
    required this.geeValidateController,
    required this.geeSeccodeController,
    required this.captcha,
    required this.captchaKey,
    required this.hint,
    required this.cid,
    required this.onCidChanged,
    required this.onPrepareCaptcha,
    required this.onOpenGee,
    required this.onSendSms,
    required this.onLogin,
  });

  final bool busy;
  final TextEditingController telController;
  final TextEditingController codeController;
  final TextEditingController geeValidateController;
  final TextEditingController geeSeccodeController;
  final CaptchaDto? captcha;
  final String? captchaKey;
  final String hint;
  final int cid;
  final ValueChanged<int> onCidChanged;
  final VoidCallback onPrepareCaptcha;
  final VoidCallback onOpenGee;
  final VoidCallback onSendSms;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          '使用手机号 + 短信验证码登录。凭据保存在本机 Rust 数据目录，不会在设置里粘贴 Cookie。',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            SizedBox(
              width: 140,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: '区号'),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: cid,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('+86 中国')),
                    ],
                    onChanged: busy
                        ? null
                        : (v) {
                            if (v != null) onCidChanged(v);
                          },
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md - 4),
            Expanded(
              child: TextField(
                controller: telController,
                enabled: !busy,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: '手机号'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md - 4),
        Text(hint, style: theme.textTheme.bodySmall),
        if (captcha != null) ...[
          const SizedBox(height: AppSpacing.sm),
          SelectableText(
            'gt: ${captcha!.gt}\nchallenge: ${captcha!.challenge}',
            style: theme.textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: AppSpacing.md - 4),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            NpButton(
              label: '获取人机验证',
              icon: AppIcons.shield,
              variant: NpButtonVariant.secondary,
              onPressed: busy ? null : onPrepareCaptcha,
            ),
            NpButton(
              label: '打开极验助手',
              icon: AppIcons.externalLink,
              variant: NpButtonVariant.secondary,
              onPressed: busy || captcha == null ? null : onOpenGee,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md - 4),
        TextField(
          controller: geeValidateController,
          enabled: !busy,
          decoration: const InputDecoration(labelText: 'gee_validate'),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: geeSeccodeController,
          enabled: !busy,
          decoration: const InputDecoration(
            labelText: 'gee_seccode（可留空，默认 validate|jordan）',
          ),
        ),
        const SizedBox(height: AppSpacing.md - 4),
        NpButton(
          label: busy ? '处理中…' : '发送短信验证码',
          icon: AppIcons.sms,
          loading: busy,
          onPressed: busy ? null : onSendSms,
        ),
        if (captchaKey != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'captcha_key 已就绪',
            style: theme.textTheme.bodySmall?.copyWith(color: colors.accent),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: codeController,
          enabled: !busy,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '短信验证码'),
        ),
        const SizedBox(height: AppSpacing.md - 4),
        NpButton(
          label: '登录',
          icon: AppIcons.login,
          variant: NpButtonVariant.secondary,
          onPressed: busy ? null : onLogin,
        ),
      ],
    );
  }
}

class _PasswordTab extends StatelessWidget {
  const _PasswordTab({
    required this.busy,
    required this.usernameController,
    required this.passwordController,
    required this.geeValidateController,
    required this.geeSeccodeController,
    required this.captcha,
    required this.hint,
    required this.onPrepareCaptcha,
    required this.onOpenGee,
    required this.onLogin,
  });

  final bool busy;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final TextEditingController geeValidateController;
  final TextEditingController geeSeccodeController;
  final CaptchaDto? captcha;
  final String hint;
  final VoidCallback onPrepareCaptcha;
  final VoidCallback onOpenGee;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          '使用手机号或邮箱 + 密码登录。密码仅用于本次请求，经 RSA 加密后提交，不会落盘。',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: usernameController,
          enabled: !busy,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.username],
          decoration: const InputDecoration(labelText: '账号（手机号 / 邮箱）'),
        ),
        const SizedBox(height: AppSpacing.md - 4),
        TextField(
          controller: passwordController,
          enabled: !busy,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          decoration: const InputDecoration(labelText: '密码'),
        ),
        const SizedBox(height: AppSpacing.md - 4),
        Text(hint, style: theme.textTheme.bodySmall),
        if (captcha != null) ...[
          const SizedBox(height: AppSpacing.sm),
          SelectableText(
            'gt: ${captcha!.gt}\nchallenge: ${captcha!.challenge}',
            style: theme.textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: AppSpacing.md - 4),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            NpButton(
              label: '获取人机验证',
              icon: AppIcons.shield,
              variant: NpButtonVariant.secondary,
              onPressed: busy ? null : onPrepareCaptcha,
            ),
            NpButton(
              label: '打开极验助手',
              icon: AppIcons.externalLink,
              variant: NpButtonVariant.secondary,
              onPressed: busy || captcha == null ? null : onOpenGee,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md - 4),
        TextField(
          controller: geeValidateController,
          enabled: !busy,
          decoration: const InputDecoration(labelText: 'gee_validate'),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: geeSeccodeController,
          enabled: !busy,
          decoration: const InputDecoration(
            labelText: 'gee_seccode（可留空，默认 validate|jordan）',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        NpButton(
          label: busy ? '登录中…' : '登录',
          icon: AppIcons.lock,
          loading: busy,
          onPressed: busy ? null : onLogin,
        ),
      ],
    );
  }
}

class _QrTab extends StatelessWidget {
  const _QrTab({
    required this.busy,
    required this.qrUrl,
    required this.status,
    required this.statusKind,
    required this.onRefresh,
  });

  final bool busy;
  final String? qrUrl;
  final String status;
  final QrStatusKind? statusKind;
  final VoidCallback onRefresh;

  static const double _qrSize = 220;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final expired = statusKind == QrStatusKind.expired;
    final failed = statusKind == QrStatusKind.error;
    final confirmed = statusKind == QrStatusKind.confirmed;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          '使用 bilibili 手机客户端扫码登录。二维码过期会自动刷新。',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: Tooltip(
            message: busy ? '刷新中…' : '点击刷新二维码',
            child: Material(
              color: Colors.white,
              borderRadius: AppShapes.borderMd,
              child: InkWell(
                borderRadius: AppShapes.borderMd,
                onTap: busy ? null : onRefresh,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: AppShapes.borderMd,
                    border: Border.all(color: colors.borderSubtle),
                  ),
                  child: SizedBox(
                    width: _qrSize + AppSpacing.lg * 2,
                    height: _qrSize + AppSpacing.lg * 2,
                    child: Center(child: _buildQrBody(colors)),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          status,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleSmall?.copyWith(
            color: confirmed
                ? colors.success
                : (expired || failed)
                    ? colors.error
                    : colors.fgPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: NpButton(
            label: busy
                ? '刷新中…'
                : (expired || failed || qrUrl == null)
                    ? '刷新'
                    : '重新获取',
            icon: AppIcons.refresh,
            loading: busy,
            variant: NpButtonVariant.secondary,
            onPressed: busy ? null : onRefresh,
          ),
        ),
      ],
    );
  }

  Widget _buildQrBody(AppColors colors) {
    if (busy && qrUrl == null) {
      return const SizedBox(
        width: 32,
        height: 32,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final url = qrUrl;
    if (url == null || url.isEmpty) {
      return Icon(AppIcons.qrCode, size: 48, color: colors.fgMuted);
    }
    return QrImageView(
      data: url,
      version: QrVersions.auto,
      size: _qrSize,
      backgroundColor: Colors.white,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Colors.black,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Colors.black,
      ),
    );
  }
}
