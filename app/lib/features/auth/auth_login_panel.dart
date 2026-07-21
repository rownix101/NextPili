import 'package:flutter/material.dart';

import '../../bridge/core_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/spacing.dart';
import 'auth_credential_pane.dart';
import 'auth_qr_pane.dart';
import 'dial_prefix.dart';

/// Dual-pane login card inspired by bilibili web sign-in (QR left, form right).
///
/// Captcha uses embedded GeeTest (PiliPlus-style). No third-party OAuth.
class AuthLoginPanel extends StatelessWidget {
  const AuthLoginPanel({
    super.key,
    required this.showQr,
    required this.wide,
    required this.formTabController,
    required this.busy,
    required this.qrBusy,
    required this.qrUrl,
    required this.qrStatus,
    required this.qrKind,
    required this.onRefreshQr,
    required this.usernameController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.pwdCaptcha,
    required this.pwdGeeReady,
    required this.pwdHint,
    required this.onSolvePwdCaptcha,
    required this.onPasswordLogin,
    required this.onRegister,
    required this.onForgotPassword,
    required this.telController,
    required this.codeController,
    required this.smsCaptcha,
    required this.smsGeeReady,
    required this.captchaKey,
    required this.smsHint,
    required this.dial,
    required this.onDialChanged,
    required this.onSolveSmsCaptcha,
    required this.onSendSms,
    required this.onSmsLogin,
  });

  final bool showQr;
  final bool wide;
  final TabController formTabController;
  final bool busy;
  final bool qrBusy;
  final String? qrUrl;
  final String qrStatus;
  final QrStatusKind? qrKind;
  final VoidCallback onRefreshQr;

  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
  final CaptchaDto? pwdCaptcha;
  final bool pwdGeeReady;
  final String pwdHint;
  final VoidCallback onSolvePwdCaptcha;
  final VoidCallback onPasswordLogin;
  final VoidCallback onRegister;
  final VoidCallback onForgotPassword;

  final TextEditingController telController;
  final TextEditingController codeController;
  final CaptchaDto? smsCaptcha;
  final bool smsGeeReady;
  final String? captchaKey;
  final String smsHint;
  final DialPrefix dial;
  final ValueChanged<DialPrefix> onDialChanged;
  final VoidCallback onSolveSmsCaptcha;
  final VoidCallback onSendSms;
  final VoidCallback onSmsLogin;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final form = AuthCredentialPane(
      tabController: formTabController,
      busy: busy,
      usernameController: usernameController,
      passwordController: passwordController,
      obscurePassword: obscurePassword,
      onToggleObscure: onToggleObscure,
      pwdCaptcha: pwdCaptcha,
      pwdGeeReady: pwdGeeReady,
      pwdHint: pwdHint,
      onSolvePwdCaptcha: onSolvePwdCaptcha,
      onPasswordLogin: onPasswordLogin,
      onRegister: onRegister,
      onForgotPassword: onForgotPassword,
      telController: telController,
      codeController: codeController,
      smsCaptcha: smsCaptcha,
      smsGeeReady: smsGeeReady,
      captchaKey: captchaKey,
      smsHint: smsHint,
      dial: dial,
      onDialChanged: onDialChanged,
      onSolveSmsCaptcha: onSolveSmsCaptcha,
      onSendSms: onSendSms,
      onSmsLogin: onSmsLogin,
    );

    final body = showQr && wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 280,
                child: AuthQrPane(
                  busy: qrBusy,
                  qrUrl: qrUrl,
                  status: qrStatus,
                  statusKind: qrKind,
                  onRefresh: onRefreshQr,
                ),
              ),
              VerticalDivider(width: 1, color: colors.borderSubtle),
              Expanded(child: form),
            ],
          )
        : form;

    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.elevated,
        borderRadius: AppShapes.borderXl,
        border: Border.all(color: colors.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppShapes.borderXl,
        child: Material(
          color: colors.elevated,
          child: body,
        ),
      ),
    );

    if (!showQr || wide) return card;

    // Narrow + QR available: stack QR above credential form.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: colors.elevated,
          borderRadius: AppShapes.borderXl,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: AppShapes.borderXl,
              border: Border.all(color: colors.borderSubtle),
            ),
            child: AuthQrPane(
              busy: qrBusy,
              qrUrl: qrUrl,
              status: qrStatus,
              statusKind: qrKind,
              onRefresh: onRefreshQr,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(child: card),
      ],
    );
  }
}

