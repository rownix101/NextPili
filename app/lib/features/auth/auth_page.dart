import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../bridge/core_api.dart';
import '../../core/adaptive/form_factor.dart';

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
  Timer? _pollTimer;

  // SMS
  final _telController = TextEditingController();
  final _codeController = TextEditingController();
  final _geeValidateController = TextEditingController();
  final _geeSeccodeController = TextEditingController();

  CaptchaDto? _captcha;
  String _loginSessionId = '';
  String? _captchaKey;
  String _smsHint = '完成人机验证后可发送短信验证码';
  int _cid = 1; // 中国大陆 passport country id

  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wantQr = supportsQrLogin(context);
    final len = wantQr ? 2 : 1;
    if (_tabs == null || _tabs!.length != len) {
      _tabs?.dispose();
      _tabs = TabController(length: len, vsync: this);
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tabs?.dispose();
    _telController.dispose();
    _codeController.dispose();
    _geeValidateController.dispose();
    _geeSeccodeController.dispose();
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
    setState(() {
      _busy = true;
      _qrStatus = '申请二维码…';
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
        _qrStatus = '等待扫码';
      });
      _pollTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
        _pollOnce();
      });
    } catch (e) {
      _toast(errorMessage(e));
      setState(() => _qrStatus = '申请失败');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pollOnce() async {
    final code = _authCode;
    if (code == null || code.isEmpty) return;
    try {
      final poll = await CoreApi.instance.loginQrPoll(authCode: code);
      if (!mounted) return;
      setState(() => _qrStatus = poll.message);
      switch (poll.status) {
        case QrStatusKind.confirmed:
          _pollTimer?.cancel();
          _refreshAccounts();
          _toast('登录成功：${poll.account?.name ?? ''}');
        case QrStatusKind.expired:
        case QrStatusKind.error:
          _pollTimer?.cancel();
        case QrStatusKind.pending:
        case QrStatusKind.scanned:
          break;
      }
    } catch (e) {
      _pollTimer?.cancel();
      if (mounted) {
        setState(() => _qrStatus = errorMessage(e));
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
    final showQr = supportsQrLogin(context);
    final tabs = _tabs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('账号与登录'),
        bottom: tabs == null
            ? null
            : TabBar(
                controller: tabs,
                tabs: [
                  const Tab(text: '短信登录'),
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
                      if (showQr)
                        _QrTab(
                          busy: _busy,
                          qrUrl: _qrUrl,
                          status: _qrStatus,
                          onStart: _startQr,
                          onCopyUrl: _qrUrl == null
                              ? null
                              : () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: _qrUrl!),
                                  );
                                  _toast('已复制登录 URL');
                                },
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Text('已保存账号', style: theme.textTheme.titleMedium),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _refreshAccounts,
                        icon: const Icon(Icons.refresh, size: 18),
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
                              trailing: IconButton(
                                icon: const Icon(Icons.logout),
                                onPressed: () => _logout(a.id),
                              ),
                            );
                          },
                        ),
                ),
                if (!showQr)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '手机端仅提供短信登录；扫码登录在桌面 / 平板可用',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '设备 buvid3：${_safeBuvid()}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          '使用手机号 + 短信验证码登录。凭据保存在本机 Rust 数据目录，不会在设置里粘贴 Cookie。',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            SizedBox(
              width: 140,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: '区号',
                  border: OutlineInputBorder(),
                ),
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
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: telController,
                enabled: !busy,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: '手机号',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(hint, style: theme.textTheme.bodySmall),
        if (captcha != null) ...[
          const SizedBox(height: 8),
          SelectableText(
            'gt: ${captcha!.gt}\nchallenge: ${captcha!.challenge}',
            style: const TextStyle(fontSize: 12),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: busy ? null : onPrepareCaptcha,
              icon: const Icon(Icons.shield_outlined),
              label: const Text('获取人机验证'),
            ),
            OutlinedButton.icon(
              onPressed: busy || captcha == null ? null : onOpenGee,
              icon: const Icon(Icons.open_in_new),
              label: const Text('打开极验助手'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: geeValidateController,
          enabled: !busy,
          decoration: const InputDecoration(
            labelText: 'gee_validate',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: geeSeccodeController,
          enabled: !busy,
          decoration: const InputDecoration(
            labelText: 'gee_seccode（可留空，默认 validate|jordan）',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: busy ? null : onSendSms,
          icon: const Icon(Icons.sms_outlined),
          label: Text(busy ? '处理中…' : '发送短信验证码'),
        ),
        if (captchaKey != null) ...[
          const SizedBox(height: 8),
          Text(
            'captcha_key 已就绪',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: codeController,
          enabled: !busy,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '短信验证码',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: busy ? null : onLogin,
          icon: const Icon(Icons.login),
          label: const Text('登录'),
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
    required this.onStart,
    required this.onCopyUrl,
  });

  final bool busy;
  final String? qrUrl;
  final String status;
  final VoidCallback onStart;
  final VoidCallback? onCopyUrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '桌面 / 平板可用：TV/HD 扫码登录。手机端请使用短信登录。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: busy ? null : onStart,
            icon: const Icon(Icons.qr_code_2),
            label: Text(busy ? '处理中…' : '获取二维码'),
          ),
          const SizedBox(height: 12),
          Text('状态：$status'),
          if (qrUrl != null) ...[
            const SizedBox(height: 12),
            SelectableText(qrUrl!, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onCopyUrl,
              icon: const Icon(Icons.copy),
              label: const Text('复制登录 URL'),
            ),
          ],
        ],
      ),
    );
  }
}
