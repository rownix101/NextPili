import 'dart:io' show Directory, Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'bridge/core_api.dart';
import 'core/adaptive/desktop_window.dart';
import 'core/adaptive/form_factor.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/glass_theme.dart';
import 'core/theme/spacing.dart';
import 'features/auth/geetest/geetest_webview_dialog.dart';
import 'l10n/l10n.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await LiquidGlassWidgets.initialize();
  await DesktopWindow.ensureInitialized();
  _initMobileSystemUi();
  await _initGeetestWebViewEnvironment();

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
    bootError = errorMessage(e, lookupAppLocalizations(const Locale('zh')));
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

/// Edge-to-edge + transparent system bars on phone/tablet OS.
///
/// Layout still respects [MediaQuery.padding] / SafeArea (multi-platform §7).
void _initMobileSystemUi() {
  if (kIsWeb || !isMobileOs) return;
  // ignore: discarded_futures
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );
}

/// Windows WebView2 user-data folder for embedded GeeTest (PiliPlus pattern).
Future<void> _initGeetestWebViewEnvironment() async {
  if (kIsWeb || !Platform.isWindows) return;
  try {
    if (await WebViewEnvironment.getAvailableVersion() == null) return;
    final support = await getApplicationSupportDirectory();
    final folder = p.join(support.path, 'flutter_inappwebview');
    await Directory(folder).create(recursive: true);
    geetestWebViewEnvironment = await WebViewEnvironment.create(
      settings: WebViewEnvironmentSettings(userDataFolder: folder),
    );
  } catch (e, st) {
    debugPrint('GeeTest WebViewEnvironment init failed: $e\n$st');
  }
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
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          final colors = AppColors.of(context);
          return Scaffold(
            backgroundColor: colors.canvas,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  context.l10n.bootCoreFailed(message),
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
