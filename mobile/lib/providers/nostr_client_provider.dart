import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Lifecycle phase for the app's Nostr publishing session.
///
/// [AuthState.authenticated] only means the user's identity is known. Consumers
/// that need to sign or publish Nostr events must wait for [nostrReady].
enum NostrSessionPhase { signedOut, identityKnown, nostrReady, tearingDown }

/// Readiness snapshot for signer-dependent Nostr side effects.
///
/// Use [isReadyForActiveClient] to confirm the phase, pubkey, and client all
/// describe the same signer-backed session before publishing.
class NostrSessionReadiness {
  const NostrSessionReadiness._({
    required this.phase,
    this.pubkey,
    this.client,
  });

  const NostrSessionReadiness.signedOut()
    : this._(phase: NostrSessionPhase.signedOut);

  const NostrSessionReadiness.identityKnown({required String pubkey})
    : this._(phase: NostrSessionPhase.identityKnown, pubkey: pubkey);

  const NostrSessionReadiness.tearingDown({required String pubkey})
    : this._(phase: NostrSessionPhase.tearingDown, pubkey: pubkey);

  const NostrSessionReadiness.nostrReady({
    required String pubkey,
    required NostrClient client,
  }) : this._(
         phase: NostrSessionPhase.nostrReady,
         pubkey: pubkey,
         client: client,
       );

  final NostrSessionPhase phase;
  final String? pubkey;
  final NostrClient? client;

  bool get isReadyForActiveClient {
    final readyClient = client;
    final readyPubkey = pubkey;
    return phase == NostrSessionPhase.nostrReady &&
        readyClient != null &&
        readyPubkey != null &&
        readyClient.hasKeys &&
        readyClient.publicKey == readyPubkey;
  }
}

/// Stores the current Nostr session readiness contract for the app.
///
/// The initial authenticated state is identity-known only. [NostrService]
/// advances this provider to [NostrSessionPhase.nostrReady] after the active
/// signer-backed [NostrClient] has initialized.
class NostrSession extends Notifier<NostrSessionReadiness> {
  @override
  NostrSessionReadiness build() {
    final identity = ref.watch(authServiceProvider).currentIdentity;
    if (identity == null) {
      return const NostrSessionReadiness.signedOut();
    }
    final previous = stateOrNull;
    if (previous?.pubkey == identity.pubkey) {
      return previous!;
    }
    return NostrSessionReadiness.identityKnown(pubkey: identity.pubkey);
  }

  void update(NostrSessionReadiness readiness) {
    state = readiness;
  }
}

/// App-wide contract for side effects that need Nostr signing or publishing.
///
/// Prefer this over raw auth state for Nostr side effects: auth only identifies
/// the user, while this provider identifies the ready signer/client pair.
final nostrSessionProvider =
    NotifierProvider<NostrSession, NostrSessionReadiness>(NostrSession.new);

