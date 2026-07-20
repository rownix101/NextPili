import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/spacing.dart';
import '../../core/widgets/content_surface.dart';
import '../../core/widgets/page_header.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: const PageHeader(title: '设置'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          ContentSurface(
            child: Column(
              children: [
                ListTile(
                  title: const Text('账号与登录'),
                  subtitle: const Text('短信登录 · 桌面/平板扫码'),
                  leading: Icon(AppIcons.user, color: colors.fgSecondary),
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
                Divider(height: 1, color: colors.borderSubtle),
                ListTile(
                  title: const Text('播放清晰度'),
                  subtitle: const Text('P3 起由 Rust settings 持久化'),
                  leading: Icon(AppIcons.highQuality, color: colors.fgSecondary),
                ),
                Divider(height: 1, color: colors.borderSubtle),
                ListTile(
                  title: const Text('代理'),
                  subtitle: const Text('统一走 HTTP 客户端配置'),
                  leading: Icon(AppIcons.proxy, color: colors.fgSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
