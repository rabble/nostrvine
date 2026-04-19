import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hls_auth_web_player/src/auth_header_provider.dart';
import 'package:hls_auth_web_player/src/hls_auth_source_policy.dart';
import 'package:hls_auth_web_player/src/hls_auth_web_runtime.dart';
import 'package:hls_auth_web_player/src/hls_auth_web_status.dart';

/// Drives a single web video element through the MP4 blob path first, then
/// falls back to HLS on `404`. On `401`/`403` it stops and surfaces the
/// age-verification flow via [status].
///
/// This class owns no browser state directly — all side effects go through
/// the injected [HlsAuthWebRuntime], which keeps it testable without JS.
class HlsAuthWebController extends ChangeNotifier {
  /// Creates a controller that drives the single [viewType] on [runtime].
  HlsAuthWebController({
    required HlsAuthWebRuntime runtime,
    required String viewType,
    required String url,
    required AuthHeaderProvider authHeader,
    String? hlsFallbackUrl,
  }) : _runtime = runtime,
       _viewType = viewType,
       _url = url,
       _authHeader = authHeader,
       _hlsFallbackUrl = hlsFallbackUrl;

  final HlsAuthWebRuntime _runtime;
  final String _viewType;
  final String _url;
  final String? _hlsFallbackUrl;
  final AuthHeaderProvider _authHeader;

  HlsAuthWebPlaybackStatus _status = HlsAuthWebPlaybackStatus.idle;
  bool _disposed = false;

  /// Current playback status.
  HlsAuthWebPlaybackStatus get status => _status;

  /// The `HtmlElementView`-compatible view type this controller drives.
  String get viewType => _viewType;

  /// Starts loading the source. Safe to call only once per controller; the
  /// widget manages lifecycle so we do not re-enter.
  Future<void> load() async {
    if (_disposed) return;
    if (!_runtime.isSupported) {
      _emit(HlsAuthWebPlaybackStatus.failure);
      return;
    }
    _runtime.ensureVideoViewFactory(_viewType);
    _emit(HlsAuthWebPlaybackStatus.loading);

    final primaryKind = sourceKindFor(_url);
    final outcome = await _loadOne(_url, primaryKind);
    if (_disposed) return;

    switch (outcome) {
      case HlsAuthWebAttemptResult.ok:
        _emit(HlsAuthWebPlaybackStatus.ready);
      case HlsAuthWebAttemptResult.requiresAuth:
        _emit(HlsAuthWebPlaybackStatus.requiresAuth);
      case HlsAuthWebAttemptResult.failure:
        await _tryHlsFallback();
    }
  }

  Future<void> _tryHlsFallback() async {
    final hlsUrl = _hlsFallbackUrl;
    if (hlsUrl == null || hlsUrl.isEmpty) {
      _emit(HlsAuthWebPlaybackStatus.failure);
      return;
    }
    final outcome = await _loadOne(hlsUrl, HlsAuthWebSourceKind.hls);
    if (_disposed) return;
    switch (outcome) {
      case HlsAuthWebAttemptResult.ok:
        _emit(HlsAuthWebPlaybackStatus.ready);
      case HlsAuthWebAttemptResult.requiresAuth:
        _emit(HlsAuthWebPlaybackStatus.requiresAuth);
      case HlsAuthWebAttemptResult.failure:
        _emit(HlsAuthWebPlaybackStatus.failure);
    }
  }

  Future<HlsAuthWebAttemptResult> _loadOne(
    String url,
    HlsAuthWebSourceKind kind,
  ) async {
    switch (kind) {
      case HlsAuthWebSourceKind.mp4:
        final authorization = await _authHeader(url, AuthHttpMethod.get);
        if (_disposed) return HlsAuthWebAttemptResult.failure;
        return _runtime.loadMp4Blob(
          viewType: _viewType,
          url: url,
          authorization: authorization,
        );
      case HlsAuthWebSourceKind.hls:
        return _runtime.loadHls(
          viewType: _viewType,
          url: url,
          authHeader: _authHeader,
        );
    }
  }

  void _emit(HlsAuthWebPlaybackStatus next) {
    if (_disposed || _status == next) return;
    _status = next;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_runtime.dispose(_viewType));
    super.dispose();
  }
}
