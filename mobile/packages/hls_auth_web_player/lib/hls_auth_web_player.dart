/// Public API for the HLS + NIP-98 auth web video player.
///
/// This package is strictly web-only. On non-web builds the widget renders
/// a failure state so callers can keep the import unconditional and gate
/// usage at the call site (e.g. `kIsWeb && FeatureFlag.hlsAuthWebPlayer`).
library;

export 'src/auth_header_provider.dart' show AuthHeaderProvider, AuthHttpMethod;
export 'src/hls_auth_source_policy.dart'
    show HlsAuthWebSourceKind, sourceKindFor;
export 'src/hls_auth_web_controller.dart' show HlsAuthWebController;
export 'src/hls_auth_web_player.dart'
    show HlsAuthWebPlayer, HlsAuthWebStatusBuilder;
export 'src/hls_auth_web_runtime.dart'
    show HlsAuthWebAttemptResult, HlsAuthWebRuntime;
export 'src/hls_auth_web_status.dart' show HlsAuthWebPlaybackStatus;
