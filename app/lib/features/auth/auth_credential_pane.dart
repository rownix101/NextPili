import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../bridge/core_api.dart';
import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/spacing.dart';
import '../../core/widgets/np_button.dart';
import '../../l10n/l10n.dart';
import 'dial_prefix.dart';
import 'dial_prefix_picker.dart';

/// Credential form pane (password + SMS tabs) for login card.

class AuthActionRow extends StatelessWidget {
  const AuthActionRow({
    super.key,
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


class AuthCaptchaSection extends StatelessWidget {
  const AuthCaptchaSection({
    super.key,
    required this.busy,
    required this.captcha,
    required this.geeReady,
    required this.onSolveCaptcha,
    this.sentReady = false,
  });

  final bool busy;
  final CaptchaDto? captcha;
  final bool geeReady;
  final VoidCallback onSolveCaptcha;
  final bool sentReady;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final subtitle = sentReady
        ? l10n.authCaptchaKeyReady
        : (geeReady
            ? l10n.authCaptchaKeyReady
            : (captcha == null ? null : l10n.authSmsHintCompleteGee));

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
        initiallyExpanded: captcha != null || geeReady || sentReady,
        title: Text(
          l10n.authCaptchaSection,
          style:
              theme.textTheme.labelLarge?.copyWith(color: colors.fgSecondary),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle,
                style:
                    theme.textTheme.bodySmall?.copyWith(color: colors.fgMuted),
              ),
        children: [
          NpButton(
            label: l10n.authGetCaptcha,
            icon: AppIcons.shield,
            variant: NpButtonVariant.secondary,
            onPressed: busy ? null : onSolveCaptcha,
            expanded: true,
          ),
          if (geeReady) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.authCaptchaKeyReady,
              style: theme.textTheme.bodySmall?.copyWith(color: colors.accent),
            ),
          ],
        ],
      ),
    );
  }
}


class AuthLabeledFieldGroup extends StatelessWidget {
  const AuthLabeledFieldGroup({required this.children});

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


class AuthInlineField extends StatelessWidget {
  const AuthInlineField({
    super.key,
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

class AuthPasswordForm extends StatelessWidget {
  const AuthPasswordForm({
    super.key,
    required this.busy,
    required this.usernameController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.captcha,
    required this.geeReady,
    required this.hint,
    required this.onSolveCaptcha,
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
  final bool geeReady;
  final String hint;
  final VoidCallback onSolveCaptcha;
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
        AuthLabeledFieldGroup(
          children: [
            AuthInlineField(
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
            AuthInlineField(
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
        AuthCaptchaSection(
          busy: busy,
          captcha: captcha,
          geeReady: geeReady,
          onSolveCaptcha: onSolveCaptcha,
        ),
        if (hint.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            hint,
            style:
                theme.textTheme.bodySmall?.copyWith(color: colors.fgSecondary),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        AuthActionRow(
          busy: busy,
          loginLabel: busy ? l10n.authLoggingIn : l10n.login,
          onRegister: onRegister,
          onLogin: onLogin,
        ),
      ],
    );
  }
}


class AuthSmsForm extends StatelessWidget {
  const AuthSmsForm({
    super.key,
    required this.busy,
    required this.telController,
    required this.codeController,
    required this.captcha,
    required this.geeReady,
    required this.captchaKey,
    required this.hint,
    required this.dial,
    required this.onDialChanged,
    required this.onSolveCaptcha,
    required this.onSendSms,
    required this.onLogin,
  });

  final bool busy;
  final TextEditingController telController;
  final TextEditingController codeController;
  final CaptchaDto? captcha;
  final bool geeReady;
  final String? captchaKey;
  final String hint;
  final DialPrefix dial;
  final ValueChanged<DialPrefix> onDialChanged;
  final VoidCallback onSolveCaptcha;
  final VoidCallback onSendSms;
  final VoidCallback onLogin;

  Future<void> _pickDial(BuildContext context) async {
    if (busy) return;
    final next = await showDialPrefixPicker(
      context: context,
      selected: dial,
    );
    if (next != null) onDialChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = AppColors.of(context);
    final theme = Theme.of(context);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        AuthLabeledFieldGroup(
          children: [
            AuthInlineField(
              label: l10n.authPhone,
              leading: Tooltip(
                message: '${dial.cname} ${dial.displayDial}',
                child: InkWell(
                  onTap: busy ? null : () => _pickDial(context),
                  borderRadius: AppShapes.borderSm,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          dial.displayDial,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.fgPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Icon(
                          Icons.arrow_drop_down,
                          size: 18,
                          color: colors.fgMuted,
                        ),
                      ],
                    ),
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
            AuthInlineField(
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
        AuthCaptchaSection(
          busy: busy,
          captcha: captcha,
          geeReady: geeReady,
          onSolveCaptcha: onSolveCaptcha,
          sentReady: captchaKey != null && captchaKey!.isNotEmpty,
        ),
        if (hint.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            hint,
            style:
                theme.textTheme.bodySmall?.copyWith(color: colors.fgSecondary),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        NpButton(
          label: busy ? l10n.authLoggingIn : l10n.login,
          loading: busy,
          onPressed: busy ? null : onLogin,
          expanded: true,
        ),
      ],
    );
  }
}


class AuthCredentialPane extends StatelessWidget {
  const AuthCredentialPane({
    super.key,
    required this.tabController,
    required this.busy,
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

  final TabController tabController;
  final bool busy;

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
              labelPadding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.md),
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
                final passwordForm = AuthPasswordForm(
                  busy: busy,
                  usernameController: usernameController,
                  passwordController: passwordController,
                  obscurePassword: obscurePassword,
                  onToggleObscure: onToggleObscure,
                  captcha: pwdCaptcha,
                  geeReady: pwdGeeReady,
                  hint: pwdHint,
                  onSolveCaptcha: onSolvePwdCaptcha,
                  onLogin: onPasswordLogin,
                  onRegister: onRegister,
                  onForgotPassword: onForgotPassword,
                );
                final smsForm = AuthSmsForm(
                  busy: busy,
                  telController: telController,
                  codeController: codeController,
                  captcha: smsCaptcha,
                  geeReady: smsGeeReady,
                  captchaKey: captchaKey,
                  hint: smsHint,
                  dial: dial,
                  onDialChanged: onDialChanged,
                  onSolveCaptcha: onSolveSmsCaptcha,
                  onSendSms: onSendSms,
                  onLogin: onSmsLogin,
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

