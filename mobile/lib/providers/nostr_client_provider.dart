import 'dart:async';

import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nostr_service_factory.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'nostr_client_provider.g.dart';

/// Core Nostr service via NostrClient for relay communication
/// Uses a Notifier to react to auth state changes and recreate the client
/// when the keyContainer changes (e.g., user signs out and signs in with different keys)
@Riverpod(keepAlive: true)
class NostrService extends _$NostrService {
  StreamSubscription<AuthState>? _authSubscription;
  String? _lastPubkey;

  @override
  NostrClient build() {
    final authService = ref.watch(authServiceProvider);
    final statisticsService = ref.watch(relayStatisticsServiceProvider);
    final environmentConfig = ref.watch(currentEnvironmentProvider);
    final dbClient = ref.watch(appDbClientProvider);

    _lastPubkey = authService.currentPublicKeyHex;

    _authSubscription?.cancel();
    _authSubscription = authService.authStateStream.listen(_onAuthStateChanged);

    // Get user relay URLs from discovered relays (NIP-65)
    // Include all relays - NostrClient needs both read and write capable relays
    // for subscribing to events and publishing events respectively
    final userRelayUrls = authService.userRelays
        .map((relay) => relay.url)
        .toList();

    // Create initial NostrClient (prefer RPC signer when available)
    final client = NostrServiceFactory.create(
      keyContainer: authService.currentKeyContainer,
      statisticsService: statisticsService,
      environmentConfig: environmentConfig,
      dbClient: dbClient,
      rpcSigner: authService.rpcSigner,
    );

    // Register callback so when NIP-65 discovery completes later, we add those
    // relays to this client (fixes race where discovery finishes after client build)
    authService.registerUserRelaysDiscoveredCallback((relayUrls) {
      if (relayUrls.isEmpty) return;
      Future.microtask(() async {
        try {
          final added = await client.addRelays(relayUrls);
          if (added > 0) {
            Log.info(
              '[NostrService] Added $added discovered relay(s) after NIP-65 discovery',
              name: 'NostrService',
              category: LogCategory.system,
            );
          }
        } catch (e) {
          Log.warning(
            '[NostrService] Failed to add discovered relays: $e',
            name: 'NostrService',
            category: LogCategory.system,
          );
        }
      });
    });

    // Schedule initialization after build completes
    // Add user relays BEFORE initialize() to avoid race condition
    Future.microtask(() async {
      try {
        // Add user relays first (must complete before initialize)
        if (userRelayUrls.isNotEmpty) {
          await client.addRelays(userRelayUrls);
        }
        // Then initialize the client
        await client.initialize();
        Log.info(
          '[NostrService] Client initialized via build()',
          name: 'NostrService',
          category: LogCategory.system,
        );
      } catch (e) {
        Log.error(
          '[NostrService] Failed to initialize client in build(): $e',
          name: 'NostrService',
          category: LogCategory.system,
        );
      }
    });

    // Capture client reference for disposal - can't access state inside onDispose
    ref.onDispose(() {
      ref.read(authServiceProvider).registerUserRelaysDiscoveredCallback(null);
      _authSubscription?.cancel();
      client.dispose();
    });

    return client;
  }

  Future<void> _onAuthStateChanged(AuthState newState) async {
    final authService = ref.read(authServiceProvider);
    final currentPubkey = authService.currentPublicKeyHex;

    if (currentPubkey != _lastPubkey) {
      Log.info(
        '[NostrService] Public key changed from $_lastPubkey to $currentPubkey, '
        'recreating NostrClient',
        name: 'NostrService',
        category: LogCategory.system,
      );

      // Unregister callback for old client before disposing it
      authService.registerUserRelaysDiscoveredCallback(null);
      state.dispose();

      // Create new client with updated signer and public key
      final statisticsService = ref.read(relayStatisticsServiceProvider);
      final environmentConfig = ref.read(currentEnvironmentProvider);
      final dbClient = ref.read(appDbClientProvider);

      // Get user relay URLs from discovered relays (NIP-65)
      // Include all relays - NostrClient needs both read and write capable relays
      // for subscribing to events and publishing events respectively
      final userRelayUrls = authService.userRelays
          .map((relay) => relay.url)
          .toList();

      final newClient = NostrServiceFactory.create(
        keyContainer: authService.currentKeyContainer,
        statisticsService: statisticsService,
        environmentConfig: environmentConfig,
        dbClient: dbClient,
        rpcSigner: authService.rpcSigner,
      );

      // Register callback for new client so later discovery adds relays to it
      authService.registerUserRelaysDiscoveredCallback((relayUrls) {
        if (relayUrls.isEmpty) return;
        Future.microtask(() async {
          try {
            final added = await newClient.addRelays(relayUrls);
            if (added > 0) {
              Log.info(
                '[NostrService] Added $added discovered relay(s) after NIP-65 discovery',
                name: 'NostrService',
                category: LogCategory.system,
              );
            }
          } catch (e) {
            Log.warning(
              '[NostrService] Failed to add discovered relays: $e',
              name: 'NostrService',
              category: LogCategory.system,
            );
          }
        });
      });

      _lastPubkey = currentPubkey;

      // Add user relays first (must complete before initialize)
      if (userRelayUrls.isNotEmpty) {
        await newClient.addRelays(userRelayUrls);
      }
      // Then initialize the new client
      await newClient.initialize();
      state = newClient;
    }
  }
}
