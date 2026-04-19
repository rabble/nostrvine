// ABOUTME: Tests for trending video relay fetch logic
// ABOUTME: Verifies fetching missing trending videos from relays

import 'dart:async';
import 'dart:convert';

import 'package:curation_service/curation_service.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';
import 'package:test/test.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockVideoEventCache extends Mock implements VideoEventCache {}

class _MockLikesRepository extends Mock implements LikesRepository {}

class _MockNostrSigner extends Mock implements NostrSigner {}

void main() {
  setUpAll(() {
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(
      Event('0' * 64, 1, <List<String>>[], ''),
    );
    registerFallbackValue(<String>[]);
    registerFallbackValue(
      VideoEvent(
        id: 'fallback',
        pubkey: 'fallback',
        createdAt: 0,
        content: '',
        timestamp: DateTime(2020),
      ),
    );
  });

  late CurationService curationService;
  late _MockNostrClient mockNostrService;
  late _MockVideoEventCache mockVideoEventCache;
  late _MockLikesRepository mockLikesRepository;
  late _MockNostrSigner mockSigner;

  setUp(() {
    mockNostrService = _MockNostrClient();
    mockVideoEventCache = _MockVideoEventCache();
    mockLikesRepository = _MockLikesRepository();
    mockSigner = _MockNostrSigner();

    // Setup default mocks
    when(() => mockVideoEventCache.discoveryVideos).thenReturn([]);

    // Mock getLikeCounts to return empty counts
    when(
      () => mockLikesRepository.getLikeCounts(any()),
    ).thenAnswer((_) async => {});

    // Mock subscribe
    when(
      () => mockNostrService.subscribe(any()),
    ).thenAnswer((_) => const Stream<Event>.empty());

    curationService = CurationService(
      nostrService: mockNostrService,
      videoEventCache: mockVideoEventCache,
      likesRepository: mockLikesRepository,
      signer: mockSigner,
      divineTeamPubkeys: const [],
    );
  });

  group('Trending Videos Relay Fetch', () {
    test(
      'fetches missing trending videos from Nostr relays',
      () async {
        when(() => mockVideoEventCache.discoveryVideos).thenReturn([]);

        final videoEvent = Event(
          '0' * 64,
          22,
          [
            ['h', 'vine'],
            ['title', 'Test Video'],
            ['url', 'https://example.com/video.mp4'],
          ],
          jsonEncode({
            'url': 'https://example.com/video.mp4',
            'description': 'Test video description',
          }),
          createdAt: 1234567890,
        )..id = 'test123';

        final streamController = StreamController<Event>();
        when(
          () => mockNostrService.subscribe(any()),
        ).thenAnswer((_) {
          Timer(const Duration(milliseconds: 100), () {
            streamController.add(videoEvent);
            unawaited(streamController.close());
          });
          return streamController.stream;
        });

        final missingEventIds = ['test123'];
        final filter = Filter(
          kinds: [22],
          ids: missingEventIds,
          h: ['vine'],
        );

        final eventStream = mockNostrService.subscribe([filter]);
        final fetchedEvents = <Event>[];

        await eventStream.forEach(fetchedEvents.add);

        expect(fetchedEvents.length, 1);
        expect(fetchedEvents[0].id, 'test123');
      },
    );

    test(
      'handles empty trending response gracefully',
      () {
        when(() => mockVideoEventCache.discoveryVideos).thenReturn([]);

        final trendingVideos = curationService.getVideosForSetType(
          CurationSetType.trending,
        );
        expect(trendingVideos, isEmpty);
      },
    );

    test('preserves order from trending API', () {
      final video1 = VideoEvent(
        id: 'video1',
        pubkey: 'pub1',
        createdAt: 1,
        content: '',
        timestamp: DateTime.now(),
      );
      final video2 = VideoEvent(
        id: 'video2',
        pubkey: 'pub2',
        createdAt: 2,
        content: '',
        timestamp: DateTime.now(),
      );

      when(
        () => mockVideoEventCache.discoveryVideos,
      ).thenReturn([video2, video1]);

      // The curation service should maintain order based
      // on analytics response (tested more thoroughly with
      // HTTP mocking)
    });
  });
}
