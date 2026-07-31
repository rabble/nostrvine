// ABOUTME: Riverpod dependency wiring for crossposting settings
// ABOUTME: Owns the API client lifecycle and repository construction

import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/repositories/crossposting_repository.dart';
import 'package:openvine/services/auth_service.dart' show AuthState;
import 'package:openvine/services/crossposting_api_client.dart';

/// Minimum iOS version whose `ASWebAuthenticationSession.Callback.https`
/// API can deliver the crossposting HTTPS OAuth callback.
const _minOAuthIosMajor = 17;
const _minOAuthIosMinor = 4;

/// Whether [systemVersion] (e.g. "17.4.1") meets the iOS OAuth floor.
///
/// Pure so the version matrix is unit-testable off-device. Fails closed on
/// unparseable input: an unknown iOS may carry the silent-cancel bug, and a
/// hidden flow is the recoverable failure.
bool iosVersionSupportsCrosspostingOAuth(String systemVersion) {
  final parts = systemVersion.split('.');
  final major = int.tryParse(parts.first);
  if (major == null) return false;
  final minor = parts.length > 1 ? int.tryParse(parts[1]) ?? -1 : 0;
  if (minor < 0) return false;
  return major > _minOAuthIosMajor ||
      (major == _minOAuthIosMajor && minor >= _minOAuthIosMinor);
}

/// Whether the current platform can deliver the HTTPS OAuth callback the
/// crossposting connect flow depends on.
///
/// Always true off iOS. On iOS, flutter_web_auth_2 only uses
/// `ASWebAuthenticationSession.Callback.https(host:path:)` on 17.4+, and
/// older versions can silently report a completed connection as a cancel —
/// so the flow is hidden there rather than offered. Fails closed when the
/// system version cannot be determined.
final crosspostingOAuthSupportProvider = FutureProvider<bool>((ref) async {
  if (kIsWeb || !Platform.isIOS) return true;
  try {
    final deviceInfo = await DeviceInfoPlugin().iosInfo;
    return iosVersionSupportsCrosspostingOAuth(deviceInfo.systemVersion);
  } catch (_) {
    return false;
  }
});

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
