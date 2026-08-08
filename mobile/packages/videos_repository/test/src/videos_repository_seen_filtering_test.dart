// TDD: client-side seen-video filtering across feeds
// Covers: home (following) demotes, new demotes, classic drops + deep-fetch,
// profile untouched, deep-fetch triggers when filtering removes most of page.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:videos_repository/videos_repository.dart';

class MockNostrClient extends Mock implements NostrClient {}

class MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

class StubRandom implements Random {
  StubRandom({int? offsetPage}) : _offsetPage = offsetPage;
  int? _offsetPage;
  final Random _inner = Random(0);
  @override
  int nextInt(int max) {
    if (_offsetPage != null) {
      final v = _offsetPage!;
      _offsetPage = null;
      return v % max;
    }
    return _inner.nextInt(max);
  }

  @override
  bool nextBool() => _inner.nextBool();
  @override
  double nextDouble() => _inner.nextDouble();
}

VideoStats _stats(
  String id, {
  String? pubkey,
  int? createdAt,
  String? platform,
}) => VideoStats(
  rawTags: platform != null ? {'platform': platform} : const {},
  id: id,
  pubkey: pubkey ?? 'pubkey-$id',
  createdAt: DateTime.fromMillisecondsSinceEpoch(
    (createdAt ?? 1704067200) * 1000,
  ),
  kind: EventKind.videoVertical,
  dTag: 'dtag-$id',
  title: 'Test',
  thumbnail: 'https://example.com/thumb.jpg',
  videoUrl: 'https://example.com/$id.mp4',
  reactions: 0,
  comments: 0,
  reposts: 0,
  engagementScore: 0,
);

Event _event(
  String id, {
  String pubkey = 'author',
  int createdAt = 1704067200,
}) {
  return Event.fromJson({
    'id': id,
    'pubkey': pubkey,
    'created_at': createdAt,
    'kind': EventKind.videoVertical,
    'tags': [
      ['url', 'https://example.com/$id.mp4'],
      ['d', 'd-$id'],
    ],
    'content': '',
    'sig': '',
  });
}

