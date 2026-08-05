// ABOUTME: E2E for #6585 — relay lists arriving from the network are
// ABOUTME: authenticated, host-filtered, count-capped, and their sockets
// ABOUTME: released. Runs on-device against local WebSocket relays.
// ABOUTME: Requires: NO Docker stack — every dependency here is local.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/nostr.dart';
import 'package:nostr_sdk/relay/relay_base.dart';
import 'package:nostr_sdk/relay/relay_pool.dart';
import 'package:nostr_sdk/relay/relay_status.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:nostr_sdk/utils/relay_url_policy.dart';
import 'package:openvine/services/relay_discovery_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A relay that answers every REQ with one chosen frame.
///
/// Stands in for an indexer. The point of #6585 is that an indexer is a
/// third-party server, so what it returns is untrusted input no matter that
/// we were the ones who asked.
class _StubIndexer {
  _StubIndexer(this._server, this._reply);

  final HttpServer _server;
  final Map<String, dynamic>? _reply;

  String get url => 'ws://127.0.0.1:${_server.port}';

  static Future<_StubIndexer> start(Map<String, dynamic>? reply) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final indexer = _StubIndexer(server, reply);
    server.listen((req) async {
      // Anything that is not a WebSocket upgrade (a NIP-11 capability probe,
      // a health check) must be answered rather than thrown out of the
      // listener — an async throw here fails the surrounding test.
      if (!WebSocketTransformer.isUpgradeRequest(req)) {
        req.response.statusCode = HttpStatus.badRequest;
        await req.response.close();
        return;
      }
      final socket = await WebSocketTransformer.upgrade(req);
      socket.listen((raw) {
        final frame = jsonDecode(raw as String) as List<dynamic>;
        if (frame.isEmpty || frame[0] != 'REQ') return;
        final subId = frame[1] as String;
        if (indexer._reply != null) {
          socket.add(jsonEncode(<dynamic>['EVENT', subId, indexer._reply]));
        }
        socket.add(jsonEncode(<dynamic>['EOSE', subId]));
      }, onError: (_) {});
    });
    return indexer;
  }

  Future<void> stop() => _server.close(force: true);
}

/// A relay that accepts the connection and then says nothing — the shape a
/// listener takes when its only purpose is to be connected to.
class _SilentRelay {
  _SilentRelay(this._server);

  final HttpServer _server;
  final List<WebSocket> _sockets = [];

  String get url => 'ws://127.0.0.1:${_server.port}';
  int get openSockets =>
      _sockets.where((s) => s.readyState == WebSocket.open).length;

