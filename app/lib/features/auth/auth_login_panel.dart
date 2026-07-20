import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../bridge/core_api.dart';
import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/spacing.dart';
import '../../core/widgets/np_button.dart';
import '../../l10n/l10n.dart';

/// Dual-pane login card inspired by bilibili web sign-in (QR left, form right).
///
/// Captcha / GeeTest stays available but secondary so the primary fields match
/// the reference layout. No third-party OAuth (WeChat / Weibo / QQ).
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
    required this.pwdGeeValidateController,
    required this.pwdGeeSeccodeController,
    required this.pwdHint,
    required this.onPreparePwdCaptcha,
    required this.onOpenPwdGee,
    required this.onPasswordLogin,
    required this.onRegister,
    required this.onForgotPassword,
    required this.telController,
    required this.codeController,
    required this.smsGeeValidateController,
    required this.smsGeeSeccodeController,
    required this.smsCaptcha,
    required this.captchaKey,
    required this.smsHint,
    required this.cid,
    required this.onCidChanged,
    required this.onPrepareSmsCaptcha,
    required this.onOpenSmsGee,
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
  final TextEditingController pwdGeeValidateController;
  final TextEditingController pwdGeeSeccodeController;
  final String pwdHint;
  final VoidCallback onPreparePwdCaptcha;
  final VoidCallback onOpenPwdGee;
  final VoidCallback onPasswordLogin;
  final VoidCallback onRegister;
  final VoidCallback onForgotPassword;

  final TextEditingController telController;
  final TextEditingController codeController;
  final TextEditingController smsGeeValidateController;
  final TextEditingController smsGeeSeccodeController;
  final CaptchaDto? smsCaptcha;
  final String? captchaKey;
  final String smsHint;
  final int cid;
  final ValueChanged<int> onCidChanged;
  final VoidCallback onPrepareSmsCaptcha;
  final VoidCallback onOpenSmsGee;
  final VoidCallback onSendSms;
  final VoidCallback onSmsLogin;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final form = _CredentialPane(
      tabController: formTabController,
      busy: busy,
      usernameController: usernameController,
      passwordController: passwordController,
      obscurePassword: obscurePassword,
      onToggleObscure: onToggleObscure,
      pwdCaptcha: pwdCaptcha,
      pwdGeeValidateController: pwdGeeValidateController,
      pwdGeeSeccodeController: pwdGeeSeccodeController,
      pwdHint: pwdHint,
      onPreparePwdCaptcha: onPreparePwdCaptcha,
      onOpenPwdGee: onOpenPwdGee,
      onPasswordLogin: onPasswordLogin,
      onRegister: onRegister,
      onForgotPassword: onForgotPassword,
      telController: telController,
      codeController: codeController,
      smsGeeValidateController: smsGeeValidateController,
      smsGeeSeccodeController: smsGeeSeccodeController,
      smsCaptcha: smsCaptcha,
      captchaKey: captchaKey,
      smsHint: smsHint,
      cid: cid,
      onCidChanged: onCidChanged,
      onPrepareSmsCaptcha: onPrepareSmsCaptcha,
      onOpenSmsGee: onOpenSmsGee,
      onSendSms: onSendSms,
      onSmsLogin: onSmsLogin,
    );

    final body = showQr && wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 280,
                child: _QrPane(
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
            child: _QrPane(
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

class _QrPane extends StatelessWidget {
  const _QrPane({
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

  static const double _qrSize = 168;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final expired = statusKind == QrStatusKind.expired;
    final failed = statusKind == QrStatusKind.error;
    final confirmed = statusKind == QrStatusKind.confirmed;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            l10n.authQrPanelTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Tooltip(
            message: busy ? l10n.authQrRefreshing : l10n.authQrTapRefresh,
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
                    width: _qrSize + AppSpacing.lg,
                    height: _qrSize + AppSpacing.lg,
                    child: Center(child: _buildQrBody(colors)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            status.isEmpty ? l10n.authQrPanelHint : status,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: confirmed
                  ? colors.success
                  : (expired || failed)
                      ? colors.error
                      : colors.fgSecondary,
              height: 1.4,
            ),
          ),
          if (expired || failed || qrUrl == null) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: busy ? null : onRefresh,
              icon: busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(AppIcons.refresh, size: 16),
              label: Text(
                busy
                    ? l10n.authQrRefreshing
                    : (expired || failed || qrUrl == null)
                        ? l10n.refresh
                        : l10n.authQrReacquire,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQrBody(AppColors colors) {
    if (busy && (qrUrl == null || qrUrl!.isEmpty)) {
      return const SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final url = qrUrl;
    if (url == null || url.isEmpty) {
      return Icon(AppIcons.qrCode, size: 40, color: colors.fgMuted);
    }
    Widget qr = QrImageView(
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
    if (statusKind == QrStatusKind.expired ||
        statusKind == QrStatusKind.error) {
      qr = ColorFiltered(
        colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
        child: Opacity(opacity: 0.35, child: qr),
      );
    }
    return qr;
  }
}

class _CredentialPane extends StatelessWidget {
  const _CredentialPane({
    required this.tabController,
    required this.busy,
    required this.usernameController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.pwdCaptcha,
    required this.pwdGeeValidateController,
    required this.pwdGeeSeccodeController,
    required this.pwdHint,
    required this.onPreparePwdCaptcha,
    required this.onOpenPwdGee,
    required this.onPasswordLogin,
    required this.onRegister,
    required this.onForgotPassword,
    required this.telController,
    required this.codeController,
    required this.smsGeeValidateController,
    required this.smsGeeSeccodeController,
    required this.smsCaptcha,
    required this.captchaKey,
    required this.smsHint,
    required this.cid,
    required this.onCidChanged,
    required this.onPrepareSmsCaptcha,
    required this.onOpenSmsGee,
    required this.onSendSms,
    required this.onSmsLogin,
  });

  final TabController tabController;
  final bool busy;

  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
  final CaptchaDto? pwdCaptcha;
  final TextEditingController pwdGeeValidateController;
  final TextEditingController pwdGeeSeccodeController;
  final String pwdHint;
  final VoidCallback onPreparePwdCaptcha;
  final VoidCallback onOpenPwdGee;
  final VoidCallback onPasswordLogin;
  final VoidCallback onRegister;
  final VoidCallback onForgotPassword;

  final TextEditingController telController;
  final TextEditingController codeController;
  final TextEditingController smsGeeValidateController;
  final TextEditingController smsGeeSeccodeController;
  final CaptchaDto? smsCaptcha;
  final String? captchaKey;
  final String smsHint;
  final int cid;
  final ValueChanged<int> onCidChanged;
  final VoidCallback onPrepareSmsCaptcha;
  final VoidCallback onOpenSmsGee;
  final VoidCallback onSendSms;
  final VoidCallback onSmsLogin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TabBar(
              controller: tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              dividerColor: Colors.transparent,
              labelPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              tabs: [
                Tab(text: l10n.authTabPassword),
                Tab(text: l10n.authTabSms),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: AnimatedBuilder(
              animation: tabController,
              builder: (context, _) {
                final passwordForm = _PasswordForm(
                  busy: busy,
                  usernameController: usernameController,
                  passwordController: passwordController,
                  obscurePassword: obscurePassword,
                  onToggleObscure: onToggleObscure,
                  captcha: pwdCaptcha,
                  geeValidateController: pwdGeeValidateController,
                  geeSeccodeController: pwdGeeSeccodeController,
                  hint: pwdHint,
                  onPrepareCaptcha: onPreparePwdCaptcha,
                  onOpenGee: onOpenPwdGee,
                  onLogin: onPasswordLogin,
                  onRegister: onRegister,
                  onForgotPassword: onForgotPassword,
                );
                final smsForm = _SmsForm(
                  busy: busy,
                  telController: telController,
                  codeController: codeController,
                  geeValidateController: smsGeeValidateController,
                  geeSeccodeController: smsGeeSeccodeController,
                  captcha: smsCaptcha,
                  captchaKey: captchaKey,
                  hint: smsHint,
                  cid: cid,
                  onCidChanged: onCidChanged,
                  onPrepareCaptcha: onPrepareSmsCaptcha,
                  onOpenGee: onOpenSmsGee,
                  onSendSms: onSendSms,
                  onLogin: onSmsLogin,
                  onRegister: onRegister,
                );
                return IndexedStack(
                  index: tabController.index,
                  children: [passwordForm, smsForm],
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.authTermsFooter,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.fgMuted,
              height: 1.35,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordForm extends StatelessWidget {
  const _PasswordForm({
    required this.busy,
    required this.usernameController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.captcha,
    required this.geeValidateController,
    required this.geeSeccodeController,
    required this.hint,
    required this.onPrepareCaptcha,
    required this.onOpenGee,
    required this.onLogin,
    required this.onRegister,
    required this.onForgotPassword,
  });

  final bool busy;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
  final CaptchaDto? captcha;
  final TextEditingController geeValidateController;
  final TextEditingController geeSeccodeController;
  final String hint;
  final VoidCallback onPrepareCaptcha;
  final VoidCallback onOpenGee;
  final VoidCallback onLogin;
  final VoidCallback onRegister;
  final VoidCallback onForgotPassword;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = AppColors.of(context);
    final theme = Theme.of(context);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _LabeledFieldGroup(
          children: [
            _InlineField(
              label: l10n.authAccountLabel,
              child: TextField(
                controller: usernameController,
                enabled: !busy,
                textInputAction: TextInputAction.next,
                autofillHints: const [
                  AutofillHints.username,
                  AutofillHints.email,
                  AutofillHints.telephoneNumber,
                ],
                decoration: InputDecoration(
                  hintText: l10n.authAccountHint,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            Divider(height: 1, color: colors.borderSubtle),
            _InlineField(
              label: l10n.authPassword,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: obscurePassword
                        ? l10n.authShowPassword
                        : l10n.authHidePassword,
                    onPressed: onToggleObscure,
                    icon: Icon(
                      obscurePassword ? AppIcons.eyeOff : AppIcons.eye,
                      size: 18,
                      color: colors.fgMuted,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  TextButton(
                    onPressed: busy ? null : onForgotPassword,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(l10n.authForgotPassword),
                  ),
                ],
              ),
              child: TextField(
                controller: passwordController,
                enabled: !busy,
                obscureText: obscurePassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onLogin(),
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  hintText: l10n.authPasswordHint,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _CaptchaSection(
          busy: busy,
          captcha: captcha,
          geeValidateController: geeValidateController,
          geeSeccodeController: geeSeccodeController,
          onPrepareCaptcha: onPrepareCaptcha,
          onOpenGee: onOpenGee,
        ),
        if (hint.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            hint,
            style: theme.textTheme.bodySmall?.copyWith(color: colors.fgSecondary),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        _ActionRow(
          busy: busy,
          loginLabel: busy ? l10n.authLoggingIn : l10n.login,
          onRegister: onRegister,
          onLogin: onLogin,
        ),
      ],
    );
  }
}

class _SmsForm extends StatelessWidget {
  const _SmsForm({
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
    required this.onRegister,
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
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = AppColors.of(context);
    final theme = Theme.of(context);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _LabeledFieldGroup(
          children: [
            _InlineField(
              label: l10n.authPhone,
              leading: SizedBox(
                width: 72,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: cid,
                    isExpanded: true,
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('+86')),
                    ],
                    onChanged: busy
                        ? null
                        : (v) {
                            if (v != null) onCidChanged(v);
                          },
                  ),
                ),
              ),
              child: TextField(
                controller: telController,
                enabled: !busy,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
                decoration: InputDecoration(
                  hintText: l10n.authPhoneHint,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            Divider(height: 1, color: colors.borderSubtle),
            _InlineField(
              label: l10n.authSmsCode,
              trailing: TextButton(
                onPressed: busy ? null : onSendSms,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(busy ? l10n.authSending : l10n.authSendCode),
              ),
              child: TextField(
                controller: codeController,
                enabled: !busy,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onLogin(),
                decoration: InputDecoration(
                  hintText: l10n.authSmsCodeHint,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _CaptchaSection(
          busy: busy,
          captcha: captcha,
          geeValidateController: geeValidateController,
          geeSeccodeController: geeSeccodeController,
          onPrepareCaptcha: onPrepareCaptcha,
          onOpenGee: onOpenGee,
          sentReady: captchaKey != null && captchaKey!.isNotEmpty,
        ),
        if (hint.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            hint,
            style: theme.textTheme.bodySmall?.copyWith(color: colors.fgSecondary),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        _ActionRow(
          busy: busy,
          loginLabel: busy ? l10n.authLoggingIn : l10n.login,
          onRegister: onRegister,
          onLogin: onLogin,
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.busy,
    required this.loginLabel,
    required this.onRegister,
    required this.onLogin,
  });

  final bool busy;
  final String loginLabel;
  final VoidCallback onRegister;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: NpButton(
            label: l10n.authRegister,
            variant: NpButtonVariant.secondary,
            onPressed: busy ? null : onRegister,
            expanded: true,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: NpButton(
            label: loginLabel,
            loading: busy,
            onPressed: busy ? null : onLogin,
            expanded: true,
          ),
        ),
      ],
    );
  }
}

class _CaptchaSection extends StatelessWidget {
  const _CaptchaSection({
    required this.busy,
    required this.captcha,
    required this.geeValidateController,
    required this.geeSeccodeController,
    required this.onPrepareCaptcha,
    required this.onOpenGee,
    this.sentReady = false,
  });

  final bool busy;
  final CaptchaDto? captcha;
  final TextEditingController geeValidateController;
  final TextEditingController geeSeccodeController;
  final VoidCallback onPrepareCaptcha;
  final VoidCallback onOpenGee;
  final bool sentReady;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = AppColors.of(context);
    final theme = Theme.of(context);

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
        initiallyExpanded: captcha != null || sentReady,
        title: Text(
          l10n.authCaptchaSection,
          style: theme.textTheme.labelLarge?.copyWith(color: colors.fgSecondary),
        ),
        subtitle: captcha == null
            ? null
            : Text(
                sentReady ? l10n.authCaptchaKeyReady : 'gt / challenge ready',
                style: theme.textTheme.bodySmall?.copyWith(color: colors.fgMuted),
              ),
        children: [
          if (captcha != null)
            SelectableText(
              'gt: ${captcha!.gt}\nchallenge: ${captcha!.challenge}',
              style: theme.textTheme.bodySmall,
            ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              NpButton(
                label: l10n.authGetCaptcha,
                icon: AppIcons.shield,
                variant: NpButtonVariant.secondary,
                onPressed: busy ? null : onPrepareCaptcha,
              ),
              NpButton(
                label: l10n.authOpenGeeHelper,
                icon: AppIcons.externalLink,
                variant: NpButtonVariant.secondary,
                onPressed: busy || captcha == null ? null : onOpenGee,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: geeValidateController,
            enabled: !busy,
            decoration: const InputDecoration(labelText: 'gee_validate'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: geeSeccodeController,
            enabled: !busy,
            decoration: InputDecoration(
              labelText: l10n.authGeeSeccodeOptional,
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledFieldGroup extends StatelessWidget {
  const _LabeledFieldGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppShapes.borderMd,
        border: Border.all(color: colors.borderSubtle),
        color: colors.sunken.withValues(alpha: 0.35),
      ),
      child: Column(children: children),
    );
  }
}

class _InlineField extends StatelessWidget {
  const _InlineField({
    required this.label,
    required this.child,
    this.leading,
    this.trailing,
  });

  final String label;
  final Widget child;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md - 2,
        vertical: 6,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.fgPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(child: child),
          ?trailing,
        ],
      ),
    );
  }
}
