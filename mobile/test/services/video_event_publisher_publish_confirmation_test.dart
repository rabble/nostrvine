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
  late _MockUploadManager mockUploadManager;
  late _MockNostrClient mockNostrClient;
  late _MockAuthService mockAuthService;
  late _MockPersonalEventCacheService mockPersonalEventCache;
  late _MockVideoEventService mockVideoEventService;
  late VideoEventPublisher publisher;

  const testPubkey =
      '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd';

  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(_FakeVideoEvent());
    registerFallbackValue(UploadStatus.pending);
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

  void stubPublish(Event event) {
    when(
      () => mockNostrClient.publishEvent(any()),
    ).thenAnswer((_) async => event);
  }

  group('VideoEventPublisher direct publish', () {
    test('succeeds when relay accepts the event', () async {
      final signedEvent = createSignedEvent();
      stubSigning(signedEvent);
      stubPublish(signedEvent);

      final result = await publisher.publishDirectUpload(createUpload());

      expect(result, isTrue);
      verify(
        () => mockUploadManager.updateUploadStatus(
          'test-upload-id',
          UploadStatus.published,
          nostrEventId: signedEvent.id,
        ),
      ).called(1);
      verify(() => mockVideoEventService.addVideoEvent(any())).called(1);
    });

    test(
      'returns false when relay rejects the event on all attempts',
      () async {
        final signedEvent = createSignedEvent();
        stubSigning(signedEvent);
        // Relay rejects the event (publishEvent returns null).
        when(
          () => mockNostrClient.publishEvent(any()),
        ).thenAnswer((_) async => null);

        final result = await publisher.publishDirectUpload(createUpload());

        expect(result, isFalse);
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

    test('reuses a cached signed event when retrying publish', () async {
      final signedEvent = createSignedEvent();
      final retryUpload = createUpload().copyWith(nostrEventId: signedEvent.id);

      when(
        () => mockPersonalEventCache.getEventById(signedEvent.id),
      ).thenReturn(signedEvent);
      stubPublish(signedEvent);

      final result = await publisher.publishDirectUpload(retryUpload);

      expect(result, isTrue);
      verifyNever(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      );
      verify(() => mockNostrClient.publishEvent(signedEvent)).called(1);
    });
  });

  group('VideoEventPublisher.currentOuterPublishTimeout wiring', () {
    // Pins the production wiring between [outerPublishTimeoutFor] and
    // the actual `Future.timeout` inside _publishEventToNostr. The math
    // is covered exhaustively in video_event_publisher_test.dart; this
    // group only verifies the call site reads from the helper rather
    // than re-introducing a hard-coded literal.

    test(
      'reflects outerPublishTimeoutFor for the current configuredRelayCount',
      () {
        when(() => mockNostrClient.configuredRelayCount).thenReturn(6);
        expect(
          publisher.currentOuterPublishTimeout,
          equals(outerPublishTimeoutFor(6)),
        );
      },
    );

    test('updates live as configuredRelayCount changes', () {
      when(() => mockNostrClient.configuredRelayCount).thenReturn(0);
      expect(
        publisher.currentOuterPublishTimeout,
        equals(outerPublishTimeoutFor(0)),
      );

      when(() => mockNostrClient.configuredRelayCount).thenReturn(50);
      expect(
        publisher.currentOuterPublishTimeout,
        equals(outerPublishTimeoutFor(50)),
      );
    });

    test(
      'never collapses to a single hard-coded literal across relay counts',
      () {
        // Regression guard against reverting the call site to e.g.
        // `Duration(seconds: 30)`. With three different stubbed counts
        // straddling the floor / mid-range / ceiling, the getter must
        // produce three distinct values.
        when(() => mockNostrClient.configuredRelayCount).thenReturn(0);
        final atFloor = publisher.currentOuterPublishTimeout;

        when(() => mockNostrClient.configuredRelayCount).thenReturn(6);
        final atDefault = publisher.currentOuterPublishTimeout;

        when(() => mockNostrClient.configuredRelayCount).thenReturn(50);
        final atCeiling = publisher.currentOuterPublishTimeout;

        expect(
          {atFloor, atDefault, atCeiling},
          hasLength(3),
          reason:
              'getter must vary with configuredRelayCount; '
              'a single literal would collapse all three to one value',
        );
      },
    );
  });
}
