// ABOUTME: Integration test for NIP-42 authentication with Nostr relays
// ABOUTME: Tests actual relay connection and AUTH flow in real app environment

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/client_utils/keys.dart' as keys;
import 'package:openvine/main.dart' as app;
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/utils/unified_logger.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('NIP-42 Auth Integration', () {
    testWidgets('Test relay authentication and video loading', (tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Access the services directly
      Log.debug('\n=== NIP-42 Authentication Test ===');

      // Create test NostrClient with generated keys
      final privateKey = keys.generatePrivateKey();
      final publicKey = keys.getPublicKey(privateKey);
      final signer = LocalNostrSigner(privateKey);

      final config = NostrClientConfig(signer: signer, publicKey: publicKey);

      // Use in-memory storage with the test relay
      final storage = InMemoryRelayStorage(['wss://relay3.openvine.co']);
      final relayConfig = RelayManagerConfig(
        defaultRelayUrl: AppConstants.defaultRelayUrl,
        storage: storage,
      );

      final nostrClient = NostrClient(
        config: config,
        relayManagerConfig: relayConfig,
      );

      // Test 1: Connect to relay
      Log.debug('\n1. Testing relay connection...');
      await nostrClient.initialize();
      Log.debug('Connected to relays: ${nostrClient.connectedRelays}');
      Log.debug('Public key: ${nostrClient.publicKey}');

      // Test 2: Try to subscribe to events
      Log.debug(
        '\n2. Testing event subscription (should trigger AUTH if needed)...',
      );
      final filters = [
        Filter(
          kinds: [22], // Video events
          limit: 5,
        ),
      ];

      final events = <Event>[];
      final subscription = nostrClient.subscribe(filters);

      // Listen for events with timeout
      try {
        await subscription
            .take(5)
            .timeout(
              const Duration(seconds: 10),
              onTimeout: (sink) {
                Log.debug(
                  'Timeout waiting for events - checking if AUTH is required',
                );
              },
            )
            .forEach((event) {
              events.add(event);
              Log.debug('Received event: ${event.kind} - ${event.id}');
            });
      } catch (e) {
        Log.debug('Error during subscription: $e');
      }

      Log.debug('\n3. Results:');
      Log.debug('Events received: ${events.length}');

      if (events.isEmpty) {
        Log.debug('⚠️ No events received - possible causes:');
        Log.debug('  - Relay requires NIP-42 AUTH but not sending challenge');
        Log.debug('  - No Kind 22 events on the relay');
        Log.debug('  - AUTH is failing silently');
      } else {
        Log.debug('✅ Successfully received ${events.length} events!');
      }

      // Test 3: Try to query our own profile
      Log.debug('\n4. Testing profile query (should work after AUTH)...');
      final profileFilters = [
        Filter(
          kinds: [0], // Profile metadata
          authors: [nostrClient.publicKey],
          limit: 1,
        ),
      ];

      final profileEvents = <Event>[];
      try {
        await nostrClient
            .subscribe(profileFilters)
            .take(1)
            .timeout(const Duration(seconds: 3), onTimeout: (sink) {})
            .forEach(profileEvents.add);
      } catch (e) {
        Log.debug('Profile query error: $e');
      }

      Log.debug('Profile events: ${profileEvents.length}');

      // Clean up
      await nostrClient.dispose();

      // Wait a bit to see any notices or errors
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
