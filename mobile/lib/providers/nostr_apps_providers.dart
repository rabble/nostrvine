// ABOUTME: Nostr Apps Riverpod providers split from app_providers.dart
// ABOUTME: Owns the apps-directory client, grant store, audit, bridge policy/service

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:openvine/config/app_config.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/services/nip98_auth_service.dart';

final nostrAppDirectoryServiceProvider = Provider<NostrAppDirectoryService>((
  ref,
) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final client = Client();
  ref.onDispose(client.close);
  return NostrAppDirectoryService(
    sharedPreferences: prefs,
    client: client,
    baseUrl: AppConfig.appsDirectoryBaseUrl,
  );
});

final nostrAppGrantStoreProvider = Provider<NostrAppGrantStore>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return NostrAppGrantStore(sharedPreferences: prefs);
});

final nostrAppBridgePolicyProvider = Provider<NostrAppBridgePolicy>((ref) {
  final authService = ref.watch(authServiceProvider);
  final grantStore = ref.watch(nostrAppGrantStoreProvider);
  return NostrAppBridgePolicy(
    grantStore: grantStore,
    currentUserPubkey: authService.currentPublicKeyHex,
  );
});

final nostrAppAuditServiceProvider = Provider<NostrAppAuditService>((ref) {
  final nip98AuthService = ref.watch(nip98AuthServiceProvider);
  final client = Client();
  ref.onDispose(client.close);
  return NostrAppAuditService(
    workerBaseUri: Uri.parse(AppConfig.appsDirectoryBaseUrl),
    authTokenProvider:
        ({required url, required method, required payload}) async {
          final token = await nip98AuthService.createAuthToken(
            url: url,
            method: HttpMethod.post,
            payload: payload,
          );
          if (token == null) return null;
          return AuditAuthToken(authorizationHeader: token.authorizationHeader);
        },
    httpClient: client,
  );
});

final nostrAppBridgeServiceProvider = Provider<NostrAppBridgeService>((ref) {
  final authService = ref.watch(authServiceProvider);
  final policy = ref.watch(nostrAppBridgePolicyProvider);
  final auditService = ref.watch(nostrAppAuditServiceProvider);
  return NostrAppBridgeService(
    authProvider: _AuthServiceBridgeAdapter(authService),
    policy: policy,
    signerFactory: () => authService.requireIdentity,
    auditService: auditService,
  );
});

/// Adapts the app-level [AuthService] to the package-level
/// [BridgeAuthProvider] interface.
class _AuthServiceBridgeAdapter implements BridgeAuthProvider {
  const _AuthServiceBridgeAdapter(this._authService);

  final AuthService _authService;

  @override
  String? get currentPublicKeyHex => _authService.currentPublicKeyHex;

  @override
  List<BridgeRelay> get userRelays => _authService.userRelays
      .map((r) => BridgeRelay(url: r.url, read: r.read, write: r.write))
      .toList();

  @override
  Future<BridgeSignedEvent?> createAndSignEvent({
    required int kind,
    required String content,
    required List<List<String>> tags,
    int? createdAt,
  }) async {
    final event = await _authService.createAndSignEvent(
      kind: kind,
      content: content,
      tags: tags,
      createdAt: createdAt,
    );
    if (event == null) return null;
    return BridgeSignedEvent(json: event.toJson());
  }
}
