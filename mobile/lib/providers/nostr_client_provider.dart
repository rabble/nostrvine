import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nostr_service_factory.dart';
import 'package:openvine/services/relay_statistics_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:unified_logger/unified_logger.dart';

part 'nostr_client_provider.g.dart';

/// Signature for constructing a [NostrClient]. The default implementation
/// delegates to [NostrServiceFactory.create]. Tests override
/// [nostrClientFactoryProvider] to inject fake clients and observe the
/// arguments NostrService passes.
typedef NostrClientFactory =
    NostrClient Function({
      NostrSigner? signer,
      RelayStatisticsService? statisticsService,
      EnvironmentConfig? environmentConfig,
      AppDbClient? dbClient,
    });

/// Indirection layer over [NostrServiceFactory.create] so tests can
/// substitute a fake factory without touching the real relay/network
/// code path. Production builds use this provider transparently.
@Riverpod(keepAlive: true)
NostrClientFactory nostrClientFactory(Ref ref) => NostrServiceFactory.create;

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
    final factory = ref.watch(nostrClientFactoryProvider);

    _lastPubkey = authService.currentIdentity?.pubkey;

    _authSubscription?.cancel();
    _authSubscription = authService.authStateStream.listen(_onAuthStateChanged);

    // Get user relay URLs from discovered relays (NIP-65)
    // Include all relays - NostrClient needs both read and write capable relays
    // for subscribing to events and publishing events respectively
    final userRelayUrls = authService.userRelays
        .map((relay) => relay.url)
        .toList();

    // Create initial NostrClient using the atomic identity as signer.
    // currentIdentity is nullable — before auth completes, the factory falls
    // back to a no-op LocalKeySigner. _onAuthStateChanged recreates the client
    // once the user authenticates.
    final client = factory(
      signer: authService.currentIdentity,
      statisticsService: statisticsService,
      environmentConfig: environmentConfig,
      dbClient: dbClient,
    );

    // NIP-65 discovered-relays callback — see _userRelaysDiscoveredCallbackFor.
    authService.registerUserRelaysDiscoveredCallback(
      _userRelaysDiscoveredCallbackFor(client),
    );

    // Bootstrap kind:10002 publisher — see _bootstrapCallbackFor.
    authService.registerBootstrapRelayListCallback(
      _bootstrapCallbackFor(client),
    );

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
      authService.registerUserRelaysDiscoveredCallback(null);
      authService.registerBootstrapRelayListCallback(null);
      _authSubscription?.cancel();
      client.dispose();
    });

    return client;
  }

  Future<void> _onAuthStateChanged(AuthState newState) async {
    final authService = ref.read(authServiceProvider);
    // Read the atomic NostrIdentity as the sole source of truth for both
    // the recreation trigger and the signer we pass into the new client.
    // The currentPublicKeyHex / currentNpub getters on AuthService use a
    // fallback chain (identity → keyContainer → profile) intended for UI
    // consumers that just need a display pubkey during the auth-screen
    // lifecycle. Reading from those getters here can report a non-null
    // pubkey during a window where _currentIdentity is still null, which
    // would install a LocalKeySigner(null) placeholder whose
    // getPublicKey() returns '' and whose hasKeys is therefore permanently
    // false — trapping every downstream consumer. PR #2833 established
    // NostrIdentity as the atomic pubkey+signer contract; honour it here
    // so the signer and the trigger cannot disagree.
    final newIdentity = authService.currentIdentity;
    final newPubkey = newIdentity?.pubkey;

    if (newPubkey != _lastPubkey) {
      Log.info(
        '[NostrService] Public key changed from $_lastPubkey to $newPubkey, '
        'recreating NostrClient',
        name: 'NostrService',
        category: LogCategory.system,
      );

      // Unregister callback for old client before disposing it
      authService.registerUserRelaysDiscoveredCallback(null);
      authService.registerBootstrapRelayListCallback(null);
      state.dispose();

      // Create new client with updated signer and public key
      final statisticsService = ref.read(relayStatisticsServiceProvider);
      final environmentConfig = ref.read(currentEnvironmentProvider);
      final dbClient = ref.read(appDbClientProvider);
      final factory = ref.read(nostrClientFactoryProvider);

      // Get user relay URLs from discovered relays (NIP-65)
      // Include all relays - NostrClient needs both read and write capable relays
      // for subscribing to events and publishing events respectively
      final userRelayUrls = authService.userRelays
          .map((relay) => relay.url)
          .toList();

      final newClient = factory(
        signer: newIdentity,
        statisticsService: statisticsService,
        environmentConfig: environmentConfig,
        dbClient: dbClient,
      );

      // NIP-65 discovered-relays callback — see _userRelaysDiscoveredCallbackFor.
      authService.registerUserRelaysDiscoveredCallback(
        _userRelaysDiscoveredCallbackFor(newClient),
      );

      // Bootstrap kind:10002 publisher — see _bootstrapCallbackFor.
      authService.registerBootstrapRelayListCallback(
        _bootstrapCallbackFor(newClient),
      );

      _lastPubkey = newPubkey;

      // Add user relays first (must complete before initialize)
      if (userRelayUrls.isNotEmpty) {
        await newClient.addRelays(userRelayUrls);
      }
      // Then initialize the new client
      await newClient.initialize();
      state = newClient;
    }
  }

  /// Builds the NIP-65 discovered-relays callback bound to [client].
  ///
  /// Registered with AuthService so when NIP-65 discovery completes later,
  /// the discovered relays are added to [client] — this fixes the race
  /// where discovery finishes after the client has been built. Used at
  /// both initial-build and account-switch sites so the
  /// add-relays-on-discovery flow stays in one place.
  static UserRelaysDiscoveredCallback _userRelaysDiscoveredCallbackFor(
    NostrClient client,
  ) {
    return (relayUrls) {
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
    };
  }

  /// Builds the bootstrap kind:10002 publisher closure bound to [client].
  ///
  /// AuthService invokes this when indexer NIP-65 discovery returns empty,
  /// so we self-publish a minimal relay list on the user's behalf. Used at
  /// both initial-build and account-switch sites so the publish path stays
  /// in one place. See divine-mobile#3174 / keycast#94.
  static BootstrapRelayListCallback _bootstrapCallbackFor(NostrClient client) {
    return (event, targetRelays) async {
      final published = await client.publishEvent(
        event,
        targetRelays: targetRelays,
      );
      return published != null;
    };
  }
}
