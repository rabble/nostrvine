// ABOUTME: Riverpod wiring for creator sync repositories.
// ABOUTME: Returns null until the vault key resolves, gating the UI.

import 'dart:async';

import 'package:creator_sync/creator_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

  final vaultKeyService = VaultKeyService(
    signer: client.signer,
    client: client,
    cache: SecureVaultKeyCache(const FlutterSecureStorage()),
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
    state: PrefsSyncStateStore(
      ref.watch(sharedPreferencesProvider),
      pubkeyHex: pubkeyHex,
    ),
    local: SavedSoundsLocalStore(ref.watch(savedSoundsServiceProvider)),
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
