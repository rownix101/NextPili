import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('账号与登录'),
            subtitle: const Text('短信登录 · 桌面/平板扫码'),
            leading: const Icon(Icons.person_outline),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/auth'),
          ),
          const ListTile(
            title: Text('播放清晰度'),
            subtitle: Text('P3 起由 Rust settings 持久化'),
            leading: Icon(Icons.high_quality_outlined),
          ),
          const ListTile(
            title: Text('代理'),
            subtitle: Text('统一走 HTTP 客户端配置'),
            leading: Icon(Icons.vpn_lock_outlined),
          ),
        ],
      ),
    );
  }
}
