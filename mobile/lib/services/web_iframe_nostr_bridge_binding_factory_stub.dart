import 'package:openvine/services/web_iframe_nostr_bridge_binding.dart';

WebIframeNostrBridgeBinding createWebIframeNostrBridgeBindingImpl() =>
    _StubWebIframeNostrBridgeBinding();

class _StubWebIframeNostrBridgeBinding implements WebIframeNostrBridgeBinding {
  @override
  void start({
    required WebIframeBridgeMessageHandler onMessage,
    required void Function(dynamic message, String targetOrigin)? Function()
    getPostReplyOverride,
  }) {}

  @override
  void stop() {}
}
