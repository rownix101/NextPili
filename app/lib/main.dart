import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'bridge/core_api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? bootError;
  try {
    await CoreApi.instance.init();
    final ver = await CoreApi.instance.bootstrapDefault();
    if (ver.major != 0) {
      // Major mismatch policy — keep permissive during 0.x skeleton.
      debugPrint('Unexpected API major: ${ver.major}');
    }
    debugPrint('Core ready: ping=${CoreApi.instance.ping()} api=${ver.major}.${ver.minor}.${ver.patch}');
  } catch (e, st) {
    bootError = errorMessage(e);
    debugPrint('Core bootstrap failed: $e\n$st');
  }

  runApp(
    ProviderScope(
      child: bootError == null
          ? NextPiliApp()
          : _BootstrapErrorApp(message: bootError),
    ),
  );
}

class _BootstrapErrorApp extends StatelessWidget {
  const _BootstrapErrorApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('无法启动 Core：\n$message', textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