void main() {
  late MockNostrClient mockNostr;
  late MockFunnelcakeApiClient mockFunnelcake;

  setUp(() {
    mockNostr = MockNostrClient();
    mockFunnelcake = MockFunnelcakeApiClient();
    when(() => mockFunnelcake.isAvailable).thenReturn(true);
    when(() => mockNostr.publicKey).thenReturn('');
  });

  setUpAll(() {
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(PopularVideosVariant.classic);
  });

  group('Seen filtering per surface', () {
    test('getHomeFeedVideos demotes recently seen (following)', () async {
      const seenId = 'seen-home';
      const unseenId = 'unseen-home';
      when(
        () => mockFunnelcake.getHomeFeed(
          pubkey: any(named: 'pubkey'),
          limit: any(named: 'limit'),
          before: any(named: 'before'),
        ),
      ).thenAnswer(
        (_) async => HomeFeedResponse(
          videos: [_stats(seenId), _stats(unseenId)],
          rawBody: '{}',
        ),
      );

      final repo = VideosRepository(
        nostrClient: mockNostr,
        funnelcakeApiClient: mockFunnelcake,
        seenVideoLookup: SeenVideoLookup(
          wasSeenRecently: (id, {within = const Duration(hours: 24)}) =>
              id == seenId,
        ),
      );

      final result = await repo.getHomeFeedVideos(
        authors: ['a'],
        userPubkey: 'u',
      );
      expect(result.videos.map((v) => v.id).toList(), [unseenId, seenId]);
    });

    test('getNewVideos demotes recently seen', () async {
      final seen = _stats('seen-new');
      final unseen = _stats('unseen-new');
      when(
        () => mockFunnelcake.getRecentVideos(
          limit: any(named: 'limit'),
          before: any(named: 'before'),
        ),
      ).thenAnswer((_) async => [seen, unseen]);
      when(
        () => mockFunnelcake.getBulkVideoStats(any()),
      ).thenAnswer((_) async => const BulkVideoStatsResponse(stats: {}));

      final repo = VideosRepository(
        nostrClient: mockNostr,
        funnelcakeApiClient: mockFunnelcake,
        seenVideoLookup: SeenVideoLookup(
          wasSeenRecently: (id, {within = const Duration(hours: 24)}) =>
              id == 'seen-new',
        ),
      );

      final videos = await repo.getNewVideos();
      expect(videos.map((v) => v.id).toList(), ['unseen-new', 'seen-new']);
    });

    test(
      'getClassicVideos drops recently seen (inventory unlimited)',
      () async {
        final seen = _stats('seen-classic', platform: 'vine');
        final unseen = _stats('unseen-classic', platform: 'vine');
        when(
          () => mockFunnelcake.getClassicVines(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async => [seen, unseen]);
        when(
          () => mockFunnelcake.getBulkVideoStats(any()),
        ).thenAnswer((_) async => const BulkVideoStatsResponse(stats: {}));

        final repo = VideosRepository(
          nostrClient: mockNostr,
          funnelcakeApiClient: mockFunnelcake,
          seenVideoLookup: SeenVideoLookup(
            wasSeenRecently: (id, {within = const Duration(hours: 24)}) =>
                id == 'seen-classic',
          ),
          random: StubRandom(offsetPage: 0),
        );

        final result = await repo.getClassicVideos(limit: 2);
        expect(result.videos.any((v) => v.id == 'seen-classic'), isFalse);
        expect(result.videos.any((v) => v.id == 'unseen-classic'), isTrue);
      },
    );

    test('getProfileVideos is untouched even if seen', () async {
      final seen = _event(
        'seen-profile',
      );
      final unseen = _event(
        'unseen-profile',
        createdAt: 1704067100,
      );
      when(
        () => mockNostr.queryEvents(any()),
      ).thenAnswer((_) async => [seen, unseen]);

      final repo = VideosRepository(
        nostrClient: mockNostr,
        funnelcakeApiClient: mockFunnelcake,
        seenVideoLookup: SeenVideoLookup(
          wasSeenRecently: (_, {within = const Duration(hours: 24)}) => true,
        ),
      );

      final videos = await repo.getProfileVideos(authorPubkey: 'author');
      expect(
        videos.map((v) => v.id),
        containsAll(['seen-profile', 'unseen-profile']),
      );
      expect(videos.length, 2);
    });

    test('without SeenVideoLookup, no filtering occurs', () async {
      final v1 = _stats('v1');
      final v2 = _stats('v2');
      when(
        () => mockFunnelcake.getHomeFeed(
          pubkey: any(named: 'pubkey'),
          limit: any(named: 'limit'),
          before: any(named: 'before'),
        ),
      ).thenAnswer(
        (_) async => HomeFeedResponse(videos: [v1, v2], rawBody: '{}'),
      );

      final repo = VideosRepository(
        nostrClient: mockNostr,
        funnelcakeApiClient: mockFunnelcake,
      );
      final result = await repo.getHomeFeedVideos(
        authors: ['a'],
        userPubkey: 'u',
      );
      expect(result.videos.map((v) => v.id).toList(), ['v1', 'v2']);
    });

    test(
      'classic deep-fetch triggers when filtering removes most of page',
      () async {
        final seenPage = List.generate(
          5,
          (i) => _stats('seen-$i', platform: 'vine'),
        );
        final freshPage = [
          _stats('fresh-0', platform: 'vine'),
          _stats('fresh-1', platform: 'vine'),
        ];
        var call = 0;
        when(
          () => mockFunnelcake.getClassicVines(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async {
          call++;
          if (call == 1) return seenPage;
          if (call == 2) return freshPage;
          return [];
        });
        when(
          () => mockFunnelcake.getBulkVideoStats(any()),
        ).thenAnswer((_) async => const BulkVideoStatsResponse(stats: {}));

        final repo = VideosRepository(
          nostrClient: mockNostr,
          funnelcakeApiClient: mockFunnelcake,
          seenVideoLookup: SeenVideoLookup(
            wasSeenRecently: (id, {within = const Duration(hours: 24)}) =>
                id.startsWith('seen-'),
          ),
          random: StubRandom(offsetPage: 0),
        );

        final result = await repo.getClassicVideos(limit: 2);
        expect(result.videos.any((v) => v.id.startsWith('seen-')), isFalse);
        expect(result.videos.any((v) => v.id.startsWith('fresh-')), isTrue);
        expect(call, greaterThan(1));
      },
    );

    test('classic returns a cursor after eight all-seen pages', () async {
      when(
        () => mockFunnelcake.getClassicVines(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((invocation) async {
        final offset = invocation.namedArguments[#offset] as int;
        return [
          _stats('seen-$offset-a', platform: 'vine'),
          _stats('seen-$offset-b', platform: 'vine'),
        ];
      });
      when(
        () => mockFunnelcake.getBulkVideoStats(any()),
      ).thenAnswer((_) async => const BulkVideoStatsResponse(stats: {}));

      final repo = VideosRepository(
        nostrClient: mockNostr,
        funnelcakeApiClient: mockFunnelcake,
        seenVideoLookup: SeenVideoLookup(
          wasSeenRecently: (_, {within = const Duration(hours: 24)}) => true,
        ),
        random: StubRandom(offsetPage: 0),
      );

      final result = await repo.getClassicVideos(limit: 2);

      expect(result.videos, isEmpty);
      expect(result.paginationCursor, 'classic-offset:16');
      expect(result.hasMore, isTrue);
      verify(
        () => mockFunnelcake.getClassicVines(
          limit: 2,
          offset: any(named: 'offset'),
        ),
      ).called(8);
    });

    test('classic cache drops videos watched after it was populated', () async {
      final seenIds = <String>{};
      when(
        () => mockFunnelcake.getClassicVines(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer(
        (_) async => [
          _stats('cached-seen', platform: 'vine'),
          _stats('cached-fresh', platform: 'vine'),
        ],
      );
      when(
        () => mockFunnelcake.getBulkVideoStats(any()),
      ).thenAnswer((_) async => const BulkVideoStatsResponse(stats: {}));

      final repo = VideosRepository(
        nostrClient: mockNostr,
        funnelcakeApiClient: mockFunnelcake,
        inMemoryFeedCache: InMemoryFeedCache(),
        seenVideoLookup: SeenVideoLookup(
          wasSeenRecently: (id, {within = const Duration(hours: 24)}) =>
              seenIds.contains(id),
        ),
        random: StubRandom(offsetPage: 0),
      );

      final initial = await repo.getClassicVideos(limit: 2);
      seenIds.add('cached-seen');
      final cached = await repo.getClassicVideos(limit: 2);

      expect(initial.videos, hasLength(2));
      expect(cached.videos.map((video) => video.id), ['cached-fresh']);
      verify(
        () => mockFunnelcake.getClassicVines(
          limit: 2,
          offset: any(named: 'offset'),
        ),
      ).called(1);
    });

    test(
      'classic cache stays non-empty when every cached video was seen',
      () async {
        var allSeen = false;
        when(
          () => mockFunnelcake.getClassicVines(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer(
          (_) async => [
            _stats('cached-a', platform: 'vine'),
            _stats('cached-b', platform: 'vine'),
          ],
        );
        when(
          () => mockFunnelcake.getBulkVideoStats(any()),
        ).thenAnswer((_) async => const BulkVideoStatsResponse(stats: {}));

        final repo = VideosRepository(
          nostrClient: mockNostr,
          funnelcakeApiClient: mockFunnelcake,
          inMemoryFeedCache: InMemoryFeedCache(),
          seenVideoLookup: SeenVideoLookup(
            wasSeenRecently: (_, {within = const Duration(hours: 24)}) =>
                allSeen,
          ),
          random: StubRandom(offsetPage: 0),
        );

        final initial = await repo.getClassicVideos(limit: 2);
        allSeen = true;
        final cached = await repo.getClassicVideos(limit: 2);

        expect(
          cached.videos.map((video) => video.id),
          unorderedEquals(initial.videos.map((video) => video.id)),
        );
        verify(
          () => mockFunnelcake.getClassicVines(
            limit: 2,
            offset: any(named: 'offset'),
          ),
        ).called(1);
      },
    );

    test('forYou deep-fetch via getRecommendedVideos', () async {
      final seen = _stats('seen-foyou');
      final fresh = _stats('fresh-foyou');
      when(
        () => mockFunnelcake.getRecommendations(
          pubkey: any(named: 'pubkey'),
          limit: any(named: 'limit'),
          seed: any(named: 'seed'),
          preferredLanguages: any(named: 'preferredLanguages'),
          viewerCountry: any(named: 'viewerCountry'),
        ),
      ).thenAnswer(
        (_) async => RecommendationsResponse(
          videos: [seen],
          source: 'personalized',
          hasMore: true,
          nextCursor: 'c1',
        ),
      );
      when(
        () => mockFunnelcake.getRecommendations(
          pubkey: any(named: 'pubkey'),
          limit: any(named: 'limit'),
          cursor: 'c1',
          seed: any(named: 'seed'),
          preferredLanguages: any(named: 'preferredLanguages'),
          viewerCountry: any(named: 'viewerCountry'),
        ),
      ).thenAnswer(
        (_) async => RecommendationsResponse(
          videos: [fresh],
          source: 'personalized',
        ),
      );

      final repo = VideosRepository(
        nostrClient: mockNostr,
        funnelcakeApiClient: mockFunnelcake,
        seenVideoLookup: SeenVideoLookup(
          wasSeenRecently: (id, {within = const Duration(hours: 24)}) =>
              id == 'seen-foyou',
        ),
      );

      final result = await repo.getRecommendedVideos(
        userPubkey: 'u',
        limit: 10,
      );
      expect(result.videos.map((v) => v.id), contains('fresh-foyou'));
    });
  });

  group('filterOutRecentlySeenVideos helper', () {
    test('drops recently seen, keeps unseen', () {
      final vSeen = VideoEvent(
        id: 'seen',
        pubkey: 'p',
        createdAt: 1,
        content: '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
        videoUrl: 'https://x/1.mp4',
      );
      final vUnseen = VideoEvent(
        id: 'unseen',
        pubkey: 'p',
        createdAt: 1,
        content: '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
        videoUrl: 'https://x/2.mp4',
      );
      final filtered = filterOutRecentlySeenVideos(
        [vSeen, vUnseen],
        seenVideoLookup: SeenVideoLookup(
          wasSeenRecently: (id, {within = const Duration(hours: 24)}) =>
              id == 'seen',
        ),
      );
      expect(filtered.map((v) => v.id), ['unseen']);
    });

    test('returns original if would empty', () {
      final v1 = VideoEvent(
        id: 'a',
        pubkey: 'p',
        createdAt: 1,
        content: '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
        videoUrl: 'https://x/1.mp4',
      );
      final filtered = filterOutRecentlySeenVideos(
        [v1],
        seenVideoLookup: SeenVideoLookup(
          wasSeenRecently: (_, {within = const Duration(hours: 24)}) => true,
        ),
      );
      expect(filtered.map((v) => v.id), ['a']);
    });

    test('prioritize keeps all but reorders', () {
      final vSeen = VideoEvent(
        id: 'seen',
        pubkey: 'p',
        createdAt: 1,
        content: '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
        videoUrl: 'https://x/1.mp4',
      );
      final vUnseen = VideoEvent(
        id: 'unseen',
        pubkey: 'p',
        createdAt: 1,
        content: '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
        videoUrl: 'https://x/2.mp4',
      );
      final ordered = prioritizeNotRecentlySeenVideos(
        [vSeen, vUnseen],
        seenVideoLookup: SeenVideoLookup(
          wasSeenRecently: (id, {within = const Duration(hours: 24)}) =>
              id == 'seen',
        ),
      );
      expect(ordered.map((v) => v.id).toList(), ['unseen', 'seen']);
    });
  });
}
