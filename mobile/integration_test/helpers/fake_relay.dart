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
/// - with [broadcast], `EVENT` is also forwarded to every OTHER open
///   subscription, which is what a multi-party test needs
class FakeRelay {
  FakeRelay._(
    this._server,
    this.reply,
    this.replyForKinds,
    this.okConfirms,
    this.broadcast,
    this.stallReqForKinds,
    this.stallReqForAuthors,
  );

  /// Starts a relay on a loopback port — ephemeral unless [port] is given.
  ///
  /// [reply] is the event served for any `REQ`; null answers `EOSE` only.
  /// [replyForKinds] narrows that to `REQ` frames naming one of those kinds,
  /// so a relay can hand back a kind-10050 to the inbox lookup while every
  /// other subscription still reads as empty.
  /// Set [okConfirms] false to model a relay that accepts the frame but never
  /// confirms it. Set [broadcast] true to fan a published `EVENT` out to every
  /// other open subscription — off by default so existing tests, which assert
  /// on what the relay was *sent*, see no extra traffic.
  /// [stallReqForKinds] models a relay that accepts a `REQ` and never
  /// terminates it: no `EVENT`, no `EOSE`. That is the only shape that makes
  /// `queryEventsDetailed` report `timedOut` — an `EOSE` is a conclusive
  /// "nothing here", so a relay answering EOSE cannot stand in for one that
  /// could not be read.
  /// [stallReqForAuthors] does the same, but keyed on the `authors` a `REQ`
  /// names rather than its kinds. A group fan-out resolves each recipient's
  /// kind-10050 in its own `REQ`, so this is what lets ONE recipient's inbox
  /// read as `found` while another's is `unreadable` in the same send — the
  /// partially-unreadable fan-out #8434 is about. A kind-keyed stall cannot
  /// express that: it stalls every recipient at once.
  /// Pass a stopped relay's [FakeRelay.port] as [port] to bring "the same
  /// relay" back, which is what a client that remembers the URL sees when a
  /// relay recovers.
  static Future<FakeRelay> start({
    Map<String, dynamic>? reply,
    Set<int> replyForKinds = const <int>{},
    bool okConfirms = true,
    bool broadcast = false,
    Set<int> stallReqForKinds = const <int>{},
    Set<String> stallReqForAuthors = const <String>{},
    int port = 0,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    final relay = FakeRelay._(
      server,
      reply,
      replyForKinds,
      okConfirms,
      broadcast,
      stallReqForKinds,
      stallReqForAuthors,
    );
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

  /// Kinds whose `REQ` is answered with [reply]; empty means every `REQ`.
  final Set<int> replyForKinds;

  /// Whether an inbound `EVENT` is answered with `OK … true`.
  final bool okConfirms;

  /// Kinds whose `REQ` is swallowed rather than answered.
  ///
  /// A subscription whose filter names one of these gets neither `EVENT` nor
  /// `EOSE`, so the read never settles and the client reports it as timed out
  /// rather than empty. Other subscriptions on the same socket are unaffected.
  final Set<int> stallReqForKinds;

  /// Authors whose `REQ` is swallowed rather than answered.
  ///
  /// Same shape as [stallReqForKinds] — neither `EVENT` nor `EOSE`, so the
  /// read times out instead of settling empty — but selective per pubkey, so a
  /// fan-out can have a readable recipient and an unreadable one at once.
  final Set<String> stallReqForAuthors;

  /// Whether a published `EVENT` is forwarded to other open subscriptions.
  ///
  /// Gift wraps are addressed by their outer `p` tag, and every party in a
  /// multi-recipient test subscribes for its own pubkey, so this fans out to
  /// every live subscription and lets each client's own filter decide. That
  /// is coarser than a real relay but sufficient: the client discards wraps
  /// it cannot decrypt.
  final bool broadcast;

  /// Live subscriptions per socket, so a broadcast can address them.
  final Map<WebSocket, Set<String>> _subscriptions = {};

  /// How many `EVENT` frames this relay has fanned out to subscribers.
  /// Lets a multi-party test tell "the relay never forwarded it" apart from
  /// "the client received it and dropped it".
  int fannedOutFrames = 0;

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
    _subscriptions[socket] = <String>{};

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
          _subscriptions[socket]?.add(subId);
          if (_isStalled(frame)) return;
          if (reply != null && _wantsReply(frame)) {
            send(<dynamic>['EVENT', subId, reply]);
          }
          send(<dynamic>['EOSE', subId]);
        } else if (frame[0] == 'CLOSE' && frame.length >= 2) {
          _subscriptions[socket]?.remove(frame[1] as String);
        } else if (frame[0] == 'EVENT' && frame.length >= 2) {
          final event = frame[1] as Map<String, dynamic>;
          if (okConfirms) {
            send(<dynamic>['OK', event['id'], true, '']);
          }
          if (broadcast) _fanOut(from: socket, event: event);
        }
      },
      onError: (_) {},
    );
  }

  /// Whether this `REQ` frame names a kind in [stallReqForKinds] or an author
  /// in [stallReqForAuthors].
  bool _isStalled(List<dynamic> frame) =>
      (stallReqForKinds.isNotEmpty && _namesAnyKind(frame, stallReqForKinds)) ||
      (stallReqForAuthors.isNotEmpty &&
          _namesAnyAuthor(frame, stallReqForAuthors));

  /// Whether [reply] is owed to this `REQ` frame; see [replyForKinds].
  bool _wantsReply(List<dynamic> frame) =>
      replyForKinds.isEmpty || _namesAnyKind(frame, replyForKinds);

  bool _namesAnyKind(List<dynamic> frame, Set<int> wanted) {
    for (final filter in frame.skip(2)) {
      if (filter is! Map) continue;
      final kinds = filter['kinds'];
      if (kinds is! List) continue;
      for (final kind in kinds) {
        if (kind is int && wanted.contains(kind)) return true;
      }
    }
    return false;
  }

  bool _namesAnyAuthor(List<dynamic> frame, Set<String> wanted) {
    for (final filter in frame.skip(2)) {
      if (filter is! Map) continue;
      final authors = filter['authors'];
      if (authors is! List) continue;
      for (final author in authors) {
        if (author is String && wanted.contains(author)) return true;
      }
    }
    return false;
  }

  /// Forwards [event] to every open subscription except the publisher's own.
  void _fanOut({required WebSocket from, required Map<String, dynamic> event}) {
    for (final entry in _subscriptions.entries) {
      final target = entry.key;
      if (identical(target, from)) continue;
      if (target.readyState != WebSocket.open) continue;
      for (final subId in entry.value) {
        try {
          target.add(jsonEncode(<dynamic>['EVENT', subId, event]));
          fannedOutFrames++;
          // Only an Error distinguishes "the client hung up" here.
          // ignore: avoid_catching_errors
        } on StateError {
          // Subscriber went away mid-broadcast; nothing to deliver.
        }
      }
    }
  }

  Future<void> stop() async {
    _subscriptions.clear();
    for (final socket in _sockets) {
      await socket.close().catchError((_) => null);
    }
    await _server.close(force: true);
  }
}
