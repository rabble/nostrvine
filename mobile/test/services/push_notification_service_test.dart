// ABOUTME: Tests for PushNotificationService covering FCM token registration,
// ABOUTME: deregistration, preference updates, and foreground message handling.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/models/notification_preferences.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/notification_service.dart';
import 'package:openvine/services/push_notification_service.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockNotificationService extends Mock implements NotificationService {}

class _MockNostrSigner extends Mock implements NostrSigner {}

class _FakeEvent extends Fake implements Event {}

class _ConfiguredEnvironmentConfig extends EnvironmentConfig {
  const _ConfiguredEnvironmentConfig({
    required super.environment,
    required this.configuredPushServicePubkey,
  });

  final String configuredPushServicePubkey;

  @override
  String get pushServicePubkey => configuredPushServicePubkey;
}

void main() {
  late _MockAuthService mockAuthService;
  late _MockNostrClient mockNostrClient;
  late _MockNotificationService mockNotificationService;
  late _MockNostrSigner mockNostrSigner;
  late StreamController<String> tokenRefreshController;

  const testPubkey =
      'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890';
  const testToken = 'fcm-test-token-abc123';
  const encryptedPayload = 'encrypted-payload-xyz';

  const configuredPushServicePubkey =
      '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';

  const testEnvironment = _ConfiguredEnvironmentConfig(
    environment: AppEnvironment.test,
    configuredPushServicePubkey: configuredPushServicePubkey,
  );

  const placeholderEnvironment = _ConfiguredEnvironmentConfig(
    environment: AppEnvironment.test,
    configuredPushServicePubkey: 'TODO_TEST_PUBKEY',
  );

  setUp(() {
    mockAuthService = _MockAuthService();
    mockNostrClient = _MockNostrClient();
    mockNotificationService = _MockNotificationService();
    mockNostrSigner = _MockNostrSigner();
    tokenRefreshController = StreamController<String>.broadcast();

    when(() => mockNostrClient.signer).thenReturn(mockNostrSigner);

    registerFallbackValue(_FakeEvent());
  });

  tearDown(() {
    tokenRefreshController.close();
  });

  PushNotificationService buildService({
    String? token = testToken,
  }) {
    return PushNotificationService(
      authService: mockAuthService,
      nostrClient: mockNostrClient,
      notificationService: mockNotificationService,
      environmentConfig: testEnvironment,
      getToken: () async => token,
      onTokenRefresh: tokenRefreshController.stream,
    );
  }

  group(PushNotificationService, () {
    group('register', () {
      test('encrypts token JSON and publishes kind 3079 event', () async {
        when(
          () => mockNostrSigner.nip44Encrypt(
            testEnvironment.pushServicePubkey,
            any(),
          ),
        ).thenAnswer((_) async => encryptedPayload);

        final fakeEvent = _FakeEvent();
        when(
          () => mockAuthService.createAndSignEvent(
            kind: PushNotificationService.pushRegistrationKind,
            content: encryptedPayload,
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => fakeEvent);

        when(
          () => mockNostrClient.publishEvent(fakeEvent),
        ).thenAnswer((_) async => fakeEvent);

        final service = buildService();
        await service.register(testPubkey);

        verify(
          () => mockNostrSigner.nip44Encrypt(
            testEnvironment.pushServicePubkey,
            '{"token":"$testToken"}',
          ),
        ).called(1);

        verify(
          () => mockAuthService.createAndSignEvent(
            kind: PushNotificationService.pushRegistrationKind,
            content: encryptedPayload,
            tags: any(named: 'tags'),
          ),
        ).called(1);

        verify(() => mockNostrClient.publishEvent(fakeEvent)).called(1);
        service.dispose();
      });

      test('includes required tags on registration event', () async {
        List<List<String>>? capturedTags;

        when(
          () => mockNostrSigner.nip44Encrypt(any(), any()),
        ).thenAnswer((_) async => encryptedPayload);

        final fakeEvent = _FakeEvent();
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((invocation) async {
          capturedTags =
              invocation.namedArguments[const Symbol('tags')]
                  as List<List<String>>?;
          return fakeEvent;
        });

        when(
          () => mockNostrClient.publishEvent(any()),
        ).thenAnswer((_) async => fakeEvent);

        final service = buildService();
        await service.register(testPubkey);

        expect(capturedTags, isNotNull);

        final pTag = capturedTags!.firstWhere(
          (t) => t.isNotEmpty && t[0] == 'p',
          orElse: () => [],
        );
        expect(pTag, hasLength(greaterThanOrEqualTo(2)));
        expect(pTag[1], equals(testEnvironment.pushServicePubkey));

        final appTag = capturedTags!.firstWhere(
          (t) => t.isNotEmpty && t[0] == 'app',
          orElse: () => [],
        );
        expect(appTag, hasLength(greaterThanOrEqualTo(2)));
        expect(
          appTag[1],
          equals(PushNotificationService.pushAppIdentifier),
        );

        final expirationTag = capturedTags!.firstWhere(
          (t) => t.isNotEmpty && t[0] == 'expiration',
          orElse: () => [],
        );
        expect(expirationTag, hasLength(greaterThanOrEqualTo(2)));
        final expirationValue = int.tryParse(expirationTag[1]);
        expect(expirationValue, isNotNull);
        expect(
          expirationValue,
          greaterThan(
            DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        );

        service.dispose();
      });

      test('does nothing when FCM token is null', () async {
        final service = buildService(token: null);
        await service.register(testPubkey);

        verifyNever(
          () => mockNostrSigner.nip44Encrypt(any(), any()),
        );
        verifyNever(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
          ),
        );
        service.dispose();
      });

      test(
        'skips registration when push service pubkey is still placeholder',
        () async {
          final service = PushNotificationService(
            authService: mockAuthService,
            nostrClient: mockNostrClient,
            notificationService: mockNotificationService,
            environmentConfig: placeholderEnvironment,
            getToken: () async => testToken,
            onTokenRefresh: tokenRefreshController.stream,
          );

          await service.register(testPubkey);

          verifyNever(() => mockNostrSigner.nip44Encrypt(any(), any()));
          verifyNever(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          );
          service.dispose();
        },
      );

      test('does nothing when NIP-44 encryption fails', () async {
        when(
          () => mockNostrSigner.nip44Encrypt(any(), any()),
        ).thenAnswer((_) async => null);

        final service = buildService();
        await service.register(testPubkey);

        verifyNever(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
          ),
        );
        service.dispose();
      });

      test('does nothing when event signing returns null', () async {
        when(
          () => mockNostrSigner.nip44Encrypt(any(), any()),
        ).thenAnswer((_) async => encryptedPayload);

        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => null);

        final service = buildService();
        await service.register(testPubkey);

        verifyNever(() => mockNostrClient.publishEvent(any()));
        service.dispose();
      });
    });

    group('deregister', () {
      test('publishes kind 3080 event with app tag', () async {
        final fakeEvent = _FakeEvent();
        when(
          () => mockAuthService.createAndSignEvent(
            kind: PushNotificationService.pushDeregistrationKind,
            content: '',
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => fakeEvent);

        when(
          () => mockNostrClient.publishEvent(fakeEvent),
        ).thenAnswer((_) async => fakeEvent);

        final service = buildService();
        await service.deregister(testPubkey);

        verify(
          () => mockAuthService.createAndSignEvent(
            kind: PushNotificationService.pushDeregistrationKind,
            content: '',
            tags: any(named: 'tags'),
          ),
        ).called(1);

        verify(() => mockNostrClient.publishEvent(fakeEvent)).called(1);
        service.dispose();
      });

      test('does not publish when event signing fails', () async {
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => null);

        final service = buildService();
        await service.deregister(testPubkey);

        verifyNever(() => mockNostrClient.publishEvent(any()));
        service.dispose();
      });
    });

    group('updatePreferences', () {
      test('encrypts kinds JSON and publishes kind 3083 event', () async {
        const prefs = NotificationPreferences(
          commentsEnabled: false,
          mentionsEnabled: false,
          repostsEnabled: false,
        );

        when(
          () => mockNostrSigner.nip44Encrypt(
            testEnvironment.pushServicePubkey,
            any(),
          ),
        ).thenAnswer((_) async => encryptedPayload);

        final fakeEvent = _FakeEvent();
        when(
          () => mockAuthService.createAndSignEvent(
            kind: PushNotificationService.pushPreferencesKind,
            content: encryptedPayload,
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => fakeEvent);

        when(
          () => mockNostrClient.publishEvent(fakeEvent),
        ).thenAnswer((_) async => fakeEvent);

        final service = buildService();
        await service.updatePreferences(prefs);

        final captureResult = verify(
          () => mockNostrSigner.nip44Encrypt(
            testEnvironment.pushServicePubkey,
            captureAny(),
          ),
        );
        captureResult.called(1);

        final capturedJson = captureResult.captured.first as String;
        expect(capturedJson, contains('"kinds"'));

        final kinds = prefs.toKindsList();
        for (final kind in kinds) {
          expect(capturedJson, contains(kind.toString()));
        }

        verify(
          () => mockAuthService.createAndSignEvent(
            kind: PushNotificationService.pushPreferencesKind,
            content: encryptedPayload,
            tags: any(named: 'tags'),
          ),
        ).called(1);

        verify(() => mockNostrClient.publishEvent(fakeEvent)).called(1);
        service.dispose();
      });

      test(
        'skips preferences update when push service pubkey is placeholder',
        () async {
          const prefs = NotificationPreferences();
          final service = PushNotificationService(
            authService: mockAuthService,
            nostrClient: mockNostrClient,
            notificationService: mockNotificationService,
            environmentConfig: placeholderEnvironment,
            getToken: () async => testToken,
            onTokenRefresh: tokenRefreshController.stream,
          );

          await service.updatePreferences(prefs);

          verifyNever(() => mockNostrSigner.nip44Encrypt(any(), any()));
          verifyNever(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          );
          service.dispose();
        },
      );
    });

    group('handleForegroundMessage', () {
      test(
        'sends local notification with title and body from message',
        () async {
          when(
            () => mockNotificationService.sendLocal(
              title: any(named: 'title'),
              body: any(named: 'body'),
            ),
          ).thenAnswer((_) async {});

          final service = buildService();
          await service.handleForegroundMessage({
            'title': 'New Like',
            'body': 'Someone liked your video',
          });

          verify(
            () => mockNotificationService.sendLocal(
              title: 'New Like',
              body: 'Someone liked your video',
            ),
          ).called(1);
          service.dispose();
        },
      );

      test('uses default app name as title when title is missing', () async {
        when(
          () => mockNotificationService.sendLocal(
            title: any(named: 'title'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async {});

        final service = buildService();
        await service.handleForegroundMessage({
          'body': 'Someone liked your video',
        });

        verify(
          () => mockNotificationService.sendLocal(
            title: 'diVine',
            body: 'Someone liked your video',
          ),
        ).called(1);
        service.dispose();
      });

      test('does not send notification when body is missing', () async {
        final service = buildService();
        await service.handleForegroundMessage({'title': 'New Like'});

        verifyNever(
          () => mockNotificationService.sendLocal(
            title: any(named: 'title'),
            body: any(named: 'body'),
          ),
        );
        service.dispose();
      });
    });

    group('token refresh', () {
      test('re-registers when token refreshes', () async {
        when(
          () => mockNostrSigner.nip44Encrypt(any(), any()),
        ).thenAnswer((_) async => encryptedPayload);

        final fakeEvent = _FakeEvent();
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => fakeEvent);

        when(
          () => mockNostrClient.publishEvent(any()),
        ).thenAnswer((_) async => fakeEvent);

        final service = buildService();

        // Trigger a token refresh
        tokenRefreshController.add('new-refreshed-token');
        await Future<void>.delayed(Duration.zero);

        // The registration call should be triggered by the token refresh
        verify(
          () => mockNostrSigner.nip44Encrypt(
            testEnvironment.pushServicePubkey,
            '{"token":"new-refreshed-token"}',
          ),
        ).called(1);

        service.dispose();
      });
    });

    group('dispose', () {
      test('cancels token refresh subscription without errors', () {
        final service = buildService();
        expect(service.dispose, returnsNormally);
      });
    });
  });
}
