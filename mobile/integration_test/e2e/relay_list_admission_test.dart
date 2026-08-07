// ABOUTME: E2E for #6585 — relay lists arriving from the network are
// ABOUTME: authenticated, host-filtered, count-capped, and their sockets
// ABOUTME: released. Runs on-device against local WebSocket relays.
// ABOUTME: Requires: NO Docker stack — every dependency here is local.

@Tags(['service'])
import 'dart:convert';

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

import '../helpers/fake_relay.dart';

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
      final indexer = await FakeRelay.start(
        reply: _signedRelayList(privateKey: authorKey),
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
        final indexer = await FakeRelay.start(reply: entry.value);
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
      final indexer = await FakeRelay.start(
        reply: _signedRelayList(
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
      final indexer = await FakeRelay.start(
        reply: _signedRelayList(
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
      final targets = [for (var i = 0; i < 4; i++) await FakeRelay.start()];
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
