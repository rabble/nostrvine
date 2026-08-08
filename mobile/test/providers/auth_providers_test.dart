// ABOUTME: Tests for authentication provider wiring.
// ABOUTME: Guards secure storage options that affect session persistence.

import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/services/auth_service.dart';

class _MockAuthService extends Mock implements AuthService {}

class _RecordingAnalytics implements AnalyticsEventSink {
  final userIds = <String?>[];

  @override
  Future<void> setUserId(String? userId) async => userIds.add(userId);

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {}

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async {}

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object>? parameters,
  }) async {}
}

void main() {
  group('flutterSecureStorageProvider', () {
    test('keeps Android secure storage encrypted without reset-on-error', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final storage = container.read(flutterSecureStorageProvider);
      final androidOptions = storage.aOptions.toMap();

      expect(androidOptions['encryptedSharedPreferences'], 'true');
      expect(androidOptions['resetOnError'], 'false');
    });
  });

  group('zendeskIdentitySyncProvider', () {
    const pubkey =
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

    test('fans restored login identity out and clears it on logout', () async {
      final authStateController = StreamController<AuthState>.broadcast();
      addTearDown(authStateController.close);
      final authService = _MockAuthService();
      when(() => authService.isAuthenticated).thenReturn(true);
      when(() => authService.currentPublicKeyHex).thenReturn(pubkey);
      when(
        () => authService.authStateStream,
      ).thenAnswer((_) => authStateController.stream);

      final analytics = _RecordingAnalytics();
      final crashUserIds = <String?>[];
      final identityCoordinator = AnalyticsIdentityCoordinator(
        analytics: analytics,
        setCrashUserId: (userId) async => crashUserIds.add(userId),
      );
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          profileRepositoryProvider.overrideWithValue(null),
          analyticsIdentityCoordinatorProvider.overrideWithValue(
            identityCoordinator,
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(zendeskIdentitySyncProvider);
      await Future<void>.delayed(Duration.zero);

      expect(analytics.userIds, [pubkey]);
      expect(crashUserIds, [pubkey]);

      authStateController.add(AuthState.unauthenticated);
      await Future<void>.delayed(Duration.zero);

      expect(analytics.userIds, [pubkey, null]);
      expect(crashUserIds, [pubkey, null]);
    });
  });
}
