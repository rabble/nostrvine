// ABOUTME: Tests for pushNotificationSync provider error handling.
// ABOUTME: Verifies firebase permission races don't escape the async listener.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/push_notification_service.dart';

class _MockFirebaseMessaging extends Mock implements FirebaseMessaging {}

class _MockAuthService extends Mock implements AuthService {}

class _MockPushNotificationService extends Mock
    implements PushNotificationService {}

NotificationSettings _settings(AuthorizationStatus status) =>
    NotificationSettings(
      alert: AppleNotificationSetting.enabled,
      announcement: AppleNotificationSetting.disabled,
      authorizationStatus: status,
      badge: AppleNotificationSetting.enabled,
      carPlay: AppleNotificationSetting.disabled,
      lockScreen: AppleNotificationSetting.enabled,
      notificationCenter: AppleNotificationSetting.enabled,
      showPreviews: AppleShowPreviewSetting.always,
      timeSensitive: AppleNotificationSetting.disabled,
      criticalAlert: AppleNotificationSetting.disabled,
      sound: AppleNotificationSetting.enabled,
      providesAppNotificationSettings: AppleNotificationSetting.disabled,
    );

void main() {
  late _MockFirebaseMessaging messaging;
  late _MockAuthService authService;
  late _MockPushNotificationService pushService;
  late StreamController<AuthState> authStateController;

  const pubkeyA =
      '1111111111111111111111111111111111111111111111111111111111111111';
  const pubkeyB =
      '2222222222222222222222222222222222222222222222222222222222222222';

  setUp(() {
    messaging = _MockFirebaseMessaging();
    authService = _MockAuthService();
    pushService = _MockPushNotificationService();
    authStateController = StreamController<AuthState>.broadcast();

    when(
      () => authService.authStateStream,
    ).thenAnswer((_) => authStateController.stream);
    when(() => authService.authState).thenReturn(AuthState.unauthenticated);
    when(() => authService.currentPublicKeyHex).thenReturn(null);

    when(() => pushService.register(any())).thenAnswer((_) async {});
    when(() => pushService.deregister(any())).thenAnswer((_) async {});
  });

  tearDown(() async {
    await authStateController.close();
  });

  ProviderContainer buildContainer() {
    final container = ProviderContainer(
      overrides: [
        firebaseMessagingProvider.overrideWithValue(messaging),
        authServiceProvider.overrideWithValue(authService),
        pushNotificationServiceProvider.overrideWithValue(pushService),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('pushNotificationSync', () {
    test('skips requestPermission when status is already authorized', () async {
      when(
        () => messaging.getNotificationSettings(),
      ).thenAnswer((_) async => _settings(AuthorizationStatus.authorized));

      final container = buildContainer();
      container.read(pushNotificationSyncProvider);

      when(() => authService.currentPublicKeyHex).thenReturn(pubkeyA);
      authStateController.add(AuthState.authenticated);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      verify(() => messaging.getNotificationSettings()).called(1);
      verifyNever(
        () => messaging.requestPermission(
          alert: any(named: 'alert'),
          announcement: any(named: 'announcement'),
          badge: any(named: 'badge'),
          carPlay: any(named: 'carPlay'),
          criticalAlert: any(named: 'criticalAlert'),
          provisional: any(named: 'provisional'),
          sound: any(named: 'sound'),
          providesAppNotificationSettings: any(
            named: 'providesAppNotificationSettings',
          ),
        ),
      );
      verify(() => pushService.register(pubkeyA)).called(1);
    });

    test('requests permission when status is notDetermined', () async {
      when(
        () => messaging.getNotificationSettings(),
      ).thenAnswer((_) async => _settings(AuthorizationStatus.notDetermined));
      when(
        () => messaging.requestPermission(
          alert: any(named: 'alert'),
          announcement: any(named: 'announcement'),
          badge: any(named: 'badge'),
          carPlay: any(named: 'carPlay'),
          criticalAlert: any(named: 'criticalAlert'),
          provisional: any(named: 'provisional'),
          sound: any(named: 'sound'),
          providesAppNotificationSettings: any(
            named: 'providesAppNotificationSettings',
          ),
        ),
      ).thenAnswer((_) async => _settings(AuthorizationStatus.authorized));

      final container = buildContainer();
      container.read(pushNotificationSyncProvider);

      when(() => authService.currentPublicKeyHex).thenReturn(pubkeyA);
      authStateController.add(AuthState.authenticated);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      verify(
        () => messaging.requestPermission(
          alert: any(named: 'alert'),
          announcement: any(named: 'announcement'),
          badge: any(named: 'badge'),
          carPlay: any(named: 'carPlay'),
          criticalAlert: any(named: 'criticalAlert'),
          provisional: any(named: 'provisional'),
          sound: any(named: 'sound'),
          providesAppNotificationSettings: any(
            named: 'providesAppNotificationSettings',
          ),
        ),
      ).called(1);
      verify(() => pushService.register(pubkeyA)).called(1);
    });

    test(
      'catches PlatformException from firebase_messaging permission race',
      () async {
        when(
          () => messaging.getNotificationSettings(),
        ).thenAnswer((_) async => _settings(AuthorizationStatus.notDetermined));
        when(
          () => messaging.requestPermission(
            alert: any(named: 'alert'),
            announcement: any(named: 'announcement'),
            badge: any(named: 'badge'),
            carPlay: any(named: 'carPlay'),
            criticalAlert: any(named: 'criticalAlert'),
            provisional: any(named: 'provisional'),
            sound: any(named: 'sound'),
            providesAppNotificationSettings: any(
              named: 'providesAppNotificationSettings',
            ),
          ),
        ).thenThrow(
          PlatformException(
            code: 'firebase_messaging/unknown',
            message:
                'A request for permissions is already running, '
                'please wait for it to finish before doing another request.',
          ),
        );

        final container = buildContainer();
        container.read(pushNotificationSyncProvider);

        // Collect any unhandled async errors from the listener.
        final unhandled = <Object>[];
        await runZonedGuarded(() async {
          when(() => authService.currentPublicKeyHex).thenReturn(pubkeyA);
          authStateController.add(AuthState.authenticated);
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);
        }, (error, stack) => unhandled.add(error));

        expect(
          unhandled,
          isEmpty,
          reason:
              'PlatformException from firebase_messaging must be caught '
              'inside the listener — otherwise it escapes to the enclosing '
              'zone and fails the surrounding integration test.',
        );
        // Permission failed, so pushService.register must not be invoked.
        verifyNever(() => pushService.register(any()));
      },
    );

    test('catches errors from pushService.register', () async {
      when(
        () => messaging.getNotificationSettings(),
      ).thenAnswer((_) async => _settings(AuthorizationStatus.authorized));
      when(
        () => pushService.register(any()),
      ).thenThrow(StateError('relay unreachable'));

      final container = buildContainer();
      container.read(pushNotificationSyncProvider);

      final unhandled = <Object>[];
      await runZonedGuarded(() async {
        when(() => authService.currentPublicKeyHex).thenReturn(pubkeyA);
        authStateController.add(AuthState.authenticated);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
      }, (error, stack) => unhandled.add(error));

      expect(unhandled, isEmpty);
    });

    test('catches errors from pushService.deregister', () async {
      when(
        () => messaging.getNotificationSettings(),
      ).thenAnswer((_) async => _settings(AuthorizationStatus.authorized));
      when(
        () => pushService.deregister(any()),
      ).thenThrow(StateError('relay unreachable'));

      final container = buildContainer();
      container.read(pushNotificationSyncProvider);

      final unhandled = <Object>[];
      await runZonedGuarded(() async {
        // First authenticate to set lastAuthenticatedPubkey.
        when(() => authService.currentPublicKeyHex).thenReturn(pubkeyA);
        authStateController.add(AuthState.authenticated);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // Then sign out — deregister throws.
        when(() => authService.currentPublicKeyHex).thenReturn(null);
        authStateController.add(AuthState.unauthenticated);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
      }, (error, stack) => unhandled.add(error));

      expect(unhandled, isEmpty);
    });

    test('survives rapid account switch (A → B) without unhandled error', () {
      // This is the exact E2E scenario: register A, sign out, register B.
      // First requestPermission is still pending when B's auth event fires,
      // causing the "already running" PlatformException.
      fakeAsync((async) {
        var requestCount = 0;
        when(
          () => messaging.getNotificationSettings(),
        ).thenAnswer((_) async => _settings(AuthorizationStatus.notDetermined));
        when(
          () => messaging.requestPermission(
            alert: any(named: 'alert'),
            announcement: any(named: 'announcement'),
            badge: any(named: 'badge'),
            carPlay: any(named: 'carPlay'),
            criticalAlert: any(named: 'criticalAlert'),
            provisional: any(named: 'provisional'),
            sound: any(named: 'sound'),
            providesAppNotificationSettings: any(
              named: 'providesAppNotificationSettings',
            ),
          ),
        ).thenAnswer((_) async {
          requestCount++;
          if (requestCount >= 2) {
            throw PlatformException(
              code: 'firebase_messaging/unknown',
              message: 'A request for permissions is already running',
            );
          }
          return _settings(AuthorizationStatus.authorized);
        });

        final container = buildContainer();
        container.read(pushNotificationSyncProvider);

        final unhandled = <Object>[];
        runZonedGuarded(() {
          when(() => authService.currentPublicKeyHex).thenReturn(pubkeyA);
          authStateController.add(AuthState.authenticated);
          async.flushMicrotasks();

          when(() => authService.currentPublicKeyHex).thenReturn(null);
          authStateController.add(AuthState.unauthenticated);
          async.flushMicrotasks();

          when(() => authService.currentPublicKeyHex).thenReturn(pubkeyB);
          authStateController.add(AuthState.authenticated);
          async.flushMicrotasks();
        }, (error, stack) => unhandled.add(error));

        expect(unhandled, isEmpty);
      });
    });
  });
}
