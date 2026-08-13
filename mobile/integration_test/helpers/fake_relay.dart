// ABOUTME: In-process WebSocket relay for integration tests that need to
// ABOUTME: control exactly what a relay says, without the Docker stack.
// ABOUTME: Answers REQ with a chosen EVENT, OK-confirms inbound EVENTs, and
// ABOUTME: records what it was sent.

import 'dart:convert';
import 'dart:io';

/// A Nostr relay that runs inside the test process.
///
/// Exists because the local Docker relay cannot serve the kinds these tests
/// need (see #6594 — the pinned funnelcake images predate gift-wrap support),
/// and because a test that asserts *which* relays were dialed has to own both
/// ends of the connection.
///
/// Speaks only the subset of the protocol these tests exercise:
/// - `REQ` → the configured [reply] event (if any), then `EOSE`
/// - `EVENT` → `["OK", <id>, true, ""]`, so an OK-confirmed publish settles
///   instead of timing out into `retryablePending`
class FakeRelay {
  FakeRelay._(this._server, this.reply, this.okConfirms);

  /// Starts a relay on an ephemeral loopback port.
  ///
  /// [reply] is the event served for any `REQ`; null answers `EOSE` only.
  /// Set [okConfirms] false to model a relay that accepts the frame but never
  /// confirms it.
  static Future<FakeRelay> start({
    Map<String, dynamic>? reply,
    bool okConfirms = true,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final relay = FakeRelay._(server, reply, okConfirms);
    server.listen(relay._handle, onError: (_) {});
    return relay;
  }

  final HttpServer _server;
  final List<WebSocket> _sockets = [];

  /// The event served in response to any `REQ`, or null for `EOSE` only.
  ///
  /// Mutable so a test can stage what a later session reads back — this relay
  /// records what it is handed but does not serve it, so "publish, then open a
  /// cold session that loads it" has to be staged explicitly.
  Map<String, dynamic>? reply;

  /// Whether an inbound `EVENT` is answered with `OK … true`.
  final bool okConfirms;

  /// Every frame this relay received, in arrival order.
  final List<List<dynamic>> receivedFrames = [];

  /// The `ws://` address of this relay.
  String get url => 'ws://127.0.0.1:${_server.port}';

  /// The port, for a channel factory that redirects other hosts here.
  int get port => _server.port;

  /// Sockets still open from the server's point of view.
  int get openSockets =>
      _sockets.where((s) => s.readyState == WebSocket.open).length;

  /// Event ids this relay was asked to store.
  List<String> get publishedEventIds => [
    for (final frame in receivedFrames)
      if (frame.isNotEmpty &&
          frame[0] == 'EVENT' &&
          frame.length >= 2 &&
          frame[1] is Map)
        (frame[1] as Map)['id'] as String,
  ];

  Future<void> _handle(HttpRequest req) async {
    // `RelayBase.doConnect` probes NIP-11 over plain HTTP before upgrading.
    // Answering rather than throwing matters: an async throw out of this
    // listener fails whatever test happens to be running.
    if (!WebSocketTransformer.isUpgradeRequest(req)) {
      req.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType('application', 'nostr+json')
        ..write(jsonEncode({'name': 'fake-relay', 'supported_nips': <int>[]}));
      await req.response.close();
      return;
    }

    final socket = await WebSocketTransformer.upgrade(req);
    _sockets.add(socket);

    // A client can close mid-exchange, and `readyState` still reads as open
    // for a moment after the sink is gone. An unguarded write then throws
    // asynchronously and is attributed to whichever test is running next.
    void send(List<dynamic> message) {
      try {
        socket.add(jsonEncode(message));
        // Only an Error distinguishes "the client hung up" here.
        // ignore: avoid_catching_errors
      } on StateError {
        // Client went away; nothing to answer.
      }
    }

    socket.listen(
      (raw) {
        final List<dynamic> frame;
        try {
          frame = jsonDecode(raw as String) as List<dynamic>;
        } on Object {
          return;
        }
        receivedFrames.add(frame);
        if (frame.isEmpty) return;

        if (frame[0] == 'REQ' && frame.length >= 2) {
          final subId = frame[1] as String;
          if (reply != null) {
            send(<dynamic>['EVENT', subId, reply]);
          }
          send(<dynamic>['EOSE', subId]);
        } else if (frame[0] == 'EVENT' && frame.length >= 2 && okConfirms) {
          final event = frame[1] as Map<String, dynamic>;
          send(<dynamic>['OK', event['id'], true, '']);
        }
      },
      onError: (_) {},
    );
  }

  Future<void> stop() async {
    for (final socket in _sockets) {
      await socket.close().catchError((_) => null);
    }
    await _server.close(force: true);
  }
}
