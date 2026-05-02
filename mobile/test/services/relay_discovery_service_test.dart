// ABOUTME: Tests for RelayDiscoveryService first-success pattern
// ABOUTME: Verifies that discoverRelays returns as soon as any indexer
// ABOUTME: succeeds, rather than waiting for all indexers to complete

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/relay_discovery_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Test subclass that overrides WebSocket-based queryIndexerDirect
/// with controllable futures.
class _TestableRelayDiscoveryService extends RelayDiscoveryService {
  _TestableRelayDiscoveryService({
    required List<String> indexerRelays,
    required this.queryHandler,
  }) : super(indexerRelays: indexerRelays);

  final Future<List<DiscoveredRelay>> Function(String indexerUrl) queryHandler;

  @override
  Future<List<DiscoveredRelay>> queryIndexerDirect(
    String indexerUrl,
    String pubkeyHex,
  ) {
    return queryHandler(indexerUrl);
  }
}

// Valid npub for testing (encodes to a valid hex pubkey)
const _testNpub =
    'npub1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqsutm2dy';

void main() {
  group(RelayDiscoveryService, () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    group('discoverRelays - first success pattern', () {
      test(
        'returns immediately when first indexer responds with relays',
        () async {
          final indexer1Completer = Completer<List<DiscoveredRelay>>();
          final indexer2Completer = Completer<List<DiscoveredRelay>>();
          final indexer3Completer = Completer<List<DiscoveredRelay>>();

          final completers = {
            'wss://indexer1': indexer1Completer,
            'wss://indexer2': indexer2Completer,
            'wss://indexer3': indexer3Completer,
          };

          final service = _TestableRelayDiscoveryService(
            indexerRelays: completers.keys.toList(),
            queryHandler: (url) => completers[url]!.future,
          );

          final resultFuture = service.discoverRelays(_testNpub);

          // Only first indexer responds
          indexer1Completer.complete([
            const DiscoveredRelay(url: 'wss://relay.example.com'),
          ]);

          final result = await resultFuture;

          expect(result.success, isTrue);
          expect(result.relays, hasLength(1));
          expect(result.relays.first.url, equals('wss://relay.example.com'));
          expect(result.foundOnIndexer, equals('wss://indexer1'));

          // Other indexers never completed - proves we didn't wait for them
          expect(indexer2Completer.isCompleted, isFalse);
          expect(indexer3Completer.isCompleted, isFalse);
        },
      );

      test(
        'returns result from second indexer when first returns empty',
        () async {
          final indexer1Completer = Completer<List<DiscoveredRelay>>();
          final indexer2Completer = Completer<List<DiscoveredRelay>>();
          final indexer3Completer = Completer<List<DiscoveredRelay>>();

          final completers = {
            'wss://indexer1': indexer1Completer,
            'wss://indexer2': indexer2Completer,
            'wss://indexer3': indexer3Completer,
          };

          final service = _TestableRelayDiscoveryService(
            indexerRelays: completers.keys.toList(),
            queryHandler: (url) => completers[url]!.future,
          );

          final resultFuture = service.discoverRelays(_testNpub);

          // First returns empty, second returns relays
          indexer1Completer.complete(<DiscoveredRelay>[]);
          indexer2Completer.complete([
            const DiscoveredRelay(url: 'wss://relay.from-second.com'),
          ]);

          final result = await resultFuture;

          expect(result.success, isTrue);
          expect(result.foundOnIndexer, equals('wss://indexer2'));

          // Third never needed
          expect(indexer3Completer.isCompleted, isFalse);
        },
      );

      test('returns failure when all indexers return empty', () async {
        final service = _TestableRelayDiscoveryService(
          indexerRelays: ['wss://a', 'wss://b', 'wss://c'],
          queryHandler: (_) async => <DiscoveredRelay>[],
        );

        final result = await service.discoverRelays(_testNpub);

        expect(result.success, isFalse);
        expect(result.errorMessage, equals('No relay list found'));
      });

      test('returns failure when all indexers throw', () async {
        final service = _TestableRelayDiscoveryService(
          indexerRelays: ['wss://a', 'wss://b'],
          queryHandler: (_) async => throw Exception('connection refused'),
        );

        final result = await service.discoverRelays(_testNpub);

        expect(result.success, isFalse);
        expect(result.errorMessage, equals('No relay list found'));
      });

      test(
        'returns result when one indexer succeeds and others throw',
        () async {
          final service = _TestableRelayDiscoveryService(
            indexerRelays: ['wss://bad1', 'wss://good', 'wss://bad2'],
            queryHandler: (url) async {
              if (url == 'wss://good') {
                return [const DiscoveredRelay(url: 'wss://relay.example.com')];
              }
              throw Exception('connection refused');
            },
          );

          final result = await service.discoverRelays(_testNpub);

          expect(result.success, isTrue);
          expect(result.foundOnIndexer, equals('wss://good'));
        },
      );

      test('does not wait for slow indexer when fast one succeeds', () async {
        final slowCompleter = Completer<List<DiscoveredRelay>>();

        final service = _TestableRelayDiscoveryService(
          indexerRelays: ['wss://slow', 'wss://fast'],
          queryHandler: (url) {
            if (url == 'wss://slow') return slowCompleter.future;
            return Future.value([
              const DiscoveredRelay(url: 'wss://relay.fast.com'),
            ]);
          },
        );

        final result = await service.discoverRelays(_testNpub);

        expect(result.success, isTrue);
        expect(result.foundOnIndexer, equals('wss://fast'));
        // Slow indexer still pending - we didn't block on it
        expect(slowCompleter.isCompleted, isFalse);
      });

      test('handles single indexer returning relays', () async {
        final service = _TestableRelayDiscoveryService(
          indexerRelays: ['wss://only-one'],
          queryHandler: (_) async => [
            const DiscoveredRelay(url: 'wss://relay.solo.com'),
          ],
        );

        final result = await service.discoverRelays(_testNpub);

        expect(result.success, isTrue);
        expect(result.relays, hasLength(1));
      });

      test('handles single indexer returning empty', () async {
        final service = _TestableRelayDiscoveryService(
          indexerRelays: ['wss://only-one'],
          queryHandler: (_) async => <DiscoveredRelay>[],
        );

        final result = await service.discoverRelays(_testNpub);

        expect(result.success, isFalse);
      });

      test('caches result after first success', () async {
        final service = _TestableRelayDiscoveryService(
          indexerRelays: ['wss://indexer'],
          queryHandler: (_) async => [
            const DiscoveredRelay(url: 'wss://cached-relay.com'),
          ],
        );

        // First call - queries indexer
        final result1 = await service.discoverRelays(_testNpub);
        expect(result1.foundOnIndexer, equals('wss://indexer'));

        // Second call - should come from cache
        final result2 = await service.discoverRelays(_testNpub);
        expect(result2.foundOnIndexer, equals('cache'));
        expect(result2.relays.first.url, equals('wss://cached-relay.com'));
      });

      test(
        'returns first non-empty when multiple resolve simultaneously',
        () async {
          // All indexers return immediately with results
          final service = _TestableRelayDiscoveryService(
            indexerRelays: ['wss://a', 'wss://b', 'wss://c'],
            queryHandler: (url) async => [
              DiscoveredRelay(url: 'wss://relay-from-$url'),
            ],
          );

          final result = await service.discoverRelays(_testNpub);

          expect(result.success, isTrue);
          // At least one of them should succeed
          expect(result.relays, hasLength(1));
        },
      );
    });
  });

  group('parseRelayListFromJson (#3362 insecure URL filtering)', () {
    late RelayDiscoveryService service;

    setUp(() {
      service = RelayDiscoveryService(indexerRelays: const ['wss://a']);
    });

    Map<String, dynamic> tagsJson(List<List<String>> tags) => {'tags': tags};

    test('keeps wss:// relays', () {
      final relays = service.parseRelayListFromJson(
        tagsJson([
          ['r', 'wss://relay.example.com'],
        ]),
      );
      expect(relays, hasLength(1));
      expect(relays.first.url, equals('wss://relay.example.com'));
    });

    test('keeps ws://localhost relays', () {
      final relays = service.parseRelayListFromJson(
        tagsJson([
          ['r', 'ws://localhost:47777'],
        ]),
      );
      expect(relays, hasLength(1));
    });

    test('drops ws:// non-loopback relays', () {
      final relays = service.parseRelayListFromJson(
        tagsJson([
          ['r', 'ws://attacker.example.com'],
        ]),
      );
      expect(relays, isEmpty);
    });

    test('drops https:// relay tags (NIP-65 advertises WS endpoints only)', () {
      // A published kind:10002 tag like `["r", "https://relay.example.com"]`
      // is not a usable relay endpoint — `RelayManager._normalizeUrl` will
      // reject it downstream. If discovery kept it, `result.hasRelays`
      // would be true and the safe-fallback bootstrap (#2931) would be
      // suppressed, leaving the user with no relays.
      final relays = service.parseRelayListFromJson(
        tagsJson([
          ['r', 'https://relay.example.com'],
          ['r', 'https://relay.divine.video'],
        ]),
      );
      expect(relays, isEmpty);
    });

    test('drops http://localhost relay tags (NIP-65 is WS-only)', () {
      // Even loopback http:// is not a relay — relays speak WebSocket.
      final relays = service.parseRelayListFromJson(
        tagsJson([
          ['r', 'http://localhost:47777'],
          ['r', 'http://attacker.example.com'],
        ]),
      );
      expect(relays, isEmpty);
    });

    test('keeps mixed list filtered to allowed entries only', () {
      final relays = service.parseRelayListFromJson(
        tagsJson([
          ['r', 'wss://good.example.com'],
          ['r', 'ws://attacker.example.com'],
          ['r', 'ws://localhost:8080'],
          ['r', 'https://relay.example.com'],
          ['r', 'http://localhost:47777'],
        ]),
      );
      expect(relays, hasLength(2));
      expect(
        relays.map((r) => r.url),
        containsAll(['wss://good.example.com', 'ws://localhost:8080']),
      );
    });

    test(
      'drops mis-nested wss://http:// tags (#3362 review follow-up)',
      () {
        // `wss://http://attacker` parses with host=`http` and path=`//attacker…`.
        // Without the `path.startsWith('//')` guard in `isRelayUrlAllowed`,
        // the predicate would accept it (scheme=wss) and discovery would
        // surface a relay pointing at host `http`. `RelayManager.
        // _normalizeUrl` would also reject it downstream, but we don't want
        // discovery's `hasRelays` to flip true on a malformed tag — that
        // would suppress the safe-fallback bootstrap (#2931).
        final relays = service.parseRelayListFromJson(
          tagsJson([
            ['r', 'wss://http://attacker.example.com'],
            ['r', 'wss://https://attacker.example.com'],
            ['r', 'wss://wss://relay.example.com'],
          ]),
        );
        expect(relays, isEmpty);
      },
    );
  });

  group(IndexerRelayConfig, () {
    group('safeFallbackRelays (#2931)', () {
      test('is non-empty so DM reachability degrades gracefully', () {
        // Regression guard for #2931: when NIP-65 discovery fails or
        // returns empty, AuthService applies this list so the client is
        // not stuck Divine-only. An empty list would silently break DM
        // delivery for imported accounts without a published kind 10002.
        expect(IndexerRelayConfig.safeFallbackRelays, isNotEmpty);
      });

      test('contains only secure WebSocket URLs', () {
        for (final url in IndexerRelayConfig.safeFallbackRelays) {
          expect(
            url,
            startsWith('wss://'),
            reason: 'fallback relay $url must use wss:// for secure transport',
          );
        }
      });

      test('contains only unique entries', () {
        const urls = IndexerRelayConfig.safeFallbackRelays;
        expect(urls.toSet().length, equals(urls.length));
      });
    });
  });
}
