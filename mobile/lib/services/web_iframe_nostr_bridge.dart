// ABOUTME: Web-only postMessage host that fulfils Divine embed-bridge requests.
// ABOUTME: An iframe of a first-party Divine app calls window.parent.postMessage
// ABOUTME: with shape { type:'divine:nostr.request', id, method, params }; this
// ABOUTME: bridge dispatches via the active WebSigner and posts the reply back.

import 'dart:async';
// TODO(#3933): migrate to package:web + dart:js_interop once the rest of the
// codebase moves off dart:html.
// ignore: deprecated_member_use
import 'dart:html'
    if (dart.library.io) 'package:openvine/services/web_iframe_nostr_bridge_stub.dart'
    as html;

import 'package:flutter/foundation.dart';
import 'package:openvine/services/web_auth_service.dart';
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
/// iframe's origin (e.g. `https://verifyer.divine.video`); only messages
/// whose `event.origin` matches that string are honored.
///
/// Lifecycle: call [start] when the iframe mounts and [stop] before it
/// unmounts. Both are idempotent; [stop] is safe to call multiple times.
class WebIframeNostrBridge {
  WebIframeNostrBridge({
    required this.allowedChildOrigin,
    required WebAuthService authService,
  }) : _auth = authService;

  /// The exact origin string of the embedded iframe whose messages we
  /// will honor (e.g. `https://verifyer.divine.video`). Compared against
  /// `MessageEvent.origin` with `==`.
  final String allowedChildOrigin;

  final WebAuthService _auth;
  void Function(html.Event)? _listener;
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
    final listener = _onMessage;
    _listener = listener;
    html.window.addEventListener('message', listener);
  }

  /// Detach the postMessage listener. Safe to call when not started.
  void stop() {
    if (!kIsWeb || !_started) return;
    _started = false;
    final listener = _listener;
    if (listener != null) {
      html.window.removeEventListener('message', listener);
      _listener = null;
    }
  }

  void _onMessage(html.Event event) {
    final msg = event as html.MessageEvent;
    final origin = msg.origin;
    final data = msg.data;
    // Default postReply uses the inbound message's source if present;
    // dart:html's MessageEvent doesn't expose `source` ergonomically, so
    // we round-trip through window.parent. The iframe is always our
    // child, and divine.video has at most one verifyer iframe at a time,
    // so addressing window.parent is fine in production. The test hook
    // takes a custom postReply.
    unawaited(
      _handleMessage(
        origin: origin,
        data: data,
        postReply: (message, targetOrigin) {
          // The iframe is a child window — we can't postMessage to a
          // child via window.parent. Production posts via the iframe's
          // contentWindow which the screen passes in. To keep this
          // class decoupled from the iframe element, we expose
          // [postReplyOverride] for the screen layer to wire up.
          final overrideFn = postReplyOverride;
          if (overrideFn != null) {
            overrideFn(message, targetOrigin);
          }
        },
      ),
    );
  }

  /// Wired by the screen layer to a function that posts to the iframe's
  /// `contentWindow`. The bridge stays unaware of the iframe element.
  void Function(dynamic message, String targetOrigin)? postReplyOverride;

  Future<void> _handleMessage({
    required String origin,
    required dynamic data,
    required void Function(dynamic message, String targetOrigin) postReply,
  }) async {
    if (origin != allowedChildOrigin) return;
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
    postReply(reply, allowedChildOrigin);
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
    switch (request.method) {
      case 'getPublicKey':
        return _auth.publicKey;
      case 'signEvent':
        final event = request.params['event'];
        if (event is! Map) {
          throw ArgumentError('signEvent: params.event must be an object');
        }
        final unsigned = event.map((k, v) => MapEntry(k.toString(), v));
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
        throw ArgumentError(
          'Unsupported embed-bridge method: ${request.method}',
        );
    }
  }
}
