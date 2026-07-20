import 'package:flutter/material.dart';

import '../../bridge/core_api.dart';
import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/widgets/np_button.dart';
import '../../l10n/l10n.dart';
import 'geetest/geetest_webview_dialog.dart';

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
  final _smsCodeController = TextEditingController();

  CaptchaDto? _captcha;
  String? _geeChallenge;
  String? _geeValidate;
  String? _geeSeccode;
  String? _captchaKey;
  String _hint = '';
  bool _busy = false;
  bool _hintReady = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hintReady) {
      _hint = context.l10n.authRiskHintInitial;
      _hintReady = true;
    }
  }

  @override
  void dispose() {
    _smsCodeController.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _solveCaptcha() async {
    setState(() {
      _busy = true;
      _hint = context.l10n.authRiskHintFetching;
    });
    try {
      final captcha = await CoreApi.instance.loginPasswordRiskCaptcha();
      if (!mounted) return;
      setState(() {
        _captcha = captcha;
        _geeChallenge = null;
        _geeValidate = null;
        _geeSeccode = null;
        _hint = context.l10n.authRiskHintCompleteGee;
      });
      final result = await GeetestWebviewDialog.show(
        context: context,
        gt: captcha.gt,
        challenge: captcha.challenge,
      );
      if (!mounted) return;
      if (result == null) {
        setState(() => _hint = context.l10n.authRiskHintCompleteGee);
        return;
      }
      setState(() {
        _geeChallenge = result.challenge;
        _geeValidate = result.validate;
        _geeSeccode = result.seccode;
        _hint = context.l10n.authCaptchaKeyReady;
      });
      _toast(context.l10n.authCaptchaKeyReady);
    } catch (e) {
      _toast(errorMessage(e, context.l10n));
      if (mounted) {
        setState(() => _hint = context.l10n.authRiskHintFetchFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendSms() async {
    var captcha = _captcha;
    var validate = _geeValidate;
    var seccode = _geeSeccode;
    var challenge = _geeChallenge;

    if (captcha == null ||
        validate == null ||
        validate.isEmpty ||
        seccode == null ||
        seccode.isEmpty) {
      await _solveCaptcha();
      captcha = _captcha;
      validate = _geeValidate;
      seccode = _geeSeccode;
      challenge = _geeChallenge;
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
      final res = await CoreApi.instance.loginPasswordRiskSendSms(
        PasswordRiskSendSmsDto(
          tmpToken: widget.risk.tmpToken,
          riskUrl: widget.risk.riskUrl,
          token: captcha.token,
          geeChallenge: challenge ?? captcha.challenge,
          geeValidate: validate,
          geeSeccode: seccode,
        ),
      );
      if (!mounted) return;
      setState(() {
        _captchaKey = res.captchaKey;
        _hint = context.l10n.authRiskHintSent;
      });
      _toast(context.l10n.authCodeSent);
    } catch (e) {
      if (!mounted) return;
      _toast(errorMessage(e, context.l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final key = _captchaKey;
    if (key == null || key.isEmpty) {
      _toast(context.l10n.authNeedSendSmsFirst);
      return;
    }
    final code = _smsCodeController.text.trim();
    if (code.isEmpty) {
      _toast(context.l10n.authNeedSmsCode);
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
      if (!mounted) return;
      _toast(errorMessage(e, context.l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final hideTel = widget.risk.hideTel;
    final geeReady = _geeValidate != null && _geeValidate!.isNotEmpty;

    return AlertDialog(
      title: Text(l10n.authRiskTitle, textAlign: TextAlign.center),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                hideTel.isEmpty ? l10n.authRiskPhoneHint : hideTel,
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
              const SizedBox(height: AppSpacing.md - 4),
              NpButton(
                label: l10n.authGetCaptcha,
                icon: AppIcons.shield,
                variant: NpButtonVariant.secondary,
                onPressed: _busy ? null : _solveCaptcha,
              ),
              if (geeReady) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.authCaptchaKeyReady,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.accent,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md - 4),
              NpButton(
                label: _busy ? l10n.authSending : l10n.authSendCode,
                icon: AppIcons.sms,
                loading: _busy,
                onPressed: _busy ? null : _sendSms,
              ),
              if (_captchaKey != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.authCaptchaKeyReady,
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
                decoration: InputDecoration(labelText: l10n.authSmsCode),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(
            l10n.cancel,
            style: TextStyle(color: colors.fgSecondary),
          ),
        ),
        TextButton(
          onPressed: _busy ? null : _verify,
          child: Text(l10n.authVerify),
        ),
      ],
    );
  }
}
