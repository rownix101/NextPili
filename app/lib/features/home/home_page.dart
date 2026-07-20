import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bridge/core_api.dart';

final coreStatusProvider = FutureProvider<String>((ref) async {
  final api = CoreApi.instance;
  final ping = api.ping();
  final ver = api.apiVersion();
  return '$ping · API ${ver.major}.${ver.minor}.${ver.patch} (core ${ver.core})';
});

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(coreStatusProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('NextPili')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('骨架已就绪', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 12),
                Text(
                  'P0：Rust workspace + Flutter 桌面壳 + FRB ping / api_version',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                status.when(
                  data: (text) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.check_circle_outline),
                      title: const Text('Core 链路'),
                      subtitle: Text(text),
                    ),
                  ),
                  loading: () => const CircularProgressIndicator(),
                  error: (e, _) => Card(
                    color: theme.colorScheme.errorContainer,
                    child: ListTile(
                      leading: const Icon(Icons.error_outline),
                      title: const Text('Core 不可用'),
                      subtitle: Text(errorMessage(e)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
