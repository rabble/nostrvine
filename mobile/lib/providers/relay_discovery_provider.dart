// ABOUTME: Provider for RelayDiscoveryService
// ABOUTME: Manages relay discovery lifecycle and provides access to the service

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/services/relay_discovery_service.dart';
import 'package:riverpod/src/providers/future_provider.dart';

/// Provider for RelayDiscoveryService
final relayDiscoveryServiceProvider = Provider<RelayDiscoveryService>((ref) {
  return RelayDiscoveryService();
});

/// Provider for relay discovery result for a specific npub
final FutureProviderFamily<RelayDiscoveryResult, String>
userRelayDiscoveryProvider =
    FutureProvider.family<RelayDiscoveryResult, String>((ref, npub) async {
      final service = ref.watch(relayDiscoveryServiceProvider);
      return service.discoverRelays(npub);
    });
