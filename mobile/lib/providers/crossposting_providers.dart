// ABOUTME: Riverpod dependency wiring for crossposting settings
// ABOUTME: Owns the API client lifecycle and repository construction

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/features/oauth/app_oauth_support.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/repositories/crossposting_repository.dart';
import 'package:openvine/services/auth_service.dart' show AuthState;
import 'package:openvine/services/crossposting_api_client.dart';

/// Whether [systemVersion] (e.g. "17.4.1") meets the iOS OAuth floor.
///
/// Alias of [iosVersionSupportsAppOAuth] — the floor is a property of the
/// shared callback, not of crossposting.
const bool Function(String) iosVersionSupportsCrosspostingOAuth =
    iosVersionSupportsAppOAuth;

/// Whether the current platform can deliver the HTTPS OAuth callback the
/// crossposting connect flow depends on.
///
/// Alias of [appOAuthSupportProvider]; see it for the iOS 17.4 rationale.
final FutureProvider<bool> crosspostingOAuthSupportProvider =
    appOAuthSupportProvider;

final crosspostingEligibleProvider = Provider<bool>((ref) {
  // Hidden entirely while the platform's OAuth callback path is unknown or
  // unreliable (iOS < 17.4) — offering the flow there fails mid-session.
  final oauthSupported =
      ref.watch(crosspostingOAuthSupportProvider).value ?? false;
  if (!oauthSupported) return false;
  final authState = ref.watch(currentAuthStateProvider);
  final authService = ref.watch(authServiceProvider);
  return authState == AuthState.authenticated &&
      authService.currentPublicKeyHex != null &&
      authService.isRegistered;
});

typedef CrosspostingApiClientFactory =
    CrosspostingApiClient Function(
      CrosspostingAccessTokenReader accessTokenReader,
    );

final crosspostingApiClientFactoryProvider =
    Provider<CrosspostingApiClientFactory>((ref) {
      return (accessTokenReader) =>
          CrosspostingApiClient(accessTokenReader: accessTokenReader);
    });

final crosspostingApiClientProvider = Provider<CrosspostingApiClient>((ref) {
  final authService = ref.watch(authServiceProvider);
  final createClient = ref.watch(crosspostingApiClientFactoryProvider);
  final client = createClient(authService.getBoundDivineAccessToken);
  ref.onDispose(client.close);
  return client;
});

final crosspostingRepositoryProvider = Provider<CrosspostingRepository>((ref) {
  return CrosspostingRepository(ref.watch(crosspostingApiClientProvider));
});
