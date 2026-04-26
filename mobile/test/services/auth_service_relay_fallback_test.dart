// ABOUTME: Tests that AuthService applies the safe fallback relay set
// ABOUTME: when NIP-65 relay discovery returns empty or fails, so DM
// ABOUTME: reachability degrades gracefully for imported accounts. #2931.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/relay_discovery_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_setup.dart';

class _MockUserDataCleanupService extends Mock
    implements UserDataCleanupService {}

/// Test double for [RelayDiscoveryService] that lets each test scenario
/// control the discovery outcome (success / empty / throw) without hitting
/// real WebSockets.
class _ControllableRelayDiscoveryService extends RelayDiscoveryService {
  _ControllableRelayDiscoveryService({required this.outcome})
    : super(indexerRelays: const ['wss://test.invalid']);

  final RelayDiscoveryResult Function() outcome;

  @override
  Future<RelayDiscoveryResult> discoverRelays(String npub) async {
    return outcome();
  }
}

void main() {
  setupTestEnvironment();

  // 64-character hex npub for tests; the value isn't validated by
  // the test double, only passed through.
  const testNpub =
      'npub1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqsutm2dy';

  group('AuthService relay fallback (#2931)', () {
    late _MockUserDataCleanupService mockCleanupService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockCleanupService = _MockUserDataCleanupService();
    });

    AuthService buildAuthService(_ControllableRelayDiscoveryService discovery) {
      return AuthService(
        userDataCleanupService: mockCleanupService,
        relayDiscoveryService: discovery,
      );
    }

    test(
      'connects to safeFallbackRelays when discovery returns empty',
      () async {
        // ARRANGE: discovery returns success but with no relays — the
        // imported-account-without-NIP-65-list scenario from the bug report.
        final discovery = _ControllableRelayDiscoveryService(
          outcome: () => RelayDiscoveryResult.failure('No relay list found'),
        );
        final authService = buildAuthService(discovery);

        // Capture the URLs the AuthService asks NostrService to add.
        List<String>? capturedRelayUrls;
        authService.registerUserRelaysDiscoveredCallback(
          (urls) => capturedRelayUrls = urls,
        );

        // ACT: drive the discovery routine directly via the test seam.
        await authService.debugDiscoverUserRelays(testNpub);

        // ASSERT: the callback received the curated fallback relay set.
        // This is the wire that connects "discovery failed" to "client
        // connects to broader relay set", which is the actual user-facing
        // fix for #2931.
        expect(
          capturedRelayUrls,
          equals(IndexerRelayConfig.safeFallbackRelays),
        );

        // ASSERT: userRelays getter does NOT include the fallback set.
        // The bridge to embedded Nostr apps reads userRelays via NIP-07's
        // getRelays(); polluting it with fallback relays would lie to apps
        // about the user's published relay list.
        expect(authService.userRelays, isEmpty);
      },
    );

    test('connects to safeFallbackRelays when discovery throws', () async {
      // ARRANGE: indexer connection failure — relay discovery throws
      // before any indexer responds.
      final discovery = _ControllableRelayDiscoveryService(
        outcome: () => throw Exception('connection refused'),
      );
      final authService = buildAuthService(discovery);

      List<String>? capturedRelayUrls;
      authService.registerUserRelaysDiscoveredCallback(
        (urls) => capturedRelayUrls = urls,
      );

      // ACT
      await authService.debugDiscoverUserRelays(testNpub);

      // ASSERT
      expect(capturedRelayUrls, equals(IndexerRelayConfig.safeFallbackRelays));
      expect(authService.userRelays, isEmpty);
    });

    test(
      'does NOT apply fallback when discovery returns the user relays',
      () async {
        // ARRANGE: happy path — discovery finds the user's published
        // relay list.
        final userRelays = [
          const DiscoveredRelay(url: 'wss://relay.example.com'),
          const DiscoveredRelay(url: 'wss://relay.user-chosen.org'),
        ];
        final discovery = _ControllableRelayDiscoveryService(
          outcome: () =>
              RelayDiscoveryResult.success(userRelays, 'wss://test-indexer'),
        );
        final authService = buildAuthService(discovery);

        List<String>? capturedRelayUrls;
        authService.registerUserRelaysDiscoveredCallback(
          (urls) => capturedRelayUrls = urls,
        );

        // ACT
        await authService.debugDiscoverUserRelays(testNpub);

        // ASSERT: callback receives the user's actual relays, not the
        // fallback set.
        expect(
          capturedRelayUrls,
          equals(['wss://relay.example.com', 'wss://relay.user-chosen.org']),
        );
        expect(
          capturedRelayUrls,
          isNot(equals(IndexerRelayConfig.safeFallbackRelays)),
        );

        // userRelays getter reflects the discovered list (this is the
        // semantic source of truth for the embedded-app bridge).
        expect(
          authService.userRelays.map((r) => r.url).toList(),
          equals(['wss://relay.example.com', 'wss://relay.user-chosen.org']),
        );
      },
    );
  });
}
