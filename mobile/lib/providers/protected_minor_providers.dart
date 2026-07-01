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
/// Keycast flag, failing to not-protected on any error (#174 is detection-only).
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
          ? const ProtectedMinorStatus(isProtectedMinor: true)
          : ProtectedMinorStatus.notProtected();
    }
  }

  return ref.watch(protectedMinorRepositoryProvider).fetchCurrentStatus();
});

/// Convenience boolean for widgets/protections: true only once the status has
/// resolved to a protected minor (loading/error read as not protected).
final isProtectedMinorProvider = Provider<bool>((ref) {
  return ref
      .watch(protectedMinorStatusProvider)
      .maybeWhen(data: (s) => s.isProtectedMinor, orElse: () => false);
});
