// ABOUTME: Riverpod wiring for creator sync repositories.
// ABOUTME: Reports session-not-ready, vault-locked, and available distinctly.

import 'dart:async';

import 'package:creator_sync/creator_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/provider_identity_stream.dart';
import 'package:openvine/providers/saved_sounds_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/creator_sync/prefs_sync_state_store.dart';
import 'package:openvine/services/creator_sync/saved_sounds_local_store.dart';
import 'package:openvine/services/creator_sync/secure_vault_key_cache.dart';

/// Outcome of resolving the sound sync repository for the active session.
///
/// Distinguishes "not ready yet" (signed out, or the signer-backed client
/// has not finished advancing to `NostrSessionPhase.nostrReady`) from
/// "couldn't unlock" (`VaultKeyUnavailableException` — a NIP-46 bunker
/// refusal, a relay outage at key-fetch time, a malformed remote key
/// event). The first case means sync is simply off; the second is the
/// spec-mandated locked state, and `SoundsTab` renders a banner for it.
sealed class SoundSyncAvailability {
  const SoundSyncAvailability();
}

/// The session is not ready to sync yet. Sync stays off; nothing to show.
class SoundSyncSessionNotReady extends SoundSyncAvailability {
  const SoundSyncSessionNotReady();
}

/// The session is ready, but the vault key could not be unlocked.
class SoundSyncVaultLocked extends SoundSyncAvailability {
  const SoundSyncVaultLocked();
}

/// The repository is ready to sync.
class SoundSyncAvailable extends SoundSyncAvailability {
  const SoundSyncAvailable(this.repository);

  final SoundSyncRepository repository;
}

/// Resolves [SoundSyncAvailability] for the active session.
///
/// Follows the nullable-gate pattern already used by
/// `profileRepository` (`repository_providers.dart`): the repository only
/// exists once [nostrSessionProvider] reports a signer-backed client ready
/// for the active identity and the vault key resolves. The gate alone does
/// not make this identity-stable, though — consumers still need to react
/// to it changing, or to a different instance on an auth change. A
/// leaf-scoped consumer keys a `BlocProvider` on the resolved repository
/// (`SoundsTab`, matching `NotificationsPage`'s pattern). `SavedSoundsScope`
/// sits above `MaterialApp.router`, where re-keying re-inflates the whole
/// app shell (#6477/#6480), so it subscribes to
/// [soundSyncRepositoryStreamProvider] instead and re-points the dependency
/// in place.
final soundSyncAvailabilityProvider = FutureProvider<SoundSyncAvailability>((
  ref,
) async {
  final readiness = ref.watch(nostrSessionProvider);
  if (!readiness.isReadyForActiveClient) {
    return const SoundSyncSessionNotReady();
  }

  final client = readiness.client!;
  final pubkeyHex = readiness.pubkey!;
  // Hoisted above the await below: every ref.watch must run before the
  // first suspension point. obtain() is a relay round trip that can take
  // seconds, and a sign-out/account-switch/session-re-advance in that
  // window disposes this provider's element — a ref.watch reached after
  // that throws UnmountedRefException. Reading these here also registers
  // the dependency on the VaultKeyUnavailableException early-return path
  // below, so this provider still rebuilds when they change even when it
  // resolves to locked.
  final secureStorage = ref.watch(flutterSecureStorageProvider);
  final sharedPreferences = ref.watch(sharedPreferencesProvider);
  final savedSoundsService = ref.watch(savedSoundsServiceProvider);

  final vaultKeyService = VaultKeyService(
    signer: client.signer,
    client: client,
    cache: SecureVaultKeyCache(secureStorage),
  );

  final SyncCipher cipher;
  try {
    cipher = SyncCipher(await vaultKeyService.obtain());
  } on VaultKeyUnavailableException {
    // Expected offline and during cold start. Surfaced as the locked
    // state rather than a spurious failure.
    return const SoundSyncVaultLocked();
  }

  return SoundSyncAvailable(
    SoundSyncRepository(
      index: SyncIndexClient(
        client: client,
        signer: client.signer,
        cipher: cipher,
      ),
      state: PrefsSyncStateStore(sharedPreferences, pubkeyHex: pubkeyHex),
      local: SavedSoundsLocalStore(savedSoundsService),
      errorReporter: (error, stackTrace, {required site}) {
        unawaited(
          CrashReportingService.instance.recordError(
            error,
            stackTrace,
            reason: 'SoundSyncRepository.$site',
          ),
        );
      },
    ),
  );
});

/// [soundSyncAvailabilityProvider] flattened to the repository, or null
/// while loading, on error, not-ready, or locked.
///
/// Exists so [soundSyncRepositoryStreamProvider] can wrap a plain
/// `ProviderListenable`, which `identityStreamOf` requires, rather than a
/// `FutureProvider`'s `AsyncValue`. Consumers that only need the repository
/// itself — not the not-ready/locked distinction — use this or the stream
/// below rather than [soundSyncAvailabilityProvider] directly.
final soundSyncRepositoryValueProvider = Provider<SoundSyncRepository?>((
  ref,
) {
  final availability = ref.watch(soundSyncAvailabilityProvider).value;
  return switch (availability) {
    SoundSyncAvailable(:final repository) => repository,
    _ => null,
  };
});

/// Successive [SoundSyncRepository] instances (including null while
/// unavailable), for the app-shell `SavedSoundsBloc` that is constructed
/// once in `SavedSoundsScope` and can never re-read
/// [soundSyncAvailabilityProvider] itself without re-inflating everything
/// below it. See `identityStreamOf`'s doc comment for the #6480 pattern
/// this follows.
final Provider<Stream<SoundSyncRepository?>> soundSyncRepositoryStreamProvider =
    identityStreamOf<SoundSyncRepository?>(soundSyncRepositoryValueProvider);
