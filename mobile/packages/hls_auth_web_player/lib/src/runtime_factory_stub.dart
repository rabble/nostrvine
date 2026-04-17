import 'package:hls_auth_web_player/src/hls_auth_web_runtime.dart';

/// Non-web platforms get a runtime that always reports unsupported. The
/// widget short-circuits to its error builder in that case. This is a last
/// line of defense; callers are expected to only instantiate the web player
/// when `kIsWeb` is true.
HlsAuthWebRuntime createDefaultRuntime() => _UnsupportedRuntime();

class _UnsupportedRuntime implements HlsAuthWebRuntime {
  @override
  bool get isSupported => false;

  @override
  void ensureVideoViewFactory(String viewType) {}

  @override
  Future<HlsAuthWebAttemptResult> loadMp4Blob({
    required String viewType,
    required String url,
    String? authorization,
  }) async => HlsAuthWebAttemptResult.failure;

  @override
  Future<HlsAuthWebAttemptResult> loadHls({
    required String viewType,
    required String url,
    required Future<String?> Function(String url, String method) authHeader,
  }) async => HlsAuthWebAttemptResult.failure;

  @override
  Future<void> dispose(String viewType) async {}
}