final nip89ClientTagEnabledProvider = FutureProvider<bool>((ref) async {
  return Nip89ClientTag.isEnabled();
});

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
  Future<void> _authStateChangeQueue = Future<void>.value();
  int _clientGeneration = 0;

  int _nextClientGeneration() => ++_clientGeneration;

  void _invalidateClientGeneration() {
    _clientGeneration++;
  }

  @override
  NostrClient build() {
    final authService = ref.watch(authServiceProvider);
    final statisticsService = ref.watch(relayStatisticsServiceProvider);
    final environmentConfig = ref.watch(currentEnvironmentProvider);
    final dbClient = ref.watch(appDbClientProvider);
    final factory = ref.watch(nostrClientFactoryProvider);

    final initialPubkey = authService.currentIdentity?.pubkey;

    _authSubscription?.cancel();
    _authSubscription = authService.authStateStream.listen(
      _enqueueAuthStateChanged,
    );

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
    final clientGeneration = _nextClientGeneration();

    // NIP-65 discovered-relays callback — see _userRelaysDiscoveredCallbackFor.
    authService.registerUserRelaysDiscoveredCallback(
      _userRelaysDiscoveredCallbackFor(client, initialPubkey, clientGeneration),
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
        if (_isCurrentClientForPubkey(
          client,
          initialPubkey,
          clientGeneration,
        )) {
          _lastPubkey = initialPubkey;
        }
        _markClientReadyIfCurrent(client, initialPubkey, clientGeneration);
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
        if (_lastPubkey == initialPubkey &&
            ref.read(authServiceProvider).currentIdentity?.pubkey ==
                initialPubkey) {
          _lastPubkey = null;
          _setSessionIdentityState(initialPubkey);
        }
      }
    });

    // Capture client reference for disposal - can't access state inside onDispose
    ref.onDispose(() {
      authService.registerUserRelaysDiscoveredCallback(null);
      authService.registerBootstrapRelayListCallback(null);
      _authSubscription?.cancel();
      _invalidateClientGeneration();
      client.dispose();
    });

    return client;
  }

  void _enqueueAuthStateChanged(AuthState newState) {
    _authStateChangeQueue = _authStateChangeQueue
        .catchError(_logAuthTransitionFailure)
        .then((_) async {
          try {
            await _onAuthStateChanged(newState);
          } catch (e, st) {
            _logAuthTransitionFailure(e, st);
          }
        });
  }

  void _logAuthTransitionFailure(Object error, StackTrace stackTrace) {
    Log.warning(
      '[NostrService] Auth state transition failed: $error',
      name: 'NostrService',
      category: LogCategory.system,
    );
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

    final activeClientPubkey = state.hasKeys ? state.publicKey : null;
    if (newPubkey != _lastPubkey ||
        (newPubkey == null && activeClientPubkey != null)) {
      _invalidateClientGeneration();
      Log.info(
        '[NostrService] Public key changed from $_lastPubkey to $newPubkey, '
        'recreating NostrClient',
        name: 'NostrService',
        category: LogCategory.system,
      );

      final oldPubkey = _lastPubkey;
      if (oldPubkey != null) {
        ref
            .read(nostrSessionProvider.notifier)
            .update(NostrSessionReadiness.tearingDown(pubkey: oldPubkey));
      }

      // Unregister callback for old client before disposing it
      authService.registerUserRelaysDiscoveredCallback(null);
      authService.registerBootstrapRelayListCallback(null);
      state.dispose();
      _invalidateClientGeneration();

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
      final clientGeneration = _nextClientGeneration();

      // NIP-65 discovered-relays callback — see _userRelaysDiscoveredCallbackFor.
      authService.registerUserRelaysDiscoveredCallback(
        _userRelaysDiscoveredCallbackFor(
          newClient,
          newPubkey,
          clientGeneration,
        ),
      );

      // Bootstrap kind:10002 publisher — see _bootstrapCallbackFor.
      authService.registerBootstrapRelayListCallback(
        _bootstrapCallbackFor(newClient),
      );

      state = newClient;
      _setSessionIdentityState(newPubkey);

      // Add user relays first (must complete before initialize)
      if (userRelayUrls.isNotEmpty) {
        await newClient.addRelays(userRelayUrls);
      }
      // Then initialize the new client
      await newClient.initialize();
      _lastPubkey = newPubkey;
      _markClientReadyIfCurrent(newClient, newPubkey, clientGeneration);
    }
  }

  void _setSessionIdentityState(String? pubkey) {
    ref
        .read(nostrSessionProvider.notifier)
        .update(
          pubkey == null
              ? const NostrSessionReadiness.signedOut()
              : NostrSessionReadiness.identityKnown(pubkey: pubkey),
        );
  }

  void _markClientReadyIfCurrent(
    NostrClient client,
    String? pubkey,
    int clientGeneration,
  ) {
    if (pubkey == null) {
      if (_isCurrentClientForPubkey(client, null, clientGeneration)) {
        ref
            .read(nostrSessionProvider.notifier)
            .update(const NostrSessionReadiness.signedOut());
      }
      return;
    }

    if (_isCurrentClientForPubkey(client, pubkey, clientGeneration) &&
        client.hasKeys &&
        client.publicKey == pubkey) {
      ref
          .read(nostrSessionProvider.notifier)
          .update(
            NostrSessionReadiness.nostrReady(pubkey: pubkey, client: client),
          );
    }
  }

  bool _isCurrentClientForPubkey(
    NostrClient client,
    String? pubkey,
    int clientGeneration,
  ) {
    final currentPubkey = ref.read(authServiceProvider).currentIdentity?.pubkey;
    return clientGeneration == _clientGeneration &&
        identical(state, client) &&
        currentPubkey == pubkey;
  }

  /// Builds the NIP-65 discovered-relays callback bound to [client].
  ///
  /// Registered with AuthService so when NIP-65 discovery completes later,
  /// the discovered relays are added to [client] — this fixes the race
  /// where discovery finishes after the client has been built. Used at
  /// both initial-build and account-switch sites so the
  /// add-relays-on-discovery flow stays in one place.
  UserRelaysDiscoveredCallback _userRelaysDiscoveredCallbackFor(
    NostrClient client,
    String? targetPubkey,
    int clientGeneration,
  ) {
    return (pubkey, relayUrls) {
      if (targetPubkey == null || pubkey != targetPubkey || relayUrls.isEmpty) {
        return;
      }
      Future.microtask(() async {
        try {
          if (!_isCurrentClientForPubkey(
            client,
            targetPubkey,
            clientGeneration,
          )) {
            return;
          }
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
      return published is PublishSuccess;
    };
  }
}
