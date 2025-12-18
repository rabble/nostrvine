// ABOUTME: Riverpod providers for REST gateway settings
// ABOUTME: Provides dependency injection for gateway configuration

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/relay_gateway_settings.dart';

/// Provider for gateway settings
///
/// Gateway communication is handled by NostrClient internally via GatewayClient.
/// This provider only manages user preferences (enabled/disabled, custom URL).
final relayGatewaySettingsProvider = Provider<RelayGatewaySettings>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return RelayGatewaySettings(prefs);
});
