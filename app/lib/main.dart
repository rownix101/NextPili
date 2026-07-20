import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';
import 'bridge/core_api.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/glass_theme.dart';
import 'core/theme/spacing.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await LiquidGlassWidgets.initialize();

  String? bootError;
  try {
    await CoreApi.instance.init();
    final ver = await CoreApi.instance.bootstrapDefault();
    if (ver.major != 0) {
      // Major mismatch policy — keep permissive during 0.x skeleton.
      debugPrint('Unexpected API major: ${ver.major}');
    }
    debugPrint(
      'Core ready: ping=${CoreApi.instance.ping()} '
      'api=${ver.major}.${ver.minor}.${ver.patch}',
    );
  } catch (e, st) {
    bootError = errorMessage(e);
    debugPrint('Core bootstrap failed: $e\n$st');
  }

  runApp(
    LiquidGlassWidgets.wrap(
      adaptiveQuality: true,
      theme: NextPiliGlassTheme.data,
      child: ProviderScope(
        child: bootError == null
            ? NextPiliApp()
            : _BootstrapErrorApp(message: bootError),
      ),
    ),
  );
}

class _BootstrapErrorApp extends StatelessWidget {
  const _BootstrapErrorApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.system,
      home: Builder(
        builder: (context) {
          final colors = AppColors.of(context);
          return Scaffold(
            backgroundColor: colors.canvas,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  '无法启动 Core：\n$message',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
