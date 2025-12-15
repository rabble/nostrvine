// ABOUTME: Tests for gateway settings Riverpod provider
// ABOUTME: Validates provider initialization and dependency injection

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/relay_gateway_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/relay_gateway_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('RelayGatewayProviders', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('sharedPreferencesProvider throws error when not overridden', () {
      final container = ProviderContainer();

      // Attempting to read the provider without overriding throws an exception
      expect(() => container.read(sharedPreferencesProvider), throwsException);

      container.dispose();
    });

    test('relayGatewaySettingsProvider provides settings instance', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );

      final settings = container.read(relayGatewaySettingsProvider);

      expect(settings, isA<RelayGatewaySettings>());
      expect(settings.isEnabled, true);

      container.dispose();
    });

    test('settings uses default gateway URL', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );

      final settings = container.read(relayGatewaySettingsProvider);

      expect(settings.gatewayUrl, 'https://gateway.divine.video');

      container.dispose();
    });

    test('settings uses custom URL from preferences', () async {
      SharedPreferences.setMockInitialValues({
        'relay_gateway_url': 'https://custom.gateway',
      });

      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );

      final settings = container.read(relayGatewaySettingsProvider);

      expect(settings.gatewayUrl, 'https://custom.gateway');

      container.dispose();
    });

    test('settings isEnabled reflects stored preference', () async {
      SharedPreferences.setMockInitialValues({'relay_gateway_enabled': false});

      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );

      final settings = container.read(relayGatewaySettingsProvider);

      expect(settings.isEnabled, false);

      container.dispose();
    });
  });
}
