import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../bridge/core_api.dart';
import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/widgets/np_button.dart';

/// Safe-center phone verify dialog (PiliPlus-style) after password login risk.
Future<AccountPublicDto?> showPasswordRiskDialog({
  required BuildContext context,
  required PasswordRiskDto risk,
  required String message,
}) {
  return showDialog<AccountPublicDto>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _PasswordRiskDialog(risk: risk, message: message),
  );
}

class _PasswordRiskDialog extends StatefulWidget {
  const _PasswordRiskDialog({
    required this.risk,
    required this.message,
  });

  final PasswordRiskDto risk;
  final String message;

  @override
  State<_PasswordRiskDialog> createState() => _PasswordRiskDialogState();
}

class _PasswordRiskDialogState extends State<_PasswordRiskDialog> {
  final _geeValidateController = TextEditingController();
  final _geeSeccodeController = TextEditingController();
  final _smsCodeController = TextEditingController();

  CaptchaDto? _captcha;
  String? _captchaKey;
  String _hint = '完成人机验证后发送短信';
  bool _busy = false;

  @override
  void dispose() {
    _geeValidateController.dispose();
    _geeSeccodeController.dispose();
    _smsCodeController.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _prepareCaptcha() async {
    setState(() {
      _busy = true;
      _hint = '获取安全中心人机验证…';
    });
    try {
      final captcha = await CoreApi.instance.loginPasswordRiskCaptcha();
      if (!mounted) return;
      setState(() {
        _captcha = captcha;
        _geeValidateController.clear();
        _geeSeccodeController.clear();
        _hint = '完成极验后发送验证码';
      });
    } catch (e) {
      _toast(errorMessage(e));
      setState(() => _hint = '获取人机验证失败');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openGee() async {
    final c = _captcha;
    if (c == null) {
      _toast('请先获取人机验证参数');
      return;
    }
    final uri = Uri.parse('https://kuresaru.github.io/geetest-validator/');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      _toast('无法打开验证页面');
    } else {
      await Clipboard.setData(
        ClipboardData(
          text: 'gt=${c.gt}\nchallenge=${c.challenge}\ntoken=${c.token}',
        ),
      );
      _toast('已复制 gt/challenge/token');
    }
  }

  Future<void> _sendSms() async {
    var captcha = _captcha;
    if (captcha == null) {
      await _prepareCaptcha();
      captcha = _captcha;
      if (captcha == null) return;
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
      final res = await CoreApi.instance.loginPasswordRiskSendSms(
        PasswordRiskSendSmsDto(
          tmpToken: widget.risk.tmpToken,
          riskUrl: widget.risk.riskUrl,
          token: captcha.token,
          geeChallenge: captcha.challenge,
          geeValidate: validate,
          geeSeccode: seccode,
        ),
      );
      if (!mounted) return;
      setState(() {
        _captchaKey = res.captchaKey;
        _hint = '短信已发送，请输入验证码';
      });
      _toast('验证码已发送');
    } catch (e) {
      _toast(errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final key = _captchaKey;
    if (key == null || key.isEmpty) {
      _toast('请先发送短信验证码');
      return;
    }
    final code = _smsCodeController.text.trim();
    if (code.isEmpty) {
      _toast('请输入短信验证码');
      return;
    }
    setState(() => _busy = true);
    try {
      final acc = await CoreApi.instance.loginPasswordRiskVerify(
        PasswordRiskVerifyDto(
          code: code,
          tmpToken: widget.risk.tmpToken,
          requestId: widget.risk.requestId,
          source: widget.risk.source,
          captchaKey: key,
          riskUrl: widget.risk.riskUrl,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(acc);
    } catch (e) {
      _toast(errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final hideTel = widget.risk.hideTel;

    return AlertDialog(
      title: const Text('本次登录需要验证您的手机号', textAlign: TextAlign.center),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                hideTel.isEmpty ? '请使用绑定手机号完成短信验证' : hideTel,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              if (widget.message.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.fgSecondary,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Text(_hint, style: theme.textTheme.bodySmall),
              if (_captcha != null) ...[
                const SizedBox(height: AppSpacing.sm),
                SelectableText(
                  'gt: ${_captcha!.gt}\nchallenge: ${_captcha!.challenge}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: AppSpacing.md - 4),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                alignment: WrapAlignment.center,
                children: [
                  NpButton(
                    label: '获取人机验证',
                    icon: AppIcons.shield,
                    variant: NpButtonVariant.secondary,
                    onPressed: _busy ? null : _prepareCaptcha,
                  ),
                  NpButton(
                    label: '打开极验助手',
                    icon: AppIcons.externalLink,
                    variant: NpButtonVariant.secondary,
                    onPressed: _busy || _captcha == null ? null : _openGee,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md - 4),
              TextField(
                controller: _geeValidateController,
                enabled: !_busy,
                decoration: const InputDecoration(labelText: 'gee_validate'),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _geeSeccodeController,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'gee_seccode（可留空）',
                ),
              ),
              const SizedBox(height: AppSpacing.md - 4),
              NpButton(
                label: _busy ? '发送中…' : '发送验证码',
                icon: AppIcons.sms,
                loading: _busy,
                onPressed: _busy ? null : _sendSms,
              ),
              if (_captchaKey != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'captcha_key 已就绪',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.accent,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _smsCodeController,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(labelText: '短信验证码'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(
            '取消',
            style: TextStyle(color: colors.fgSecondary),
          ),
        ),
        TextButton(
          onPressed: _busy ? null : _verify,
          child: const Text('确认'),
        ),
      ],
    );
  }
}
