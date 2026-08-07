// ABOUTME: Riverpod wiring for creator sync repositories.
// ABOUTME: Returns null until the vault key resolves, gating the UI.

import 'dart:async';

import 'package:creator_sync/creator_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/saved_sounds_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/creator_sync/prefs_sync_state_store.dart';
import 'package:openvine/services/creator_sync/saved_sounds_local_store.dart';
import 'package:openvine/services/creator_sync/secure_vault_key_cache.dart';

/// The sound sync repository, or null until the vault key is available.
///
/// Follows the nullable-gate pattern already used by
/// `profileRepository` (`repository_providers.dart`): the repository only
/// exists once [nostrSessionProvider] reports a signer-backed client ready
/// for the active identity and the vault key resolves, so no consumer can
/// ever capture a half-initialised dependency and no `ValueKey` guard is
/// needed at the call site. The UI renders a disabled sync affordance while
/// this stays null.
final soundSyncRepositoryProvider = FutureProvider<SoundSyncRepository?>((
  ref,
) async {
  final readiness = ref.watch(nostrSessionProvider);
  if (!readiness.isReadyForActiveClient) return null;

  final client = readiness.client!;
  final pubkeyHex = readiness.pubkey!;
  // Hoisted above the await below: every ref.watch must run before the
  // first suspension point. obtain() is a relay round trip that can take
  // seconds, and a sign-out/account-switch/session-re-advance in that
  // window disposes this provider's element — a ref.watch reached after
  // that throws UnmountedRefException. Reading these here also registers
  // the dependency on the VaultKeyUnavailableException early-return path
  // below, so this provider still rebuilds when they change even when it
  // resolves to null.
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
    // Expected offline and during cold start. Null keeps the UI disabled
    // rather than surfacing a spurious failure.
    return null;
  }

  return SoundSyncRepository(
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
  );
});
