// ABOUTME: Tests for CurationService.createCurationSet() method
// ABOUTME: Validates creation and publishing of NIP-51 video curation sets to Nostr

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curation_service.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:likes_repository/likes_repository.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockLikesRepository extends Mock implements LikesRepository {}

class _MockAuthService extends Mock implements AuthService {}

const _testPubkey =
    'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';

void main() {
  group('CurationService.createCurationSet()', () {
    late _MockNostrClient mockNostrService;
    late _MockVideoEventService mockVideoEventService;
    late _MockLikesRepository mockLikesRepository;
    late _MockAuthService mockAuthService;
    late CurationService curationService;

    setUpAll(() {
      registerFallbackValue(Event(_testPubkey, 30005, <List<String>>[], ''));
      registerFallbackValue(<Filter>[]);
    });

    setUp(() {
      mockNostrService = _MockNostrClient();
      mockVideoEventService = _MockVideoEventService();
      mockLikesRepository = _MockLikesRepository();
      mockAuthService = _MockAuthService();

      // Setup default mock behaviors for constructor initialization
      when(() => mockVideoEventService.discoveryVideos).thenReturn([]);
      when(
        () => mockLikesRepository.getLikeCounts(any()),
      ).thenAnswer((_) async => {});
      when(
        () => mockNostrService.subscribe(any()),
      ).thenAnswer((_) => const Stream<Event>.empty());
      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => null);

      curationService = CurationService(
        nostrService: mockNostrService,
        videoEventService: mockVideoEventService,
        likesRepository: mockLikesRepository,
        authService: mockAuthService,
      );
    });

    test(
      'returns true when event is signed and published successfully',
      () async {
        final signedEvent = Event(_testPubkey, 30005, <List<String>>[], 'test');
        signedEvent.id = 'signed_event_id';

        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => signedEvent);
        when(
          () => mockNostrService.publishEvent(any()),
        ).thenAnswer((_) async => signedEvent);
        when(
          () => mockNostrService.connectedRelays,
        ).thenReturn(['wss://relay']);

        final result = await curationService.createCurationSet(
          id: 'test_list',
          title: 'Test Curation List',
          videoIds: ['video1', 'video2', 'video3'],
          description: 'A test curation set',
          imageUrl: 'https://example.com/image.jpg',
        );

        expect(result, isTrue);
        verify(() => mockNostrService.publishEvent(any())).called(1);
      },
    );

    test('calls createAndSignEvent with kind 30005', () async {
      final signedEvent = Event(_testPubkey, 30005, <List<String>>[], 'test');
      signedEvent.id = 'event_id';

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => signedEvent);
      when(
        () => mockNostrService.publishEvent(any()),
      ).thenAnswer((_) async => signedEvent);
      when(() => mockNostrService.connectedRelays).thenReturn([]);

      await curationService.createCurationSet(
        id: 'test',
        title: 'Test',
        videoIds: ['video1'],
      );

      final captured = verify(
        () => mockAuthService.createAndSignEvent(
          kind: captureAny(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).captured;

      expect(captured.single, 30005);
    });

    test('creates event with correct tags', () async {
      final signedEvent = Event(_testPubkey, 30005, <List<String>>[], 'test');
      signedEvent.id = 'event_id';

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => signedEvent);
      when(
        () => mockNostrService.publishEvent(any()),
      ).thenAnswer((_) async => signedEvent);
      when(() => mockNostrService.connectedRelays).thenReturn([]);

      await curationService.createCurationSet(
        id: 'my_list',
        title: 'My List',
        videoIds: ['vid1', 'vid2'],
        description: 'Test description',
        imageUrl: 'https://example.com/img.jpg',
      );

      final captured = verify(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: captureAny(named: 'tags'),
        ),
      ).captured;

      final tags = captured.single as List<List<String>>;

      // Verify d tag (identifier)
      final dTag = tags.firstWhere((tag) => tag[0] == 'd');
      expect(dTag[1], 'my_list');

      // Verify title tag
      final titleTag = tags.firstWhere((tag) => tag[0] == 'title');
      expect(titleTag[1], 'My List');

      // Verify description tag
      final descTag = tags.firstWhere((tag) => tag[0] == 'description');
      expect(descTag[1], 'Test description');

      // Verify image tag
      final imageTag = tags.firstWhere((tag) => tag[0] == 'image');
      expect(imageTag[1], 'https://example.com/img.jpg');

      // Verify client attribution tag
      final clientTag = tags.firstWhere((tag) => tag[0] == 'client');
      expect(clientTag[1], 'diVine');

      // Verify video references as 'e' tags
      final eTags = tags.where((tag) => tag[0] == 'e').toList();
      expect(eTags, hasLength(2));
      expect(eTags[0][1], 'vid1');
      expect(eTags[1][1], 'vid2');
    });

    test('returns false when broadcast fails', () async {
      final signedEvent = Event(_testPubkey, 30005, <List<String>>[], 'test');

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => signedEvent);
      when(
        () => mockNostrService.publishEvent(any()),
      ).thenAnswer((_) async => null);

      final result = await curationService.createCurationSet(
        id: 'test_list',
        title: 'Test List',
        videoIds: ['video1'],
      );

      expect(result, isFalse);
    });

    test('returns false when event signing fails', () async {
      // createAndSignEvent returns null (signing failure)
      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => null);

      final result = await curationService.createCurationSet(
        id: 'test_list',
        title: 'Test List',
        videoIds: ['video1'],
      );

      expect(result, isFalse);
      verifyNever(() => mockNostrService.publishEvent(any()));
    });

    test('returns false when publish throws exception', () async {
      final signedEvent = Event(_testPubkey, 30005, <List<String>>[], 'test');

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => signedEvent);
      when(
        () => mockNostrService.publishEvent(any()),
      ).thenThrow(Exception('Network error'));

      final result = await curationService.createCurationSet(
        id: 'error_list',
        title: 'Error Test',
        videoIds: ['video1'],
      );

      expect(result, isFalse);
    });

    test('creates curation set with empty video list', () async {
      final signedEvent = Event(_testPubkey, 30005, <List<String>>[], 'test');
      signedEvent.id = 'event_id';

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => signedEvent);
      when(
        () => mockNostrService.publishEvent(any()),
      ).thenAnswer((_) async => signedEvent);
      when(() => mockNostrService.connectedRelays).thenReturn([]);

      final result = await curationService.createCurationSet(
        id: 'empty_list',
        title: 'Empty List',
        videoIds: [],
      );

      expect(result, isTrue);

      // Verify no 'e' tags were added
      final captured = verify(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: captureAny(named: 'tags'),
        ),
      ).captured;

      final tags = captured.single as List<List<String>>;
      final eTags = tags.where((tag) => tag[0] == 'e').toList();
      expect(eTags, isEmpty);
    });

    test('creates curation set with minimal parameters', () async {
      final signedEvent = Event(_testPubkey, 30005, <List<String>>[], 'test');
      signedEvent.id = 'event_id';

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => signedEvent);
      when(
        () => mockNostrService.publishEvent(any()),
      ).thenAnswer((_) async => signedEvent);
      when(() => mockNostrService.connectedRelays).thenReturn([]);

      final result = await curationService.createCurationSet(
        id: 'minimal',
        title: 'Minimal',
        videoIds: ['video1'],
      );

      expect(result, isTrue);

      // Verify no description or image tags
      final captured = verify(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: captureAny(named: 'tags'),
        ),
      ).captured;

      final tags = captured.single as List<List<String>>;
      final descTags = tags.where((tag) => tag[0] == 'description');
      final imageTags = tags.where((tag) => tag[0] == 'image');
      expect(descTags, isEmpty);
      expect(imageTags, isEmpty);
    });

    test('updates publish status on successful publish', () async {
      final signedEvent = Event(_testPubkey, 30005, <List<String>>[], 'test');
      signedEvent.id = 'published_event_id';

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => signedEvent);
      when(
        () => mockNostrService.publishEvent(any()),
      ).thenAnswer((_) async => signedEvent);
      when(() => mockNostrService.connectedRelays).thenReturn(['wss://relay']);

      await curationService.createCurationSet(
        id: 'status_test',
        title: 'Status Test',
        videoIds: ['video1'],
      );

      final status = curationService.getCurationPublishStatus('status_test');
      expect(status.isPublished, isTrue);
      expect(status.isPublishing, isFalse);
      expect(status.publishedEventId, 'published_event_id');
    });

    test('updates publish status on failed publish', () async {
      final signedEvent = Event(_testPubkey, 30005, <List<String>>[], 'test');

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => signedEvent);
      when(
        () => mockNostrService.publishEvent(any()),
      ).thenAnswer((_) async => null);

      await curationService.createCurationSet(
        id: 'fail_status',
        title: 'Fail Status Test',
        videoIds: ['video1'],
      );

      final status = curationService.getCurationPublishStatus('fail_status');
      expect(status.isPublished, isFalse);
      expect(status.isPublishing, isFalse);
      expect(status.failedAttempts, 1);
    });

    test('uses content from description or title', () async {
      final signedEvent = Event(_testPubkey, 30005, <List<String>>[], 'test');
      signedEvent.id = 'event_id';

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => signedEvent);
      when(
        () => mockNostrService.publishEvent(any()),
      ).thenAnswer((_) async => signedEvent);
      when(() => mockNostrService.connectedRelays).thenReturn([]);

      // With description
      await curationService.createCurationSet(
        id: 'with_desc',
        title: 'Title',
        videoIds: ['video1'],
        description: 'My description',
      );

      final capturedWithDesc = verify(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: captureAny(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).captured;

      expect(capturedWithDesc.single, 'My description');

      // Without description - uses title
      reset(mockAuthService);
      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => signedEvent);

      await curationService.createCurationSet(
        id: 'no_desc',
        title: 'Just Title',
        videoIds: ['video1'],
      );

      final capturedNoDesc = verify(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: captureAny(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).captured;

      expect(capturedNoDesc.single, 'Just Title');
    });
  });
}
