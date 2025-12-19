import 'dart:async';

import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/relay_gateway_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nostr_service_factory.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:nostr_client/nostr_client.dart';

part 'nostr_client_provider.g.dart';

/// Core Nostr service via NostrClient for relay communication
/// Uses a Notifier to react to auth state changes and recreate the client
/// when the keyContainer changes (e.g., user signs out and signs in with different keys)
@Riverpod(keepAlive: true)
class NostrService extends _$NostrService {
  StreamSubscription<AuthState>? _authSubscription;
  String? _lastKeyContainerPubkey;

  @override
  NostrClient build() {
    final authService = ref.watch(authServiceProvider);
    final statisticsService = ref.watch(relayStatisticsServiceProvider);
    final gatewaySettings = ref.watch(relayGatewaySettingsProvider);

    _lastKeyContainerPubkey = authService.currentKeyContainer?.publicKeyHex;

    _authSubscription?.cancel();
    _authSubscription = authService.authStateStream.listen(_onAuthStateChanged);

    ref.onDispose(() {
      _authSubscription?.cancel();

      state.dispose();
    });

    // Create initial NostrClient
    return NostrServiceFactory.create(
      keyContainer: authService.currentKeyContainer,
      statisticsService: statisticsService,
      gatewaySettings: gatewaySettings,
    );
  }

  Future<void> _onAuthStateChanged(AuthState newState) async {
    final authService = ref.read(authServiceProvider);
    final currentPubkey = authService.currentKeyContainer?.publicKeyHex;

    if (currentPubkey != _lastKeyContainerPubkey) {
      Log.info(
        '[NostrService] KeyContainer changed from $_lastKeyContainerPubkey to $currentPubkey, recreating NostrClient',
        name: 'NostrService',
        category: LogCategory.system,
      );

      state.dispose();

      // Create new client with updated keyContainer
      final statisticsService = ref.read(relayStatisticsServiceProvider);
      final gatewaySettings = ref.read(relayGatewaySettingsProvider);

      final newClient = NostrServiceFactory.create(
        keyContainer: authService.currentKeyContainer,
        statisticsService: statisticsService,
        gatewaySettings: gatewaySettings,
      );

      _lastKeyContainerPubkey = currentPubkey;

      // Initialize the new client
      await newClient.initialize();
      state = newClient;
    }
  }
}
