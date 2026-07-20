import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'frb/api/simple.dart' as frb;
import 'frb/error.dart';
import 'frb/frb_generated.dart';

export 'frb/api/simple.dart' show ApiVersion, BootstrapConfig;
export 'frb/error.dart' show AppError, ErrorKind;

/// Thin facade over generated FRB bindings.
class CoreApi {
  CoreApi._();

  static final CoreApi instance = CoreApi._();

  bool _initialized = false;

  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;
    await RustLib.init();
    _initialized = true;
  }

  String ping() => frb.ping();

  frb.ApiVersion apiVersion() => frb.apiVersion();

  Future<void> bootstrap({
    required String dataDir,
    required String cacheDir,
    String logLevel = 'info',
  }) {
    return frb.bootstrap(
      config: frb.BootstrapConfig(
        dataDir: dataDir,
        cacheDir: cacheDir,
        logLevel: logLevel,
      ),
    );
  }

  /// Resolve platform data/cache dirs and bootstrap core.
  Future<frb.ApiVersion> bootstrapDefault({String logLevel = 'info'}) async {
    final support = await getApplicationSupportDirectory();
    final cache = await getApplicationCacheDirectory();
    final dataDir = p.join(support.path, 'nextpili');
    final cacheDir = p.join(cache.path, 'nextpili');
    await bootstrap(dataDir: dataDir, cacheDir: cacheDir, logLevel: logLevel);
    return apiVersion();
  }
}

/// Map FRB [AppError] / any into a short UI message.
String errorMessage(Object error) {
  if (error is AppError) {
    return error.message;
  }
  if (error is AnyhowException) {
    return error.message;
  }
  return error.toString();
}
