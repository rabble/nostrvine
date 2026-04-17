// ABOUTME: Riverpod provider that constructs NotificationRepository
// ABOUTME: with all dependencies (API client, profile repo, DAO, auth).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/services/nip98_auth_service.dart';
import 'package:openvine/utils/relay_url_utils.dart';

/// Riverpod provider that creates and exposes a [NotificationRepository].
///
/// Bridges the BLoC-based notification system into the existing Riverpod
/// dependency graph so the BLoC can be constructed in a ConsumerWidget.
///
/// Returns `null` when the [ProfileRepository] is not yet available
/// (e.g. during early auth when the NostrClient hasn't been initialised).
final notificationRepositoryProvider = Provider<NotificationRepository?>((ref) {
  final environmentConfig = ref.watch(currentEnvironmentProvider);
  final nostrService = ref.watch(nostrServiceProvider);
  final notificationsBaseUrl = resolvePinnedApiBaseUrlFromRelays(
    configuredRelays: nostrService.configuredRelays,
    fallbackBaseUrl: relayWsToHttpBase(environmentConfig.relayUrl),
  );
  final funnelcakeApiClient = FunnelcakeApiClient(
    baseUrl: notificationsBaseUrl,
  );
  final profileRepository = ref.watch(profileRepositoryProvider);

  // ProfileRepository is nullable during early auth. Return null so the
  // page can show a loading state until deps are ready.
  if (profileRepository == null) return null;

  final db = ref.watch(databaseProvider);
  final authService = ref.watch(authServiceProvider);
  final nip98AuthService = ref.watch(nip98AuthServiceProvider);
  final userPubkey = authService.currentPublicKeyHex ?? '';

  final blocklistService = ref.watch(contentBlocklistServiceProvider);
  return NotificationRepository(
    funnelcakeApiClient: funnelcakeApiClient,
    profileRepository: profileRepository,
    notificationsDao: db.notificationsDao,
    userPubkey: userPubkey,
    blockFilter: blocklistService.shouldFilterFromFeeds,
    authHeadersProvider: (url, method) async {
      final httpMethod = switch (method.toUpperCase()) {
        'POST' => HttpMethod.post,
        'PUT' => HttpMethod.put,
        'DELETE' => HttpMethod.delete,
        'PATCH' => HttpMethod.patch,
        _ => HttpMethod.get,
      };
      final token = await nip98AuthService.createAuthToken(
        url: url,
        method: httpMethod,
      );
      if (token == null) return <String, String>{};
      return {'Authorization': token.authorizationHeader};
    },
  );
});