  static Future<_SilentRelay> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final relay = _SilentRelay(server);
    server.listen((req) async {
      if (!WebSocketTransformer.isUpgradeRequest(req)) {
        req.response.statusCode = HttpStatus.badRequest;
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

Map<String, dynamic> _signedRelayList({
  required String privateKey,
  List<List<String>> tags = const [
    ['r', 'wss://legit.example'],
  ],
  int kind = 10002,
}) {
  final event = Event(
    getPublicKey(privateKey),
    kind,
    tags,
    '',
    createdAt: 1700000000,
  )..sign(privateKey);
  return event.toJson();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const authorKey =
      '1111111111111111111111111111111111111111111111111111111111111111';
  final authorPubkey = getPublicKey(authorKey);

  group('#6585 relay-list admission', () {
    testWidgets('a correctly signed kind-10002 is admitted', (tester) async {
      final indexer = await _StubIndexer.start(
        _signedRelayList(privateKey: authorKey),
      );
      addTearDown(indexer.stop);

      final relays = await RelayDiscoveryService(
        indexerRelays: [indexer.url],
      ).queryIndexerDirect(indexer.url, authorPubkey);

      // Positive control: without this, every rejection below could be
      // passing because nothing was ever delivered.
      expect(relays.map((r) => r.url), ['wss://legit.example']);
    });

    testWidgets("a frame that is not the author's kind-10002 is refused", (
      tester,
    ) async {
      const otherKey =
          '2222222222222222222222222222222222222222222222222222222222222222';

      final cases = <String, Map<String, dynamic>>{
        'no signature': _signedRelayList(privateKey: authorKey)..['sig'] = '',
        'signed by someone else': _signedRelayList(privateKey: otherKey),
        'wrong kind': _signedRelayList(privateKey: authorKey, kind: 1),
        'id does not match its contents':
            _signedRelayList(privateKey: authorKey)
              ..['tags'] = [
                ['r', 'wss://swapped-in.example'],
              ],
        'not an event at all': {
          'tags': [
            ['r', 'wss://bare-tags.example'],
          ],
        },
      };

      for (final entry in cases.entries) {
        final indexer = await _StubIndexer.start(entry.value);
        addTearDown(indexer.stop);
        final relays = await RelayDiscoveryService(
          indexerRelays: [indexer.url],
        ).queryIndexerDirect(indexer.url, authorPubkey);
        expect(relays, isEmpty, reason: entry.key);
      }
    });

    testWidgets("an admitted list cannot name this device's own network", (
      tester,
    ) async {
      final indexer = await _StubIndexer.start(
        _signedRelayList(
          privateKey: authorKey,
          tags: const [
            ['r', 'wss://public.example'],
            ['r', 'wss://192.168.1.50'],
            ['r', 'wss://10.1.2.3'],
            ['r', 'wss://127.0.0.1'],
            ['r', 'wss://169.254.169.254'],
            ['r', 'wss://[fe80::1]'],
            ['r', 'wss://2130706433'],
            ['r', 'wss://nas.local'],
            ['r', 'ws://cleartext.example'],
          ],
        ),
      );
      addTearDown(indexer.stop);

      final relays = await RelayDiscoveryService(
        indexerRelays: [indexer.url],
      ).queryIndexerDirect(indexer.url, authorPubkey);

      expect(relays.map((r) => r.url), ['wss://public.example']);
    });

    testWidgets('one relay list cannot inject an unbounded set', (
      tester,
    ) async {
      final indexer = await _StubIndexer.start(
        _signedRelayList(
          privateKey: authorKey,
          tags: [
            for (var i = 0; i < 200; i++) ['r', 'wss://flood-$i.example'],
          ],
        ),
      );
      addTearDown(indexer.stop);

      final relays = await RelayDiscoveryService(
        indexerRelays: [indexer.url],
      ).queryIndexerDirect(indexer.url, authorPubkey);

      expect(relays, hasLength(RelayListCaps.nip65));
      expect(relays.first.url, 'wss://flood-0.example');
    });

    testWidgets('a cached list is re-admitted on read, not just on write', (
      tester,
    ) async {
      // The cache outlives the write by 24h, so an entry persisted by an
      // older build must not be adopted unchecked.
      const npub = 'npub1e2eadmissiontest';
      SharedPreferences.setMockInitialValues({
        'relay_discovery_$npub': jsonEncode({
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'relays': [
            {'url': 'wss://public.example', 'read': true, 'write': true},
            {'url': 'wss://192.168.1.50', 'read': true, 'write': true},
            {'url': 'wss://127.0.0.1', 'read': true, 'write': true},
            {'url': 'wss://169.254.169.254', 'read': true, 'write': true},
            {'url': 'ws://cleartext.example', 'read': true, 'write': true},
            for (var i = 0; i < 40; i++)
              {'url': 'wss://cached-$i.example', 'read': true, 'write': true},
          ],
        }),
      });

      final result = await RelayDiscoveryService(
        indexerRelays: const ['ws://127.0.0.1:1'],
      ).discoverRelays(npub);

      expect(result.relays, hasLength(RelayListCaps.nip65));
      expect(
        result.relays.map((r) => r.url),
        isNot(anyElement(contains('192.168'))),
      );
      expect(
        result.relays.map((r) => r.url),
        isNot(anyElement(contains('127.0.0.1'))),
      );
      expect(
        result.relays.map((r) => r.url),
        isNot(anyElement(contains('169.254'))),
      );
    });

    testWidgets('sockets opened for a publish are released once idle', (
      tester,
    ) async {
      final targets = [for (var i = 0; i < 4; i++) await _SilentRelay.start()];
      addTearDown(() async {
        for (final relay in targets) {
          await relay.stop();
        }
      });
      final urls = [for (final relay in targets) relay.url];

      final signer = LocalNostrSigner(authorKey);
      RelayBase gen(String url) => RelayBase(url, RelayStatus(url));
      final pool = RelayPool(
        Nostr(signer, [], gen),
        [],
        gen,
        tempRelayIdleTimeout: Duration.zero,
        tempRelaySweepInterval: const Duration(hours: 1),
      );

      final wrap = Event(authorPubkey, 1059, [], 'probe')..sign(authorKey);
      await pool.sendEventAwaitOk(
        ['EVENT', wrap.toJson()],
        eventId: wrap.id,
        eventKind: wrap.kind,
        tempRelays: urls,
        targetRelays: urls,
        timeout: const Duration(seconds: 2),
      );

      // NIP-17 requires publishing to the relays the recipient named, so the
      // connections are expected — what #6585 changes is that they end.
      expect(pool.tempRelayUrls, hasLength(4));
      expect(targets.every((r) => r.openSockets > 0), isTrue);

      pool.sweepIdleTempRelays();
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(pool.tempRelayUrls, isEmpty);
      for (final relay in targets) {
        expect(relay.openSockets, isZero, reason: relay.url);
      }
    });
  });
}
