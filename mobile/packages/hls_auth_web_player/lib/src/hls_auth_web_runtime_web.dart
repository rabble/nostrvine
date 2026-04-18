// Web-only runtime. Bridges the Dart controller to the JS shim installed by
// `web/hls_auth_web_player.js`.

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:hls_auth_web_player/src/auth_header_provider.dart';
import 'package:hls_auth_web_player/src/hls_auth_web_runtime.dart';
import 'package:hls_auth_web_player/src/js/hls_js_bindings.dart';

/// Web implementation of [HlsAuthWebRuntime]. Creates a `<video>` element per
/// registered view type, hands it to the JS shim, and dispatches MP4 / HLS
/// loads through `window.__divine*` helpers installed by
/// `web/hls_auth_web_player.js`.
class WebHlsAuthRuntime implements HlsAuthWebRuntime {
  /// Creates a [WebHlsAuthRuntime] that uses the default browser globals.
  WebHlsAuthRuntime();

  final Set<String> _registeredFactories = <String>{};

  @override
  bool get isSupported {
    if (!kIsWeb) return false;
    final ctor = hlsConstructor;
    if (ctor == null) return false;
    try {
      return hlsIsSupportedJs().toDart;
    } on Object catch (error, stackTrace) {
      developer.log(
        'hls.isSupported threw',
        name: 'hls_auth_web_player',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  @override
  void ensureVideoViewFactory(String viewType) {
    if (_registeredFactories.contains(viewType)) return;
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
      final element = _createVideoElement(viewType);
      final register = divineRegisterVideo;
      if (register != null) {
        register.callAsFunction(null, viewType.toJS, element);
      }
      return element;
    });
    _registeredFactories.add(viewType);
  }

  @override
  Future<HlsAuthWebAttemptResult> loadMp4Blob({
    required String viewType,
    required String url,
    String? authorization,
  }) async {
    final fetchMp4 = divineFetchMp4;
    if (fetchMp4 == null) return HlsAuthWebAttemptResult.failure;
    final promise = fetchMp4.callAsFunction(
      null,
      viewType.toJS,
      url.toJS,
      authorization?.toJS,
    );
    final result = await _awaitResult(promise);
    return _attemptFromStatus(result);
  }

  @override
  Future<HlsAuthWebAttemptResult> loadHls({
    required String viewType,
    required String url,
    required AuthHeaderProvider authHeader,
  }) async {
    final loadHls = divineLoadHls;
    if (loadHls == null) return HlsAuthWebAttemptResult.failure;
    JSPromise<JSString?> bridge(JSString jsUrl, JSString jsMethod) {
      final completer = Completer<JSString?>();
      unawaited(
        authHeader(jsUrl.toDart, jsMethod.toDart).then(
          (value) => completer.complete(value?.toJS),
          onError: (Object error, StackTrace stackTrace) {
            developer.log(
              'auth header callback threw',
              name: 'hls_auth_web_player',
              error: error,
              stackTrace: stackTrace,
            );
            completer.complete(null);
          },
        ),
      );
      return completer.future.toJS;
    }

    final jsCallback = bridge.toJS;
    final promise = loadHls.callAsFunction(
      null,
      viewType.toJS,
      url.toJS,
      jsCallback,
    );
    final result = await _awaitResult(promise);
    return _attemptFromStatus(result);
  }

  @override
  Future<void> dispose(String viewType) async {
    final disposeView = divineDisposeView;
    if (disposeView == null) return;
    disposeView.callAsFunction(null, viewType.toJS);
  }

  JSObject _createVideoElement(String viewType) {
    final element = _documentCreateElement('video'.toJS);
    element['id'] = 'divine-hls-$viewType'.toJS;
    element['playsInline'] = true.toJS;
    element['controls'] = false.toJS;
    element['muted'] = true.toJS;
    element['autoplay'] = true.toJS;
    final style = element['style'] as JSObject?;
    if (style != null) {
      style['width'] = '100%'.toJS;
      style['height'] = '100%'.toJS;
      style['objectFit'] = 'cover'.toJS;
      style['background'] = '#000'.toJS;
    }
    return element;
  }

  Future<JSObject?> _awaitResult(JSAny? maybePromise) async {
    if (maybePromise == null) return null;
    final promise = maybePromise as JSPromise<JSAny?>;
    final value = await promise.toDart;
    if (value == null) return null;
    return value as JSObject;
  }

  HlsAuthWebAttemptResult _attemptFromStatus(JSObject? result) {
    if (result == null) return HlsAuthWebAttemptResult.failure;
    final statusValue = result['status'] as JSString?;
    final status = statusValue?.toDart;
    switch (status) {
      case 'ok':
        return HlsAuthWebAttemptResult.ok;
      case 'requiresAuth':
        return HlsAuthWebAttemptResult.requiresAuth;
      default:
        return HlsAuthWebAttemptResult.failure;
    }
  }
}

@JS('document.createElement')
external JSObject _documentCreateElement(JSString tag);
