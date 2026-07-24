// ABOUTME: Riverpod dependency wiring for crossposting settings
// ABOUTME: Owns the API client lifecycle and repository construction

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/repositories/crossposting_repository.dart';
import 'package:openvine/services/auth_service.dart' show AuthState;
import 'package:openvine/services/crossposting_api_client.dart';

final crosspostingEligibleProvider = Provider<bool>((ref) {
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
