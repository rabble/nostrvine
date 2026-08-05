// ABOUTME: Pins that temp relays opened for a publish are closed once idle.
// ABOUTME: Before #6585 nothing ever closed them, so a publish to addresses a
// ABOUTME: counterparty chose left a socket open per address for the session.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/nostr.dart';
import 'package:nostr_sdk/relay/relay_base.dart';
import 'package:nostr_sdk/relay/relay_pool.dart';
import 'package:nostr_sdk/relay/relay_status.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:nostr_sdk/utils/relay_addr_util.dart';

/// A relay that accepts the upgrade and then stays silent — the worst case a
/// listener can present, and the one that used to keep its socket forever.
class _SilentRelay {
  _SilentRelay(this._server);

  final HttpServer _server;
  final List<WebSocket> _sockets = [];

  String get url => 'ws://127.0.0.1:${_server.port}';

  /// The key a *subscribe* stores this relay under.
  ///
  /// `subscribe` normalises its `tempRelays` through [RelayAddrUtil.handle]
  /// (which appends a trailing slash) while the publish path does not, so the
  /// two enter `_tempRelays` under different keys for the same host. Tests
  /// assert on [RelayPool.tempRelayUrls] rather than guessing, because a
  /// lookup with the wrong key misses and makes a cleanup assertion vacuous.
  String get subscribeKey => RelayAddrUtil.handle(url);

  /// Sockets this listener still has open, from the *server's* point of view.
  int get openSockets =>
      _sockets.where((s) => s.readyState == WebSocket.open).length;

  static Future<_SilentRelay> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final relay = _SilentRelay(server);
    server.listen((req) async {
      if (!WebSocketTransformer.isUpgradeRequest(req)) {
        req.response.statusCode = 400;
        await req.response.close();
        return;
      }
      final socket = await WebSocketTransformer.upgrade(req);
      relay._sockets.add(socket);
      socket.listen((_) {}, onError: (_) {});
    });
    return relay;
  }

  Future<void> stop() async {
    for (final socket in _sockets) {
      await socket.close().catchError((_) => null);
    }
    await _server.close(force: true);
  }
}

void main() {
  late List<_SilentRelay> relays;

  setUp(() => relays = []);

  tearDown(() async {
    for (final relay in relays) {
      await relay.stop();
    }
  });

  Future<_SilentRelay> startRelay() async {
    final relay = await _SilentRelay.start();
    relays.add(relay);
    return relay;
  }

  /// Builds a pool with a short idle window so the sweep is observable
  /// without a wall-clock wait. The sweep is driven manually in these tests.
  RelayPool buildPool() {
    final signer = LocalNostrSigner(
      '0000000000000000000000000000000000000000000000000000000000000001',
    );
    final nostr = Nostr(signer, [], (url) => RelayBase(url, RelayStatus(url)));
    return RelayPool(
      nostr,
      [],
      (url) => RelayBase(url, RelayStatus(url)),
      tempRelayIdleTimeout: Duration.zero,
      tempRelaySweepInterval: const Duration(hours: 1),
    );
  }

  Future<Event> signedGiftWrap(RelayPool pool) async {
    final signer = pool.localNostr.nostrSigner;
    final pubkey = await signer.getPublicKey();
    final event = Event(pubkey!, 1059, [], 'probe');
    final signed = await signer.signEvent(event);
    return signed!;
  }

  test(
    'closes the temp relays a publish opened once they go idle',
    () async {
      final targets = [for (var i = 0; i < 5; i++) await startRelay()];
      final urls = [for (final relay in targets) relay.url];
      final pool = buildPool();
      final event = await signedGiftWrap(pool);

      await pool.sendEventAwaitOk(
        ['EVENT', event.toJson()],
        eventId: event.id,
        eventKind: event.kind,
        tempRelays: urls,
        targetRelays: urls,
        timeout: const Duration(seconds: 2),
      );

      // Every address got a socket — that is the behaviour #6585 bounds, not
      // removes: NIP-17 requires publishing to the recipient's own relays.
      expect(
        targets.every((relay) => relay.openSockets > 0),
        isTrue,
        reason: 'publish should reach every target',
      );
      expect(pool.tempRelayUrls, hasLength(5));

      pool.sweepIdleTempRelays();
      // Let the close frames land on the listeners.
      await Future<void>.delayed(const Duration(milliseconds: 300));

      for (final relay in targets) {
        expect(
          relay.openSockets,
          isZero,
          reason: 'idle temp relay ${relay.url} should have been closed',
        );
      }
      expect(pool.tempRelayUrls, isEmpty);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'leaves a temp relay alone while it is still serving a subscription',
    () async {
      final target = await startRelay();
      final pool = buildPool();

      pool.subscribe(
        [
          Filter(kinds: [1], limit: 1).toJson(),
        ],
        (_) {},
        tempRelays: [target.url],
        id: 'sub-under-sweep',
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));

      pool.sweepIdleTempRelays();
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(
        pool.tempRelayUrls,
        contains(target.subscribeKey),
        reason: 'a relay carrying a live subscription must not be swept',
      );
      expect(target.openSockets, greaterThan(0));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'removeAll closes temp relays and stops the sweep',
    () async {
      final target = await startRelay();
      final pool = buildPool();
      final event = await signedGiftWrap(pool);

      await pool.sendEventAwaitOk(
        ['EVENT', event.toJson()],
        eventId: event.id,
        eventKind: event.kind,
        tempRelays: [target.url],
        targetRelays: [target.url],
        timeout: const Duration(seconds: 2),
      );
      expect(pool.tempRelayUrls, hasLength(1));

      pool.removeAll();
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(pool.tempRelayUrls, isEmpty);
      expect(target.openSockets, isZero);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
