import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          ListTile(
            title: Text('账号与登录'),
            subtitle: Text('P1 接入扫码 / Cookie 导入'),
            leading: Icon(Icons.person_outline),
          ),
          ListTile(
            title: Text('播放清晰度'),
            subtitle: Text('P3 起由 Rust settings 持久化'),
            leading: Icon(Icons.high_quality_outlined),
          ),
          ListTile(
            title: Text('代理'),
            subtitle: Text('统一走 HTTP 客户端配置'),
            leading: Icon(Icons.vpn_lock_outlined),
          ),
        ],
      ),
    );
  }
}
