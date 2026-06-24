// ABOUTME: Web-only postMessage host that fulfils Divine embed-bridge requests.
// ABOUTME: An iframe of a first-party Divine app calls window.parent.postMessage
// ABOUTME: with shape { type:'divine:nostr.request', id, method, params }; this
// ABOUTME: bridge dispatches via the active WebSigner and posts the reply back.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:openvine/services/web_auth_service.dart';
import 'package:openvine/services/web_iframe_nostr_bridge_binding.dart';
import 'package:openvine/services/web_iframe_nostr_bridge_binding_factory.dart';
import 'package:unified_logger/unified_logger.dart';

/// postMessage envelope sent from a Divine integrated-app iframe to the host.
///
/// Mirrors the shape produced by `installDivineEmbedBridge()` in the
/// `@divinevideo/signer` package.
class _EmbedRequest {
  _EmbedRequest({
    required this.id,
    required this.method,
    required this.params,
  });

  final num id;
  final String method;
  final Map<String, dynamic> params;
}

/// Listens for `divine:nostr.request` messages from a single child iframe of
/// a known origin and routes them through a [WebSigner] from
/// [WebAuthService]. Construct with [allowedParentOrigin] set to the
/// iframe's origin (e.g. `https://verifier.divine.video`); only messages
/// whose `event.origin` matches that string are honored.
///
/// Lifecycle: call [start] when the iframe mounts and [stop] before it
/// unmounts. Both are idempotent; [stop] is safe to call multiple times.
class WebIframeNostrBridge {
  WebIframeNostrBridge({
    required NostrAppDirectoryEntry app,
    required WebAuthService authService,
  }) : _app = app,
       _auth = authService,
       _binding = createWebIframeNostrBridgeBinding();

  final NostrAppDirectoryEntry _app;
  final WebAuthService _auth;
  final WebIframeNostrBridgeBinding _binding;
  bool _started = false;

  /// Hook for tests to drive the bridge with synthesized messages without
  /// depending on a real `dart:html` `Window`. Not used in production.
  @visibleForTesting
  Future<void> handleMessageForTest({
    required String origin,
    required dynamic data,
    required void Function(dynamic message, String targetOrigin) postReply,
  }) {
    return _handleMessage(origin: origin, data: data, postReply: postReply);
  }

  /// Begin listening for postMessage requests from the iframe. No-op on
  /// non-web platforms. No-op if already started.
  void start() {
    if (!kIsWeb || _started) return;
    _started = true;
    _binding.start(
      onMessage:
          ({
            required String origin,
            required dynamic data,
            required void Function(dynamic message, String targetOrigin)
            postReply,
          }) async {
            await _handleMessage(
              origin: origin,
              data: data,
              postReply: postReply,
            );
          },
      getPostReplyOverride: () => postReplyOverride,
    );
  }

  /// Detach the postMessage listener. Safe to call when not started.
  void stop() {
    if (!kIsWeb || !_started) return;
    _started = false;
    _binding.stop();
  }

  /// Wired by the screen layer to a function that posts to the iframe's
  /// `contentWindow`. The bridge stays unaware of the iframe element.
  void Function(dynamic message, String targetOrigin)? postReplyOverride;

  Future<void> _handleMessage({
    required String origin,
    required dynamic data,
    required void Function(dynamic message, String targetOrigin) postReply,
  }) async {
    if (!_app.allowedOrigins.contains(origin)) return;
    final request = _parseRequest(data);
    if (request == null) return;

    Object? result;
    String? error;
    try {
      result = await _dispatch(request);
    } catch (e, stackTrace) {
      error = e.toString();
      Log.error(
        'Embed bridge dispatch failed for ${request.method}: $e',
        name: 'WebIframeNostrBridge',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
    }

    final reply = <String, dynamic>{
      'type': 'divine:nostr.response',
      'id': request.id,
      if (error != null) 'error': error else 'result': result,
    };
    postReply(reply, origin);
  }

  _EmbedRequest? _parseRequest(dynamic data) {
    if (data is! Map) return null;
    final map = data.cast<dynamic, dynamic>();
    if (map['type'] != 'divine:nostr.request') return null;
    final id = map['id'];
    final method = map['method'];
    if (id is! num || method is! String) return null;
    final params = map['params'];
    return _EmbedRequest(
      id: id,
      method: method,
      params: params is Map
          ? params.map((k, v) => MapEntry(k.toString(), v))
          : <String, dynamic>{},
    );
  }

  Future<Object?> _dispatch(_EmbedRequest request) async {
    final signer = _auth.signer;
    if (signer == null) {
      throw StateError('No active Divine signer — sign in to host');
    }
    if (!_app.allowedMethods.contains(request.method)) {
      throw ArgumentError(
        'Unsupported embed-bridge method: ${request.method}',
      );
    }
    switch (request.method) {
      case 'getPublicKey':
        return _auth.publicKey;
      case 'signEvent':
        final event = request.params['event'];
        if (event is! Map) {
          throw ArgumentError('signEvent: params.event must be an object');
        }
        final unsigned = event.map((k, v) => MapEntry(k.toString(), v));
        final kind = unsigned['kind'];
        if (kind is! num ||
            !_app.allowedSignEventKinds.contains(kind.toInt())) {
          throw ArgumentError(
            'Blocked signEvent kind: ${unsigned['kind']}',
          );
        }
        if (_app.promptRequiredFor.contains('signEvent') ||
            _app.promptRequiredFor.contains('signEvent:${kind.toInt()}')) {
          throw StateError(
            'Prompt-required bridge capabilities are not supported on web',
          );
        }
        final signed = await signer.signEvent(unsigned);
        if (signed == null) {
          throw StateError('Signer returned null — user rejected or failed');
        }
        return signed;
      case 'getRelays':
        // Optional NIP-07 method. We don't expose host relays through the
        // bridge today; return an empty object so the caller falls back
        // to its own relay list.
        return <String, dynamic>{};
      default:
        throw ArgumentError('Blocked embed-bridge method: ${request.method}');
    }
  }
}
