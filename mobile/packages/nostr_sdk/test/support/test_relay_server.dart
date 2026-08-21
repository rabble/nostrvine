// ABOUTME: In-process WebSocket relay stand-in for nostr_sdk NIP-46 tests.
// ABOUTME: Counts sockets opened and closed so leaks are directly observable.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A loopback WebSocket server that stands in for a relay.
///
/// [connectionCount] is the point of the harness: a socket opened by a
/// reconnect that should never have run shows up here even though nothing in
/// the app holds a reference to it any more.
class TestRelayServer {
  TestRelayServer._(this._server) {
    _requests = _server.listen(_handleRequest);
  }

  final HttpServer _server;
  final _sockets = <WebSocket>[];
  final receivedMessages = <List<dynamic>>[];
  late final StreamSubscription<HttpRequest> _requests;

  /// How many sockets clients have opened over this server's lifetime.
  int connectionCount = 0;

  /// How many of those have since closed, from either end — a client
  /// teardown, [dropConnections], or [close].
  int closedConnectionCount = 0;

  bool _closed = false;

  String get url => 'ws://127.0.0.1:${_server.port}';

  /// Sockets that are still open — the leak this harness exists to catch.
  ///
  /// A server-side drop counts as closed too, so a test that calls
  /// [dropConnections] and then sees this climb back is watching the client
  /// dial a socket nothing is left holding.
  int get openConnectionCount => connectionCount - closedConnectionCount;

  static Future<TestRelayServer> start({int? port}) async {
    final server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      port ?? 0,
    );
    return TestRelayServer._(server);
  }

  /// Sends a relay message (e.g. `['EVENT', subId, eventJson]`) to every
  /// connected client. Callers ignore the subscription id, so any value works.
  void push(Object message) {
    final text = jsonEncode(message);
    for (final socket in _sockets) {
      socket.add(text);
    }
  }

  /// Drops every live socket while the server keeps listening, so a client
  /// sees its connection die and can dial back in.
  Future<void> dropConnections() async {
    final live = List<WebSocket>.of(_sockets);
    _sockets.clear();
    for (final socket in live) {
      await socket.close();
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }

    final socket = await WebSocketTransformer.upgrade(request);
    _sockets.add(socket);
    connectionCount += 1;
    socket.listen(
      (message) {
        receivedMessages.add(jsonDecode(message as String) as List<dynamic>);
      },
      onDone: () => closedConnectionCount += 1,
      onError: (Object _) {},
    );
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final socket in _sockets) {
      await socket.close();
    }
    await _requests.cancel();
    await _server.close(force: true);
  }
}
