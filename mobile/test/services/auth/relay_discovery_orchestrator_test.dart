// ABOUTME: Tests for RelayDiscoveryOrchestrator — NIP-65 discovery write-backs,
// ABOUTME: stale-session guard, fallback relays, and bootstrap kind:10002.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart'
    show SecureKeyContainer;
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/auth/nostr_identity.dart';
import 'package:openvine/services/auth/relay_discovery_orchestrator.dart';
import 'package:openvine/services/relay_discovery_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockRelayDiscoveryService extends Mock
    implements RelayDiscoveryService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testPrivateKey =
      '6b911fd37cdf5c81d4c0adb1ab7fa822ed253ab0ad9aa18d77257c88b29b718e';
  const testPubkey =
      '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd';
  const testNpub = 'npub1testonly';
  const primaryRelayUrl = 'wss://relay.test.divine.video';

  group(RelayDiscoveryOrchestrator, () {
    late _MockRelayDiscoveryService discoveryService;
    late List<List<DiscoveredRelay>> userRelaysWrites;
    late List<bool> hasProfileWrites;
    late List<(String, List<String>)> externalRelayCalls;
    late NostrIdentity? identity;
    late bool sessionCurrent;
    late BootstrapRelayListCallback? bootstrapCallback;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      discoveryService = _MockRelayDiscoveryService();
      userRelaysWrites = [];
      hasProfileWrites = [];
      externalRelayCalls = [];
      identity = null;
      sessionCurrent = true;
      bootstrapCallback = null;
    });

    RelayDiscoveryOrchestrator buildOrchestrator() =>
        RelayDiscoveryOrchestrator(
          relayDiscoveryService: discoveryService,
          primaryRelayUrl: primaryRelayUrl,
          isSessionCurrent: (_) => sessionCurrent,
          currentIdentity: () => identity,
          onUserRelays: userRelaysWrites.add,
          onHasExistingProfile: hasProfileWrites.add,
          userRelaysDiscoveredCallback: () =>
              (pubkey, urls) => externalRelayCalls.add((pubkey, urls)),
          bootstrapRelayListCallback: () => bootstrapCallback,
        );

    group('discoverUserRelays', () {
      test('reports discovered relays and notifies the external callback '
          'with the target pubkey', () async {
        const relays = [
          DiscoveredRelay(url: 'wss://a.example'),
          DiscoveredRelay(url: 'wss://b.example', write: false),
        ];
        when(
          () => discoveryService.discoverRelays(testNpub),
        ).thenAnswer((_) async => RelayDiscoveryResult.success(relays, 'idx'));

        await buildOrchestrator().discoverUserRelays(testNpub, testPubkey);

        expect(userRelaysWrites, equals([relays]));
        expect(externalRelayCalls, hasLength(1));
        expect(externalRelayCalls.single.$1, equals(testPubkey));
        expect(
          externalRelayCalls.single.$2,
          equals(['wss://a.example', 'wss://b.example']),
        );
      });

      test('ignores results for a stale session', () async {
        sessionCurrent = false;
        when(() => discoveryService.discoverRelays(testNpub)).thenAnswer(
          (_) async => RelayDiscoveryResult.success(const [
            DiscoveredRelay(url: 'wss://a.example'),
          ], 'idx'),
        );

        await buildOrchestrator().discoverUserRelays(testNpub, testPubkey);

        expect(userRelaysWrites, isEmpty);
        expect(externalRelayCalls, isEmpty);
      });

      test('empty discovery clears relays and connects the safe fallback '
          'set without reporting it as user relays', () async {
        when(
          () => discoveryService.discoverRelays(testNpub),
        ).thenAnswer((_) async => RelayDiscoveryResult.success(const [], null));

        await buildOrchestrator().discoverUserRelays(testNpub, testPubkey);

        expect(userRelaysWrites, equals([<DiscoveredRelay>[]]));
        expect(externalRelayCalls, hasLength(1));
        expect(
          externalRelayCalls.single.$2,
          equals(IndexerRelayConfig.safeFallbackRelays),
        );
      });

      test('discovery failure clears relays and connects the safe fallback '
          'set', () async {
        when(
          () => discoveryService.discoverRelays(testNpub),
        ).thenThrow(Exception('indexers unreachable'));

        await buildOrchestrator().discoverUserRelays(testNpub, testPubkey);

        expect(userRelaysWrites, equals([<DiscoveredRelay>[]]));
        expect(
          externalRelayCalls.single.$2,
          equals(IndexerRelayConfig.safeFallbackRelays),
        );
      });

      test('discovery failure for a stale session writes nothing', () async {
        sessionCurrent = false;
        when(
          () => discoveryService.discoverRelays(testNpub),
        ).thenThrow(Exception('indexers unreachable'));

        await buildOrchestrator().discoverUserRelays(testNpub, testPubkey);

        expect(userRelaysWrites, isEmpty);
        expect(externalRelayCalls, isEmpty);
      });
    });

    group('publishBootstrapRelayList', () {
      LocalNostrIdentity localIdentity() => LocalNostrIdentity(
        keyContainer: SecureKeyContainer.fromPrivateKeyHex(testPrivateKey),
      );

      test('no-ops without a current identity', () async {
        var called = false;
        bootstrapCallback = (event, relays) async {
          called = true;
          return true;
        };

        await buildOrchestrator().publishBootstrapRelayList();

        expect(called, isFalse);
      });

      test('no-ops without a registered callback', () async {
        identity = localIdentity();

        await buildOrchestrator().publishBootstrapRelayList();

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getBool('bootstrap_kind10002_published_$testPubkey'),
          isNull,
        );
      });

      test('signs and publishes a kind:10002 pointing at the primary relay, '
          'then sets the one-shot flag', () async {
        identity = localIdentity();
        Event? publishedEvent;
        List<String>? publishedTargets;
        bootstrapCallback = (event, relays) async {
          publishedEvent = event;
          publishedTargets = relays;
          return true;
        };

        await buildOrchestrator().publishBootstrapRelayList();

        expect(publishedEvent, isNotNull);
        expect(publishedEvent!.kind, equals(EventKind.relayListMetadata));
        expect(publishedEvent!.pubkey, equals(testPubkey));
        expect(publishedEvent!.sig, isNotEmpty);
        expect(
          publishedEvent!.tags,
          equals([
            ['r', primaryRelayUrl],
          ]),
        );
        expect(
          publishedTargets,
          equals([primaryRelayUrl, ...IndexerRelayConfig.defaultIndexers]),
        );
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getBool('bootstrap_kind10002_published_$testPubkey'),
          isTrue,
        );
      });

      test('leaves the flag unset when no relay accepts the event so the '
          'next login retries', () async {
        identity = localIdentity();
        bootstrapCallback = (event, relays) async => false;

        await buildOrchestrator().publishBootstrapRelayList();

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getBool('bootstrap_kind10002_published_$testPubkey'),
          isNull,
        );
      });

      test('skips publishing when the one-shot flag is already set', () async {
        SharedPreferences.setMockInitialValues({
          'bootstrap_kind10002_published_$testPubkey': true,
        });
        identity = localIdentity();
        var called = false;
        bootstrapCallback = (event, relays) async {
          called = true;
          return true;
        };

        await buildOrchestrator().publishBootstrapRelayList();

        expect(called, isFalse);
      });
    });

    group('checkExistingProfile', () {
      test(
        'reports false without network when no pubkey is available',
        () async {
          await buildOrchestrator().checkExistingProfile(null);

          expect(hasProfileWrites, equals([false]));
        },
      );
    });

    group('connectToFallbackRelays', () {
      test('pushes the safe fallback set through the external callback', () {
        buildOrchestrator().connectToFallbackRelays(testPubkey);

        expect(externalRelayCalls, hasLength(1));
        expect(externalRelayCalls.single.$1, equals(testPubkey));
        expect(
          externalRelayCalls.single.$2,
          equals(IndexerRelayConfig.safeFallbackRelays),
        );
      });
    });
  });
}
