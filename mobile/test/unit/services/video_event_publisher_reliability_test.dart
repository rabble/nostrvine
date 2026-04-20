// ABOUTME: Tests video publishing wraps NostrClient.publishEventWithRetry and
// ABOUTME: surfaces outcome+feedback on its result type.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show VideoEvent;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/video_event_publisher.dart';
import 'package:openvine/services/video_event_service.dart';

class _MockUploadManager extends Mock implements UploadManager {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

class _MockPersonalEventCacheService extends Mock
    implements PersonalEventCacheService {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _FakeEvent extends Fake implements Event {}

class _FakeVideoEvent extends Fake implements VideoEvent {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testPubkey =
      '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd';

  late _MockUploadManager mockUploadManager;
  late _MockNostrClient mockNostrClient;
  late _MockAuthService mockAuthService;
  late _MockPersonalEventCacheService mockPersonalEventCache;
  late _MockVideoEventService mockVideoEventService;
  late VideoEventPublisher publisher;

  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(_FakeVideoEvent());
    registerFallbackValue(UploadStatus.pending);
    registerFallbackValue(const RetryPolicy());
  });

  setUp(() {
    mockUploadManager = _MockUploadManager();
    mockNostrClient = _MockNostrClient();
    mockAuthService = _MockAuthService();
    mockPersonalEventCache = _MockPersonalEventCacheService();
    mockVideoEventService = _MockVideoEventService();

    publisher = VideoEventPublisher(
      uploadManager: mockUploadManager,
      nostrService: mockNostrClient,
      authService: mockAuthService,
      personalEventCache: mockPersonalEventCache,
      videoEventService: mockVideoEventService,
    );

    when(() => mockAuthService.isAuthenticated).thenReturn(true);
    when(() => mockAuthService.currentPublicKeyHex).thenReturn(testPubkey);

    when(() => mockNostrClient.isInitialized).thenReturn(true);
    when(() => mockNostrClient.configuredRelayCount).thenReturn(1);
    when(() => mockNostrClient.connectedRelayCount).thenReturn(1);
    when(
      () => mockNostrClient.configuredRelays,
    ).thenReturn(const ['wss://relay.divine.video']);
    when(
      () => mockNostrClient.connectedRelays,
    ).thenReturn(const ['wss://relay.divine.video']);
    when(() => mockNostrClient.publicKey).thenReturn(testPubkey);

    when(
      () => mockUploadManager.updateUploadStatus(
        any(),
        any(),
        nostrEventId: any(named: 'nostrEventId'),
      ),
    ).thenAnswer((_) async {});

    when(() => mockPersonalEventCache.cacheUserEvent(any())).thenReturn(null);
    when(() => mockPersonalEventCache.getEventById(any())).thenReturn(null);
    when(() => mockVideoEventService.addVideoEvent(any())).thenReturn(null);
  });

  PendingUpload createUpload() {
    return PendingUpload(
      id: 'test-upload-id',
      localVideoPath: '/tmp/test.mp4',
      nostrPubkey: testPubkey,
      status: UploadStatus.readyToPublish,
      createdAt: DateTime.now(),
      videoId: 'test-video-id',
      title: 'Plants',
      cdnUrl: 'https://cdn.example.com/video.mp4',
      fallbackUrl: 'https://cdn.example.com/video.mp4',
    );
  }

  Event createSignedEvent() {
    return Event(
      testPubkey,
      NIP71VideoKinds.getPreferredAddressableKind(),
      const [
        ['d', 'test-video-id'],
        ['title', 'Plants'],
        ['imeta', 'url https://cdn.example.com/video.mp4', 'm video/mp4'],
      ],
      'A plant video',
      createdAt: 1700000000,
    );
  }

  void stubSigning(Event event) {
    when(
      () => mockAuthService.createAndSignEvent(
        kind: any(named: 'kind'),
        content: any(named: 'content'),
        tags: any(named: 'tags'),
      ),
    ).thenAnswer((_) async => event);
  }

  void stubPublishOutcome(PublishOutcome outcome) {
    when(
      () => mockNostrClient.publishEventWithRetry(
        any(),
        policy: any(named: 'policy'),
        targetRelays: any(named: 'targetRelays'),
      ),
    ).thenAnswer((_) async => outcome);
  }

