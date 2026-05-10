import 'dart:async';
import 'dart:js_interop';

import 'package:openvine/services/web_iframe_nostr_bridge_binding.dart';
import 'package:web/web.dart' as web;

WebIframeNostrBridgeBinding createWebIframeNostrBridgeBindingImpl() =>
    _WebWebIframeNostrBridgeBinding();

class _WebWebIframeNostrBridgeBinding implements WebIframeNostrBridgeBinding {
  web.EventListener? _listener;

  @override
  void start({
    required WebIframeBridgeMessageHandler onMessage,
    required void Function(dynamic message, String targetOrigin)? Function()
    getPostReplyOverride,
  }) {
    final listener = ((web.Event event) {
      final messageEvent = event as web.MessageEvent;
      unawaited(
        onMessage(
          origin: messageEvent.origin,
          data: messageEvent.data.dartify(),
          postReply: (message, targetOrigin) {
            final postReplyOverride = getPostReplyOverride();
            if (postReplyOverride != null) {
              postReplyOverride(message, targetOrigin);
            }
          },
        ),
      );
    }).toJS;
    _listener = listener;
    web.window.addEventListener('message', listener);
  }

  @override
  void stop() {
    final listener = _listener;
    if (listener != null) {
      web.window.removeEventListener('message', listener);
      _listener = null;
    }
  }
}
