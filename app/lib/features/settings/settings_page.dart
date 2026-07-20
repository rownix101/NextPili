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

/// Common Bilibili qn options (see docs/api/endpoints/video.md).
const _qnOptions = <(int, String)>[
  (16, '360P'),
  (32, '480P'),
  (64, '720P'),
  (80, '1080P'),
  (112, '1080P+'),
  (116, '1080P60'),
  (120, '4K'),
  (125, 'HDR'),
  (126, '杜比视界'),
  (127, '8K'),
];

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
        _error = errorMessage(e);
      });
    }
  }

  Future<void> _setPreferredQn(int qn) async {
    try {
      final s = CoreApi.instance.updateSettings(preferredQn: qn);
      if (!mounted) return;
      setState(() => _settings = s);
      _toast('默认清晰度已更新');
    } catch (e) {
      if (!mounted) return;
      _toast(errorMessage(e));
    }
  }

  Future<void> _saveProxy() async {
    try {
      final raw = _proxyController.text.trim();
      final s = CoreApi.instance.updateSettings(proxy: raw);
      if (!mounted) return;
      setState(() => _settings = s);
      _proxyController.text = s.proxy ?? '';
      _toast(raw.isEmpty ? '已清除代理' : '代理已保存并生效');
    } catch (e) {
      if (!mounted) return;
      _toast(errorMessage(e));
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: const PageHeader(title: '设置'),
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
                        FilledButton(onPressed: _load, child: const Text('重试')),
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
                            title: const Text('账号与登录'),
                            subtitle: const Text('短信登录 · 桌面/平板扫码'),
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
                            title: const Text('默认清晰度'),
                            subtitle: Text(
                              _labelForQn(_settings?.preferredQn ?? 80),
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
                                      'HTTP 代理',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                TextField(
                                  controller: _proxyController,
                                  decoration: const InputDecoration(
                                    hintText: 'http://127.0.0.1:7890',
                                    helperText:
                                        '留空并保存可清除；支持 http / https / socks5',
                                    border: OutlineInputBorder(),
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
                                    child: const Text('保存代理'),
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
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final (qn, label) in _qnOptions)
                ListTile(
                  title: Text(label),
                  subtitle: Text('qn $qn'),
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

String _labelForQn(int qn) {
  for (final (code, label) in _qnOptions) {
    if (code == qn) return '$label · qn $qn';
  }
  return 'qn $qn';
}
