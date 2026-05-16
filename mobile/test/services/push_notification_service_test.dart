// ABOUTME: Tests for PushNotificationService covering FCM token registration,
// ABOUTME: deregistration, preference updates, and foreground message handling.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/models/notification_preferences.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nostr_identity.dart';
import 'package:openvine/services/notification_service.dart';
import 'package:openvine/services/push_notification_service.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockNotificationService extends Mock implements NotificationService {}

class _MockNostrSigner extends Mock implements NostrSigner {}

class _FakeEvent extends Fake implements Event {
  @override
  String get id => 'push-control-event-id';
}

class _MockEvent extends Mock implements Event {}

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

  const testPubkey =
      'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890';
  const testToken = 'fcm-test-token-abc123';
  const encryptedPayload = 'encrypted-payload-xyz';
  const pushPublishTimeout = Duration(seconds: 5);

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

    when(() => mockNostrClient.signer).thenReturn(mockNostrSigner);

    registerFallbackValue(_FakeEvent());
    registerFallbackValue(<String>[]);
    registerFallbackValue(Duration.zero);
  });

  PushNotificationService buildService({
    String? token = testToken,
    FutureOr<bool> Function()? isCurrent,
  }) {
    return PushNotificationService(
      authService: mockAuthService,
      nostrClient: mockNostrClient,
      notificationService: mockNotificationService,
      environmentConfig: testEnvironment,
      getToken: () async => token,
      isCurrent: isCurrent,
    );
  }

  group(PushNotificationService, () {
    group('register', () {
      test(
        'encrypts token JSON and publishes kind 3079 event to environment relay with OK timeout',
        () async {
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
            () => mockNostrClient.publishEventAwaitOk(
              fakeEvent,
              targetRelays: [testEnvironment.relayUrl],
              timeout: pushPublishTimeout,
              diagnosticTag: 'push-control',
            ),
          ).thenAnswer(
            (_) async => PublishOutcome(
              eventId: fakeEvent.id,
              acceptedBy: [testEnvironment.relayUrl],
              rejectedBy: const {},
              noResponseFrom: const [],
            ),
          );

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

          verify(
            () => mockNostrClient.publishEventAwaitOk(
              fakeEvent,
              targetRelays: [testEnvironment.relayUrl],
              timeout: pushPublishTimeout,
              diagnosticTag: 'push-control',
            ),
          ).called(1);
          service.dispose();
        },
      );

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
          () => mockNostrClient.publishEventAwaitOk(
            any(),
            targetRelays: any(named: 'targetRelays'),
            timeout: any(named: 'timeout'),
            diagnosticTag: any(named: 'diagnosticTag'),
          ),
        ).thenAnswer(
          (_) async => PublishOutcome(
            eventId: fakeEvent.id,
            acceptedBy: [testEnvironment.relayUrl],
            rejectedBy: const {},
            noResponseFrom: const [],
          ),
        );

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
        expect(appTag[1], equals(PushNotificationService.pushAppIdentifier));

        final expirationTag = capturedTags!.firstWhere(
          (t) => t.isNotEmpty && t[0] == 'expiration',
          orElse: () => [],
        );
        expect(expirationTag, hasLength(greaterThanOrEqualTo(2)));
        final expirationValue = int.tryParse(expirationTag[1]);
        expect(expirationValue, isNotNull);
        expect(
          expirationValue,
          greaterThan(DateTime.now().millisecondsSinceEpoch ~/ 1000),
        );

        service.dispose();
      });

      test('does nothing when FCM token is null', () async {
        final service = buildService(token: null);
        await service.register(testPubkey);

        verifyNever(() => mockNostrSigner.nip44Encrypt(any(), any()));
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

        verifyNever(
          () => mockNostrClient.publishEventAwaitOk(
            any(),
            targetRelays: any(named: 'targetRelays'),
            timeout: any(named: 'timeout'),
            diagnosticTag: any(named: 'diagnosticTag'),
          ),
        );
        service.dispose();
      });

      test(
        'completes without error when registration publish receives no OK response',
        () async {
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
            () => mockNostrClient.publishEventAwaitOk(
              fakeEvent,
              targetRelays: [testEnvironment.relayUrl],
              timeout: pushPublishTimeout,
              diagnosticTag: 'push-control',
            ),
          ).thenAnswer(
            (_) async => PublishOutcome(
              eventId: fakeEvent.id,
              acceptedBy: const [],
              rejectedBy: const {},
              noResponseFrom: [testEnvironment.relayUrl],
            ),
          );

          final service = buildService();
          await expectLater(service.register(testPubkey), completes);
          service.dispose();
        },
      );

      test(
        'completes without error when registration publish is rejected',
        () async {
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
            () => mockNostrClient.publishEventAwaitOk(
              fakeEvent,
              targetRelays: [testEnvironment.relayUrl],
              timeout: pushPublishTimeout,
              diagnosticTag: 'push-control',
            ),
          ).thenAnswer(
            (_) async => PublishOutcome(
              eventId: fakeEvent.id,
              acceptedBy: const [],
              rejectedBy: {testEnvironment.relayUrl: 'blocked'},
              noResponseFrom: const [],
            ),
          );

          final service = buildService();
          await expectLater(service.register(testPubkey), completes);
          service.dispose();
        },
      );
    });

    group('deregister', () {
      test(
        'publishes kind 3080 event to environment relay with OK timeout',
        () async {
          final fakeEvent = _FakeEvent();
          when(
            () => mockAuthService.createAndSignEvent(
              kind: PushNotificationService.pushDeregistrationKind,
              content: '',
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((_) async => fakeEvent);

          when(
            () => mockNostrClient.publishEventAwaitOk(
              fakeEvent,
              targetRelays: [testEnvironment.relayUrl],
              timeout: pushPublishTimeout,
              diagnosticTag: 'push-control',
            ),
          ).thenAnswer(
            (_) async => PublishOutcome(
              eventId: fakeEvent.id,
              acceptedBy: [testEnvironment.relayUrl],
              rejectedBy: const {},
              noResponseFrom: const [],
            ),
          );

          final service = buildService();
          await service.deregister(testPubkey);

          verify(
            () => mockAuthService.createAndSignEvent(
              kind: PushNotificationService.pushDeregistrationKind,
              content: '',
              tags: any(named: 'tags'),
            ),
          ).called(1);

          verify(
            () => mockNostrClient.publishEventAwaitOk(
              fakeEvent,
              targetRelays: [testEnvironment.relayUrl],
              timeout: pushPublishTimeout,
              diagnosticTag: 'push-control',
            ),
          ).called(1);
          service.dispose();
        },
      );

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

        verifyNever(
          () => mockNostrClient.publishEventAwaitOk(
            any(),
            targetRelays: any(named: 'targetRelays'),
            timeout: any(named: 'timeout'),
            diagnosticTag: any(named: 'diagnosticTag'),
          ),
        );
        service.dispose();
      });
      test(
        'completes without error when deregistration publish receives no OK response',
        () async {
          final fakeEvent = _FakeEvent();
          when(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((_) async => fakeEvent);

          when(
            () => mockNostrClient.publishEventAwaitOk(
              fakeEvent,
              targetRelays: [testEnvironment.relayUrl],
              timeout: pushPublishTimeout,
              diagnosticTag: 'push-control',
            ),
          ).thenAnswer(
            (_) async => PublishOutcome(
              eventId: fakeEvent.id,
              acceptedBy: const [],
              rejectedBy: const {},
              noResponseFrom: [testEnvironment.relayUrl],
            ),
          );

          final service = buildService();
          await expectLater(service.deregister(testPubkey), completes);
          service.dispose();
        },
      );

      test(
        'completes without error when deregistration publish is rejected',
        () async {
          final fakeEvent = _FakeEvent();
          when(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((_) async => fakeEvent);

          when(
            () => mockNostrClient.publishEventAwaitOk(
              fakeEvent,
              targetRelays: [testEnvironment.relayUrl],
              timeout: pushPublishTimeout,
              diagnosticTag: 'push-control',
            ),
          ).thenAnswer(
            (_) async => PublishOutcome(
              eventId: fakeEvent.id,
              acceptedBy: const [],
              rejectedBy: {testEnvironment.relayUrl: 'blocked'},
              noResponseFrom: const [],
            ),
          );

          final service = buildService();
          await expectLater(service.deregister(testPubkey), completes);
          service.dispose();
        },
      );

      test(
        'does not sign deregistration when session is already stale',
        () async {
          final service = buildService(isCurrent: () => false);

          await service.deregister(testPubkey);

          verifyNever(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          );
          verifyNever(() => mockNostrClient.publishEvent(any()));
          service.dispose();
        },
      );

      test(
        'does not publish deregistration when session becomes stale after signing',
        () async {
          var current = true;
          final fakeEvent = _MockEvent();
          when(
            () => fakeEvent.id,
          ).thenReturn('captured-deregistration-event-id');
          when(() => fakeEvent.isSigned).thenReturn(true);
          when(() => fakeEvent.isValid).thenReturn(true);
          when(
            () => mockAuthService.createAndSignEvent(
              kind: PushNotificationService.pushDeregistrationKind,
              content: '',
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((_) async {
            current = false;
            return fakeEvent;
          });

          final service = buildService(isCurrent: () => current);

          await service.deregister(testPubkey);

          verify(
            () => mockAuthService.createAndSignEvent(
              kind: PushNotificationService.pushDeregistrationKind,
              content: '',
              tags: any(named: 'tags'),
            ),
          ).called(1);
          verifyNever(() => mockNostrClient.publishEvent(any()));
          service.dispose();
        },
      );

      test(
        'can sign deregistration with captured outgoing identity',
        () async {
          final capturedSigner = _MockNostrSigner();
          final capturedIdentity = KeycastNostrIdentity(
            pubkey: testPubkey,
            rpcSigner: capturedSigner,
          );
          final fakeEvent = _MockEvent();
          when(
            () => fakeEvent.id,
          ).thenReturn('captured-deregistration-event-id');
          when(() => fakeEvent.isSigned).thenReturn(true);
          when(() => fakeEvent.isValid).thenReturn(true);
          when(
            () => capturedSigner.signEvent(any()),
          ).thenAnswer((_) async => fakeEvent);
          when(
            () => mockNostrClient.publishEventAwaitOk(
              fakeEvent,
              targetRelays: [testEnvironment.relayUrl],
              timeout: pushPublishTimeout,
              diagnosticTag: 'push-control',
            ),
          ).thenAnswer(
            (_) async => PublishOutcome(
              eventId: fakeEvent.id,
              acceptedBy: [testEnvironment.relayUrl],
              rejectedBy: const {},
              noResponseFrom: const [],
            ),
          );

          final service = buildService(isCurrent: () => false);
          await service.deregister(
            testPubkey,
            signingIdentity: capturedIdentity,
          );

          verifyNever(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          );
          verify(() => capturedSigner.signEvent(any())).called(1);
          verify(
            () => mockNostrClient.publishEventAwaitOk(
              fakeEvent,
              targetRelays: [testEnvironment.relayUrl],
              timeout: pushPublishTimeout,
              diagnosticTag: 'push-control',
            ),
          ).called(1);
          service.dispose();
        },
      );

      test(
        'publishes captured-identity deregistration with supplied cleanup client',
        () async {
          final capturedSigner = _MockNostrSigner();
          final capturedIdentity = KeycastNostrIdentity(
            pubkey: testPubkey,
            rpcSigner: capturedSigner,
          );
          final cleanupClient = _MockNostrClient();
          final fakeEvent = _MockEvent();
          when(
            () => fakeEvent.id,
          ).thenReturn('cleanup-deregistration-event-id');
          when(() => fakeEvent.isSigned).thenReturn(true);
          when(() => fakeEvent.isValid).thenReturn(true);
          when(
            () => capturedSigner.signEvent(any()),
          ).thenAnswer((_) async => fakeEvent);
          when(
            () => cleanupClient.publishEventAwaitOk(
              fakeEvent,
              targetRelays: [testEnvironment.relayUrl],
              timeout: pushPublishTimeout,
              diagnosticTag: 'push-control',
            ),
          ).thenAnswer(
            (_) async => PublishOutcome(
              eventId: fakeEvent.id,
              acceptedBy: [testEnvironment.relayUrl],
              rejectedBy: const {},
              noResponseFrom: const [],
            ),
          );

          final service = buildService(isCurrent: () => false);
          await service.deregister(
            testPubkey,
            signingIdentity: capturedIdentity,
            publishClient: cleanupClient,
          );

          verify(() => capturedSigner.signEvent(any())).called(1);
          verifyNever(
            () => mockNostrClient.publishEventAwaitOk(
              any(),
              targetRelays: any(named: 'targetRelays'),
              timeout: any(named: 'timeout'),
              diagnosticTag: any(named: 'diagnosticTag'),
            ),
          );
          verify(
            () => cleanupClient.publishEventAwaitOk(
              fakeEvent,
              targetRelays: [testEnvironment.relayUrl],
              timeout: pushPublishTimeout,
              diagnosticTag: 'push-control',
            ),
          ).called(1);
          service.dispose();
        },
      );
    });

    group('updatePreferences', () {
      test(
        'encrypts kinds JSON and publishes kind 3083 event to environment relay with OK timeout',
        () async {
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
            () => mockNostrClient.publishEventAwaitOk(
              fakeEvent,
              targetRelays: [testEnvironment.relayUrl],
              timeout: pushPublishTimeout,
              diagnosticTag: 'push-control',
            ),
          ).thenAnswer(
            (_) async => PublishOutcome(
              eventId: fakeEvent.id,
              acceptedBy: [testEnvironment.relayUrl],
              rejectedBy: const {},
              noResponseFrom: const [],
            ),
          );

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

          verify(
            () => mockNostrClient.publishEventAwaitOk(
              fakeEvent,
              targetRelays: [testEnvironment.relayUrl],
              timeout: pushPublishTimeout,
              diagnosticTag: 'push-control',
            ),
          ).called(1);
          service.dispose();
        },
      );

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
      test(
        'completes without error when preferences publish receives no OK response',
        () async {
          const prefs = NotificationPreferences();

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
            () => mockNostrClient.publishEventAwaitOk(
              fakeEvent,
              targetRelays: [testEnvironment.relayUrl],
              timeout: pushPublishTimeout,
              diagnosticTag: 'push-control',
            ),
          ).thenAnswer(
            (_) async => PublishOutcome(
              eventId: fakeEvent.id,
              acceptedBy: const [],
              rejectedBy: const {},
              noResponseFrom: [testEnvironment.relayUrl],
            ),
          );

          final service = buildService();
          await expectLater(service.updatePreferences(prefs), completes);
          service.dispose();
        },
      );

      test(
        'completes without error when preferences publish is rejected',
        () async {
          const prefs = NotificationPreferences();

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
            () => mockNostrClient.publishEventAwaitOk(
              fakeEvent,
              targetRelays: [testEnvironment.relayUrl],
              timeout: pushPublishTimeout,
              diagnosticTag: 'push-control',
            ),
          ).thenAnswer(
            (_) async => PublishOutcome(
              eventId: fakeEvent.id,
              acceptedBy: const [],
              rejectedBy: {testEnvironment.relayUrl: 'blocked'},
              noResponseFrom: const [],
            ),
          );

          final service = buildService();
          await expectLater(service.updatePreferences(prefs), completes);
          service.dispose();
        },
      );

      test(
        'drops preferences update when session changes after signing',
        () async {
          const prefs = NotificationPreferences();
          var current = true;
          when(
            () => mockNostrSigner.nip44Encrypt(any(), any()),
          ).thenAnswer((_) async => encryptedPayload);

          final fakeEvent = _FakeEvent();
          when(
            () => mockAuthService.createAndSignEvent(
              kind: PushNotificationService.pushPreferencesKind,
              content: encryptedPayload,
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((_) async {
            current = false;
            return fakeEvent;
          });

          final service = buildService(isCurrent: () => current);
          await service.updatePreferences(prefs);

          verifyNever(() => mockNostrClient.publishEvent(any()));
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

    group('registerToken', () {
      test(
        'publishes provided refreshed token through environment relay OK publish',
        () async {
          when(
            () => mockNostrSigner.nip44Encrypt(any(), any()),
          ).thenAnswer((_) async => encryptedPayload);
          when(() => mockAuthService.currentIdentity).thenReturn(
            KeycastNostrIdentity(
              pubkey: testPubkey,
              rpcSigner: mockNostrSigner,
            ),
          );

          final fakeEvent = _FakeEvent();
          when(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((_) async => fakeEvent);

          when(
            () => mockNostrClient.publishEventAwaitOk(
              fakeEvent,
              targetRelays: [testEnvironment.relayUrl],
              timeout: pushPublishTimeout,
              diagnosticTag: 'push-control',
            ),
          ).thenAnswer(
            (_) async => PublishOutcome(
              eventId: fakeEvent.id,
              acceptedBy: [testEnvironment.relayUrl],
              rejectedBy: const {},
              noResponseFrom: const [],
            ),
          );

          final service = buildService();

          await service.registerToken(testPubkey, 'new-refreshed-token');

          verify(
            () => mockNostrSigner.nip44Encrypt(
              testEnvironment.pushServicePubkey,
              '{"token":"new-refreshed-token"}',
            ),
          ).called(1);

          verify(
            () => mockNostrClient.publishEventAwaitOk(
              fakeEvent,
              targetRelays: [testEnvironment.relayUrl],
              timeout: pushPublishTimeout,
              diagnosticTag: 'push-control',
            ),
          ).called(1);

          service.dispose();
        },
      );

      test(
        'drops refreshed token registration when session is stale',
        () async {
          when(() => mockAuthService.currentIdentity).thenReturn(
            KeycastNostrIdentity(
              pubkey: testPubkey,
              rpcSigner: mockNostrSigner,
            ),
          );
          final service = buildService(isCurrent: () => false);

          await service.registerToken(testPubkey, 'new-refreshed-token');

          verifyNever(() => mockNostrSigner.nip44Encrypt(any(), any()));
          service.dispose();
        },
      );
    });

    group('dispose', () {
      test('completes without errors', () {
        final service = buildService();
        expect(service.dispose, returnsNormally);
      });
    });
  });
}