  group('VideoEventPublisher reliability', () {
    test(
      'accepted-by-any → success result with outcome + feedback',
      () async {
        final signedEvent = createSignedEvent();
        stubSigning(signedEvent);
        stubPublishOutcome(
          PublishOutcome(
            eventId: signedEvent.id,
            acceptedBy: const {'wss://a'},
            rejectedBy: const {},
            noResponseFrom: const {},
          ),
        );

        final result = await publisher.publishDirectUpload(createUpload());

        expect(result.success, isTrue);
        expect(result.outcome, isNotNull);
        expect(result.outcome!.acceptedBy, {'wss://a'});
        expect(result.feedback?.severity, PublishSeverity.success);
        expect(result.feedback?.retryable, isFalse);
        expect(result.eventId, signedEvent.id);

        verify(
          () => mockNostrClient.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).called(1);

        verify(
          () => mockUploadManager.updateUploadStatus(
            'test-upload-id',
            UploadStatus.published,
            nostrEventId: signedEvent.id,
          ),
        ).called(1);
        verify(() => mockVideoEventService.addVideoEvent(any())).called(1);
      },
    );

    test(
      'all-no-response → retryable failure result with outcome + feedback',
      () async {
        final signedEvent = createSignedEvent();
        stubSigning(signedEvent);
        stubPublishOutcome(
          PublishOutcome(
            eventId: signedEvent.id,
            acceptedBy: const {},
            rejectedBy: const {},
            noResponseFrom: const {'wss://a', 'wss://b'},
          ),
        );

        final result = await publisher.publishDirectUpload(createUpload());

        expect(result.success, isFalse);
        expect(result.feedback?.severity, PublishSeverity.error);
        expect(result.feedback?.retryable, isTrue);
        expect(result.feedback?.messageKey, 'publish_no_relay_response');

        // Ad-hoc 3x retry loop is removed; publishEventWithRetry owns retry.
        verify(
          () => mockNostrClient.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).called(1);
        // publishEvent (the old one-shot API) must not be called anymore.
        verifyNever(() => mockNostrClient.publishEvent(any()));

        // Upload NOT marked published on failure.
        verifyNever(
          () => mockUploadManager.updateUploadStatus(
            any(),
            UploadStatus.published,
            nostrEventId: any(named: 'nostrEventId'),
          ),
        );
        verifyNever(() => mockVideoEventService.addVideoEvent(any()));
      },
    );

    test(
      'permanent rejection surfaces non-retryable feedback with reason',
      () async {
        final signedEvent = createSignedEvent();
        stubSigning(signedEvent);
        stubPublishOutcome(
          PublishOutcome(
            eventId: signedEvent.id,
            acceptedBy: const {},
            rejectedBy: const {'wss://a': 'blocked: duplicate'},
            noResponseFrom: const {},
          ),
        );

        final result = await publisher.publishDirectUpload(createUpload());

        expect(result.success, isFalse);
        expect(result.feedback?.retryable, isFalse);
        expect(result.feedback?.messageKey, 'publish_rejected_permanent');
        expect(result.feedback?.firstRejectionReason, 'blocked: duplicate');

        verifyNever(
          () => mockUploadManager.updateUploadStatus(
            any(),
            UploadStatus.published,
            nostrEventId: any(named: 'nostrEventId'),
          ),
        );
      },
    );

    test(
      'resumable signed-event cache is populated on signing '
      '(preserved across retry-logic migration)',
      () async {
        final signedEvent = createSignedEvent();
        stubSigning(signedEvent);
        stubPublishOutcome(
          PublishOutcome(
            eventId: signedEvent.id,
            acceptedBy: const {'wss://a'},
            rejectedBy: const {},
            noResponseFrom: const {},
          ),
        );

        final result = await publisher.publishDirectUpload(createUpload());

        expect(result.success, isTrue);
        // Cache was written with the signed event for resumable publish.
        verify(
          () => mockPersonalEventCache.cacheUserEvent(signedEvent),
        ).called(1);
      },
    );
  });
}
