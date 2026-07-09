// ABOUTME: Riverpod providers exposing the non-blocking protected-minor (13-15)
// ABOUTME: state from Keycast's verified_minor flag, for #175/#176 to consume.

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/protected_minor_status.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/repositories/protected_minor_repository.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/protected_minor_override_service.dart';
import 'package:openvine/services/protected_minor_sticky_store.dart';

/// Developer-only override service (debug builds).
final protectedMinorOverrideServiceProvider =
    Provider<ProtectedMinorOverrideService>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return ProtectedMinorOverrideService(prefs: prefs);
    });

/// Repository that reads `verified_minor` from Keycast for the current session.
final protectedMinorRepositoryProvider = Provider<ProtectedMinorRepository>((
  ref,
) {
  final oauthClient = ref.watch(oauthClientProvider);
  return ProtectedMinorRepository(
    oauthClient: oauthClient,
    readAccessToken: () async =>
        (await oauthClient.getSessionOrRefresh())?.accessToken,
  );
});

/// Non-blocking protected-minor state for the authenticated account.
///
/// Unauthenticated accounts are never protected. In debug builds a local
/// override short-circuits the real fetch. Otherwise the repository reads the
/// Keycast flag, preserving fetch failures as unknown so #175/#176 can choose
/// their own enforcement posture.
///
/// Notes for consumers (#175/#176):
/// - Resolving this may trigger a Keycast token refresh via
///   `getSessionOrRefresh()` (a network call + storage write) when the cached
///   session is stale. In the common case a valid session is reused with no
///   refresh.
/// - This only recomputes when auth state changes. An account approved as a
///   minor mid-session (no auth-state transition) will not refetch until the
///   provider is invalidated — call `ref.invalidate(protectedMinorStatusProvider)`
///   when fresh state is required.
final protectedMinorStatusProvider = FutureProvider<ProtectedMinorStatus>((
  ref,
) async {
  final authState = ref.watch(currentAuthStateProvider);
  if (authState != AuthState.authenticated) {
    return ProtectedMinorStatus.notProtected();
  }

  if (kDebugMode) {
    final override = ref
        .watch(protectedMinorOverrideServiceProvider)
        .getOverride();
    if (override != null) {
      return override
          ? ProtectedMinorStatus.protected()
          : ProtectedMinorStatus.notProtected();
    }
  }

  return ref.watch(protectedMinorRepositoryProvider).fetchCurrentStatus();
});

/// Convenience boolean seam for the protections (#175/#176).
///
/// Reads the last-known status via `.value`, so a protected minor stays
/// protected through a refetch (AsyncLoading) instead of flickering to
/// not-protected — matching the blocking review gate, which reads
/// `reviewStatusAsync.value` (`app_router.dart`). `false` only until the first
/// resolution.
///
/// Note: unknown/error status is still exposed on [protectedMinorStatusProvider]
/// for consumers that need to distinguish an unavailable check from confirmed
/// not-protected.
/// Persisted last-known protected-minor state (fail-safe backing, #175).
final protectedMinorStickyStoreProvider = Provider<ProtectedMinorStickyStore>((
  ref,
) {
  return ProtectedMinorStickyStore(prefs: ref.watch(sharedPreferencesProvider));
});

/// Whether a live protected-minor status may be trusted as a fresh signal for
/// the current account, or `null` to fall back to the persisted sticky value.
///
/// A status is only trustworthy when the session is **authenticated** and the
/// value is **freshly resolved** (`AsyncData`). This rejects two fail-safe
/// hazards: the `notProtected()` the #174 seam emits merely because auth has
/// not completed (cold start / session restore), and a stale value retained
/// from a previous account during a refetch (`AsyncLoading`/`AsyncError`).
ProtectedMinorStatus? trustedProtectedMinorStatus({
  required bool authenticated,
  required AsyncValue<ProtectedMinorStatus> live,
}) {
  if (!authenticated) return null;
  if (live is! AsyncData<ProtectedMinorStatus>) return null;
  return live.value;
}

/// Effective protected-minor seam for the protections (#175/#176), fail-safe.
///
/// The effective value is a trusted live status when available, else the
/// persisted last-known (sticky). A trusted status is also persisted for the
/// next cold start. Unknown/error and any untrusted status never weaken
/// protection: an account confirmed a protected minor stays protected offline
/// and at cold start, and lifts only on a positive not-a-minor signal from an
/// authenticated check (age-up / revocation).
final isProtectedMinorProvider = Provider<bool>((ref) {
  final authState = ref.watch(currentAuthStateProvider);
  final pubkey = ref.watch(authServiceProvider).currentPublicKeyHex;
  final store = ref.watch(protectedMinorStickyStoreProvider);
  final live = ref.watch(protectedMinorStatusProvider);

  // Account-switch safety relies on the invariant that every account swap
  // transits a non-authenticated authState (authenticating/checking), which
  // invalidates protectedMinorStatusProvider (it watches currentAuthStateProvider)
  // back into AsyncLoading before authState returns to authenticated for the new
  // account. That is why a stale AsyncData from a previous account can never be
  // trusted here. A future silent same-authState pubkey swap would need to also
  // invalidate the status provider to preserve this guarantee.
  final trusted = trustedProtectedMinorStatus(
    authenticated: authState == AuthState.authenticated,
    live: live,
  );
  if (trusted != null) {
    // Persist trusted transitions for future cold starts (fire-and-forget).
    store.applyLiveStatus(pubkey, trusted);
    if (trusted.kind == ProtectedMinorStatusKind.protected) return true;
    if (trusted.kind == ProtectedMinorStatusKind.notProtected) return false;
  }
  // Untrusted / unknown -> last-known persisted value (sticky).
  return store.isProtectedMinorFor(pubkey);
});

/// The #176 DM-restriction seam — fail CLOSED, a deliberate divergence from
/// [isProtectedMinorProvider] (which #175's content lock consumes fail-open):
/// the restricted party can trivially suppress the input that produces an
/// absent answer (airplane mode, cleared storage, blocked keycast domain,
/// expired token), so "no answer" must restrict rather than lift.
///
/// Restricted unless a positive not-protected verdict exists:
/// - trusted live `notProtected` -> unrestricted (persisted for cold start);
/// - persisted last-known `notProtected` -> unrestricted, so adults don't eat
///   a lockout on every network blip;
/// - everything else (protected, unknown, loading, missing token, never
///   resolved, unauthenticated) -> restricted.
///
/// Accepted cost per the design doc's fail-safe posture: a brand-new install
/// during a keycast outage can DM only official accounts until the first
/// check clears (rare, self-heals).
final isDmRestrictedProvider = Provider<bool>((ref) {
  final authState = ref.watch(currentAuthStateProvider);
  final pubkey = ref.watch(authServiceProvider).currentPublicKeyHex;
  final store = ref.watch(protectedMinorStickyStoreProvider);
  final live = ref.watch(protectedMinorStatusProvider);

  final trusted = trustedProtectedMinorStatus(
    authenticated: authState == AuthState.authenticated,
    live: live,
  );
  if (trusted != null) {
    // Same fire-and-forget persistence as isProtectedMinorProvider (idempotent
    // there and here; whichever seam resolves first records the verdict).
    store.applyLiveStatus(pubkey, trusted);
    if (trusted.kind == ProtectedMinorStatusKind.protected) return true;
    if (trusted.kind == ProtectedMinorStatusKind.notProtected) return false;
  }
  // No trusted answer: only a persisted positive not-protected lifts the
  // restriction; a never-seen account fails closed.
  return store.lastKnownFor(pubkey) ?? true;
});
