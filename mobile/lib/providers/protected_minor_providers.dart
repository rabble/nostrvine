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
final isProtectedMinorProvider = Provider<bool>((ref) {
  return ref.watch(protectedMinorStatusProvider).value?.isProtectedMinor ??
      false;
});
