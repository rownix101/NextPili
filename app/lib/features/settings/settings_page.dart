import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../bridge/core_api.dart';
import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/spacing.dart';
import '../../core/widgets/glass/app_glass.dart';
import '../../core/widgets/loading.dart';
import '../../core/widgets/page_header.dart';
import '../../l10n/l10n.dart';
import '../../core/widgets/app_snack_bar.dart';

/// Common Bilibili qn options (see docs/api/endpoints/video.md).
/// Labels that are not pure tech tokens resolve via l10n in [_labelForQn].
const _qnCodes = <int>[16, 32, 64, 80, 112, 116, 120, 125, 126, 127];

String _staticQnLabel(int qn, AppLocalizations l10n) {
  return switch (qn) {
    16 => '360P',
    32 => '480P',
    64 => '720P',
    80 => '1080P',
    112 => '1080P+',
    116 => '1080P60',
    120 => '4K',
    125 => 'HDR',
    126 => l10n.qualityDolbyVision,
    127 => '8K',
    _ => l10n.settingsQnLabel(qn),
  };
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _loading = true;
  String? _error;
  SettingsDto? _settings;
  late final TextEditingController _proxyController;

  @override
  void initState() {
    super.initState();
    _proxyController = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _proxyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = CoreApi.instance.getSettings();
      if (!mounted) return;
      _proxyController.text = s.proxy ?? '';
      setState(() {
        _settings = s;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = errorMessage(e, context.l10n);
      });
    }
  }

  Future<void> _setPreferredQn(int qn) async {
    try {
      final s = CoreApi.instance.updateSettings(preferredQn: qn);
      if (!mounted) return;
      setState(() => _settings = s);
      _toast(context.l10n.settingsQualityUpdated);
    } catch (e) {
      if (!mounted) return;
      _toast(errorMessage(e, context.l10n));
    }
  }

  Future<void> _saveProxy() async {
    try {
      final raw = _proxyController.text.trim();
      final s = CoreApi.instance.updateSettings(proxy: raw);
      if (!mounted) return;
      setState(() => _settings = s);
      _proxyController.text = s.proxy ?? '';
      final l10n = context.l10n;
      _toast(raw.isEmpty ? l10n.settingsProxyCleared : l10n.settingsProxySaved);
    } catch (e) {
      if (!mounted) return;
      _toast(errorMessage(e, context.l10n));
    }
  }

  void _toast(String msg) {
    AppSnackBar.show(context, message: msg);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final glassSettings = GlassPanel.settings(colors);

    TextStyle titleStyle(AppColors c) =>
        theme.textTheme.titleMedium?.copyWith(color: c.fgPrimary) ??
        TextStyle(color: c.fgPrimary, fontSize: 16, fontWeight: FontWeight.w500);

    TextStyle subtitleStyle(AppColors c) =>
        theme.textTheme.bodySmall?.copyWith(color: c.fgSecondary) ??
        TextStyle(color: c.fgSecondary, fontSize: 13);

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: PageHeader(
        title: l10n.settingsTitle,
        showBack: Navigator.canPop(context),
      ),
      body: _loading
          ? const AppLoading()
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: AppSpacing.md),
                        FilledButton(
                          onPressed: _load,
                          child: Text(l10n.retry),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    // design-system §2.5 — settings grouped surface uses Liquid Glass.
                    GlassGroupedSection(
                      useOwnLayer: true,
                      quality: GlassQuality.standard,
                      settings: glassSettings,
                      shape: LiquidRoundedSuperellipse(
                        borderRadius: AppShapes.md,
                      ),
                      margin: EdgeInsets.zero,
                      children: [
                        GlassListTile(
                          leading: Icon(
                            AppIcons.user,
                            color: colors.fgSecondary,
                            size: AppIcons.md,
                          ),
                          title: Text(
                            l10n.settingsAccountTitle,
                            style: titleStyle(colors),
                          ),
                          subtitle: Text(
                            l10n.settingsAccountSubtitle,
                            style: subtitleStyle(colors),
                          ),
                          trailing: Icon(
                            AppIcons.chevronRight,
                            color: colors.fgMuted,
                            size: AppIcons.sm,
                          ),
                          onTap: () => context.push('/auth'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    GlassGroupedSection(
                      useOwnLayer: true,
                      quality: GlassQuality.standard,
                      settings: glassSettings,
                      shape: LiquidRoundedSuperellipse(
                        borderRadius: AppShapes.md,
                      ),
                      margin: EdgeInsets.zero,
                      children: [
                        GlassListTile(
                          leading: Icon(
                            AppIcons.highQuality,
                            color: colors.fgSecondary,
                            size: AppIcons.md,
                          ),
                          title: Text(
                            l10n.settingsDefaultQuality,
                            style: titleStyle(colors),
                          ),
                          subtitle: Text(
                            _labelForQn(
                              _settings?.preferredQn ?? 80,
                              l10n,
                            ),
                            style: subtitleStyle(colors),
                          ),
                          trailing: Icon(
                            AppIcons.chevronRight,
                            color: colors.fgMuted,
                            size: AppIcons.sm,
                          ),
                          onTap: () => _pickQuality(context),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.sm,
                            AppSpacing.md,
                            AppSpacing.md,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    AppIcons.proxy,
                                    color: colors.fgSecondary,
                                    size: AppIcons.md,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Text(
                                    l10n.settingsProxyTitle,
                                    style: titleStyle(colors),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              TextField(
                                controller: _proxyController,
                                style: TextStyle(color: colors.fgPrimary),
                                decoration: InputDecoration(
                                  hintText: 'http://127.0.0.1:7890',
                                  hintStyle: TextStyle(color: colors.fgMuted),
                                  helperText: l10n.settingsProxyHelper,
                                  helperStyle:
                                      TextStyle(color: colors.fgMuted),
                                  border: OutlineInputBorder(
                                    borderRadius: AppShapes.borderSm,
                                    borderSide: BorderSide(
                                      color: colors.borderSubtle,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: AppShapes.borderSm,
                                    borderSide: BorderSide(
                                      color: colors.borderSubtle,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: AppShapes.borderSm,
                                    borderSide: BorderSide(
                                      color: colors.accent,
                                    ),
                                  ),
                                  isDense: true,
                                  filled: true,
                                  fillColor: colors.sunken,
                                ),
                                keyboardType: TextInputType.url,
                                onSubmitted: (_) => _saveProxy(),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton(
                                  onPressed: _saveProxy,
                                  child: Text(l10n.settingsProxySave),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
    );
  }

  Future<void> _pickQuality(BuildContext context) async {
    final current = _settings?.preferredQn ?? 80;
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final sheetL10n = ctx.l10n;
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final qn in _qnCodes)
                ListTile(
                  title: Text(_staticQnLabel(qn, sheetL10n)),
                  subtitle: Text(sheetL10n.settingsQnLabel(qn)),
                  trailing: qn == current
                      ? Icon(
                          AppIcons.check,
                          color: AppColors.of(ctx).accent,
                        )
                      : null,
                  onTap: () => Navigator.of(ctx).pop(qn),
                ),
            ],
          ),
        );
      },
    );
    if (picked != null && picked != current) {
      await _setPreferredQn(picked);
    }
  }
}

String _labelForQn(int qn, AppLocalizations l10n) {
  if (_qnCodes.contains(qn)) {
    return l10n.settingsQnWithLabel(_staticQnLabel(qn, l10n), qn);
  }
  return l10n.settingsQnLabel(qn);
}
