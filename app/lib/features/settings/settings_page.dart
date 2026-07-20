import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../bridge/core_api.dart';
import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/spacing.dart';
import '../../core/widgets/content_surface.dart';
import '../../core/widgets/loading.dart';
import '../../core/widgets/page_header.dart';
import '../../l10n/l10n.dart';

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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: PageHeader(title: l10n.settingsTitle),
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
                    ContentSurface(
                      child: Column(
                        children: [
                          ListTile(
                            title: Text(l10n.settingsAccountTitle),
                            subtitle: Text(l10n.settingsAccountSubtitle),
                            leading: Icon(
                              AppIcons.user,
                              color: colors.fgSecondary,
                            ),
                            trailing: Icon(
                              AppIcons.chevronRight,
                              color: colors.fgMuted,
                              size: AppIcons.sm,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppShapes.borderMd,
                            ),
                            onTap: () => context.push('/auth'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ContentSurface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ListTile(
                            title: Text(l10n.settingsDefaultQuality),
                            subtitle: Text(
                              _labelForQn(
                                _settings?.preferredQn ?? 80,
                                l10n,
                              ),
                            ),
                            leading: Icon(
                              AppIcons.highQuality,
                              color: colors.fgSecondary,
                            ),
                            trailing: Icon(
                              AppIcons.chevronRight,
                              color: colors.fgMuted,
                              size: AppIcons.sm,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppShapes.borderMd,
                            ),
                            onTap: () => _pickQuality(context),
                          ),
                          Divider(height: 1, color: colors.borderSubtle),
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
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                TextField(
                                  controller: _proxyController,
                                  decoration: InputDecoration(
                                    hintText: 'http://127.0.0.1:7890',
                                    helperText: l10n.settingsProxyHelper,
                                    border: const OutlineInputBorder(),
                                    isDense: true,
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
