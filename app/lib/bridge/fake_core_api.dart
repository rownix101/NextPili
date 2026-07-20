import 'frb/api/simple.dart';

/// In-memory fake for widget tests (no native lib).
class FakeCoreApi {
  String ping() => 'pong';

  ApiVersion apiVersion() => const ApiVersion(
        major: 0,
        minor: 2,
        patch: 0,
        core: 'fake',
      );

  Future<void> bootstrap({
    required String dataDir,
    required String cacheDir,
    String logLevel = 'info',
  }) async {}
}
