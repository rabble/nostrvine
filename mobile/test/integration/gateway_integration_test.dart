// ABOUTME: Integration test for REST gateway settings + NostrClient configuration
// ABOUTME: Tests settings provider and NostrServiceFactory gateway wiring

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_gateway/nostr_gateway.dart';
import 'package:openvine/providers/relay_gateway_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/relay_gateway_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Gateway Integration', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('settings provider wires correctly with shared preferences', () async {
      SharedPreferences.setMockInitialValues({'relay_gateway_enabled': true});

      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );

      // Verify settings provider works
      final settings = container.read(relayGatewaySettingsProvider);
      expect(settings, isA<RelayGatewaySettings>());
      expect(settings.isEnabled, true);
      expect(settings.gatewayUrl, 'https://gateway.divine.video');

      container.dispose();
    });

    test('settings correctly determine gateway usage', () async {
      // Test with gateway enabled and divine relay
      SharedPreferences.setMockInitialValues({'relay_gateway_enabled': true});
      var prefs = await SharedPreferences.getInstance();
      var settings = RelayGatewaySettings(prefs);

      expect(
        settings.shouldUseGateway(
          configuredRelays: ['wss://relay.divine.video'],
        ),
        true,
      );

      // Test with gateway disabled
      SharedPreferences.setMockInitialValues({'relay_gateway_enabled': false});
      prefs = await SharedPreferences.getInstance();
      settings = RelayGatewaySettings(prefs);

      expect(
        settings.shouldUseGateway(
          configuredRelays: ['wss://relay.divine.video'],
        ),
        false,
      );

      // Test with gateway enabled but no divine relay
      SharedPreferences.setMockInitialValues({'relay_gateway_enabled': true});
      prefs = await SharedPreferences.getInstance();
      settings = RelayGatewaySettings(prefs);

      expect(
        settings.shouldUseGateway(
          configuredRelays: ['wss://nos.lol', 'wss://relay.damus.io'],
        ),
        false,
      );

      // Test with divine relay among multiple relays
      expect(
        settings.shouldUseGateway(
          configuredRelays: [
            'wss://nos.lol',
            'wss://relay.divine.video',
            'wss://relay.damus.io',
          ],
        ),
        true,
      );
    });

    test('custom gateway URL is persisted and used', () async {
      SharedPreferences.setMockInitialValues({
        'relay_gateway_url': 'https://custom.gateway.test',
        'relay_gateway_enabled': true,
      });

      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );

      final settings = container.read(relayGatewaySettingsProvider);
      expect(settings.gatewayUrl, 'https://custom.gateway.test');

      container.dispose();
    });

    test('GatewayClient can be created from settings', () async {
      SharedPreferences.setMockInitialValues({'relay_gateway_enabled': true});

      final prefs = await SharedPreferences.getInstance();
      final settings = RelayGatewaySettings(prefs);

      // This is what NostrServiceFactory does when gateway is enabled
      final gatewayClient = GatewayClient(gatewayUrl: settings.gatewayUrl);

      expect(gatewayClient, isNotNull);
      expect(gatewayClient.gatewayUrl, 'https://gateway.divine.video');
    });

    test('isDivineRelayConfigured static method works correctly', () {
      expect(
        RelayGatewaySettings.isDivineRelayConfigured([
          'wss://relay.divine.video',
        ]),
        true,
      );
      expect(
        RelayGatewaySettings.isDivineRelayConfigured([
          'wss://nos.lol',
          'wss://relay.divine.video',
        ]),
        true,
      );
      expect(
        RelayGatewaySettings.isDivineRelayConfigured(['wss://nos.lol']),
        false,
      );
      expect(RelayGatewaySettings.isDivineRelayConfigured([]), false);
    });
  });
}
