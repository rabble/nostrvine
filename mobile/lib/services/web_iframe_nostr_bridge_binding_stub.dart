typedef WebIframeBridgeMessageHandler =
    Future<void> Function({
      required String origin,
      required dynamic data,
      required void Function(dynamic message, String targetOrigin) postReply,
    });

abstract class WebIframeNostrBridgeBinding {
  void start({
    required WebIframeBridgeMessageHandler onMessage,
    required void Function(dynamic message, String targetOrigin)?
        Function()
        getPostReplyOverride,
  });

  void stop();
}

WebIframeNostrBridgeBinding createWebIframeNostrBridgeBinding() =>
    _StubWebIframeNostrBridgeBinding();

class _StubWebIframeNostrBridgeBinding implements WebIframeNostrBridgeBinding {
  @override
  void start({
    required WebIframeBridgeMessageHandler onMessage,
    required void Function(dynamic message, String targetOrigin)?
        Function()
        getPostReplyOverride,
  }) {}

  @override
  void stop() {}
}
