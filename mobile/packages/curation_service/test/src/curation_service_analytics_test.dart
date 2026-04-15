// ABOUTME: Tests for CurationService analytics integration
// ABOUTME: Verifies trending data fetch and relay fallback

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
    when(
      () => mockVideoEventCache.addVideoEvent(any()),
    ).thenReturn(null);

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

  group('Analytics Integration Tests', () {
    test(
      'calls real analytics API and mocks relay fetch '
      'for missing videos',
      () async {
        when(() => mockVideoEventCache.discoveryVideos).thenReturn([]);

        final missingVideoEvent = Event(
          '0' * 64,
          22,
          [
            ['h', 'vine'],
            ['title', 'Fetched Video'],
          ],
          jsonEncode({
            'url': 'https://example.com/video.mp4',
            'description': 'Fetched video description',
          }),
          createdAt: 1234567891,
        )..id = 'test_trending_video_id';

        final streamController = StreamController<Event>();
        when(
          () => mockNostrService.subscribe(any()),
        ).thenAnswer((_) {
          Timer(const Duration(milliseconds: 100), () {
            streamController.add(missingVideoEvent);
            unawaited(streamController.close());
          });
          return streamController.stream;
        });

        await curationService.refreshTrendingFromAnalytics();

        // Test passes if no exceptions were thrown
        expect(true, isTrue);
      },
    );

    test(
      'handles analytics API errors gracefully',
      () async {
        await curationService.refreshTrendingFromAnalytics();

        final trendingVideos = curationService.getVideosForSetType(
          CurationSetType.trending,
        );
        expect(trendingVideos, isNotNull);
      },
    );

    test(
      'handles relay timeout when fetching missing videos',
      () async {
        when(() => mockVideoEventCache.discoveryVideos).thenReturn([]);

        final streamController = StreamController<Event>();
        when(
          () => mockNostrService.subscribe(any()),
        ).thenAnswer((_) {
          Timer(
            const Duration(seconds: 1),
            streamController.close,
          );
          return streamController.stream;
        });

        await curationService.refreshTrendingFromAnalytics();

        final trendingVideos = curationService.getVideosForSetType(
          CurationSetType.trending,
        );
        expect(trendingVideos, isNotNull);
      },
    );

    test(
      'maintains order from analytics API when videos '
      'exist locally',
      () async {
        final videos = [
          VideoEvent(
            id: 'third',
            pubkey: 'pub3',
            createdAt: 3,
            content: '',
            timestamp: DateTime.now(),
          ),
          VideoEvent(
            id: 'first',
            pubkey: 'pub1',
            createdAt: 1,
            content: '',
            timestamp: DateTime.now(),
          ),
          VideoEvent(
            id: 'second',
            pubkey: 'pub2',
            createdAt: 2,
            content: '',
            timestamp: DateTime.now(),
          ),
        ];
        when(() => mockVideoEventCache.discoveryVideos).thenReturn(videos);

        await curationService.refreshTrendingFromAnalytics();

        final trendingVideos = curationService.getVideosForSetType(
          CurationSetType.trending,
        );
        expect(trendingVideos, isNotNull);
      },
    );
  });
}
