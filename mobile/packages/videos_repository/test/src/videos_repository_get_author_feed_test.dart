// ABOUTME: Tests for VideosRepository.getAuthorFeed — the composed author/
// ABOUTME: profile feed (REST envelope, collaborator guard, relay-seed merge,
// ABOUTME: in-memory cache, REST-unavailable + FunnelcakeException fallback).

import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

const _author = 'author-pubkey';

VideoStats _stats({
  required String id,
  String pubkey = _author,
  String dTag = 'd',
  String videoUrl = 'https://example.com/v.mp4',
  Map<String, String> rawTags = const {},
}) {
  return VideoStats(
    id: id,
    pubkey: pubkey,
    createdAt: DateTime.fromMillisecondsSinceEpoch(1704067200 * 1000),
    kind: EventKind.videoVertical,
    dTag: dTag,
    title: 'Test',
    thumbnail: 'https://example.com/t.jpg',
    videoUrl: videoUrl,
    reactions: 0,
    comments: 0,
    reposts: 0,
    engagementScore: 0,
    rawTags: rawTags,
  );
}

VideoEvent _seed(String id, {String? vineId, int? originalLikes}) => VideoEvent(
  id: id,
  pubkey: _author,
  createdAt: 1704067200,
  content: '',
  timestamp: DateTime.fromMillisecondsSinceEpoch(1704067200 * 1000),
  vineId: vineId,
  originalLikes: originalLikes,
);

void main() {
  setUpAll(() => registerFallbackValue(<String>[]));

  group('VideosRepository.getAuthorFeed', () {
    late _MockNostrClient nostrClient;
    late _MockFunnelcakeApiClient funnelcake;
    late InMemoryFeedCache cache;
    late VideosRepository repository;

    void stubAuthor(VideosByAuthorResponse response) {
      when(
        () => funnelcake.getVideosByAuthor(
          pubkey: any(named: 'pubkey'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          before: any(named: 'before'),
        ),
      ).thenAnswer((_) async => response);
    }

    setUp(() {
      nostrClient = _MockNostrClient();
      funnelcake = _MockFunnelcakeApiClient();
      cache = InMemoryFeedCache();
      repository = VideosRepository(
        nostrClient: nostrClient,
        funnelcakeApiClient: funnelcake,
        inMemoryFeedCache: cache,
      );

      when(() => funnelcake.isAvailable).thenReturn(true);
      when(
        () => funnelcake.getBulkVideoStats(any()),
      ).thenAnswer((_) async => const BulkVideoStatsResponse(stats: {}));
      when(
        () => funnelcake.getVideoViews(any()),
      ).thenAnswer((_) async => 0);
    });

    test('surfaces the v2 envelope (totalCount/nextOffset/hasMore)', () async {
      stubAuthor(
        VideosByAuthorResponse(
          videos: [_stats(id: 'a')],
          totalCount: 42,
          nextOffset: 50,
          hasMore: true,
        ),
      );

      final result = await repository.getAuthorFeed(authorPubkey: _author);

      expect(result.videos, hasLength(1));
      expect(result.totalCount, equals(42));
      expect(result.nextOffset, equals(50));
      expect(result.hasMore, isTrue);
    });

    test('hydrates REST videos with bulk stats (existing-wins)', () async {
      when(() => funnelcake.getBulkVideoStats(any())).thenAnswer(
        (_) async => const BulkVideoStatsResponse(
          stats: {
            'a': BulkVideoStatsEntry(
              eventId: 'a',
              reactions: 6,
              comments: 1,
              reposts: 0,
              views: 14,
              loops: 7,
            ),
          },
        ),
      );
      stubAuthor(VideosByAuthorResponse(videos: [_stats(id: 'a')]));

      final result = await repository.getAuthorFeed(authorPubkey: _author);

      final video = result.videos.single;
      expect(video.originalLoops, equals(7));
      expect(video.rawTags['loops'], equals('7'));
      // Bulk-stats supplied the view count, so the per-video views endpoint is
      // skipped (the value is preserved verbatim, not overwritten with 0).
      expect(video.rawTags['views'], equals('14'));
      verifyNever(() => funnelcake.getVideoViews(any()));
    });

    test(
      'treats a fractional view count as present, skipping the views endpoint',
      () async {
        stubAuthor(
          VideosByAuthorResponse(
            videos: [
              _stats(id: 'a', rawTags: {'views': '12.7'}),
            ],
          ),
        );

        final result = await repository.getAuthorFeed(authorPubkey: _author);

        expect(result.videos, hasLength(1));
        expect(result.videos.single.rawTags['views'], equals('12.7'));
        verifyNever(() => funnelcake.getVideoViews(any()));
      },
    );

    test(
      'falls back to a page-size heuristic for nextOffset/hasMore',
      () async {
        stubAuthor(VideosByAuthorResponse(videos: [_stats(id: 'a')]));

        final result = await repository.getAuthorFeed(authorPubkey: _author);

        // Envelope omitted -> nextOffset = offset(0) + restCount(1); hasMore is
        // false because 1 < the 50-row page size.
        expect(result.nextOffset, equals(1));
        expect(result.hasMore, isFalse);
      },
    );

    test('drops backend-leaked p-tagged collaborator videos', () async {
      stubAuthor(
        VideosByAuthorResponse(
          videos: [
            _stats(id: 'mine'),
            _stats(id: 'leaked', pubkey: 'someone-else'),
          ],
        ),
      );

      final result = await repository.getAuthorFeed(authorPubkey: _author);

      expect(result.videos, hasLength(1));
      expect(result.videos.single.id, equals('mine'));
      expect(result.videos.single.pubkey, equals(_author));
    });

    test(
      'merges the relay seed with REST, deduping by addressable id',
      () async {
        // REST `toVideoEvent` derives stableId from the d-tag ('d' here); the
        // relay seed shares that addressable id so the two copies dedup — the
        // same identity the production relay snapshot and REST row collapse on.
        stubAuthor(VideosByAuthorResponse(videos: [_stats(id: 'a')]));

        final result = await repository.getAuthorFeed(
          authorPubkey: _author,
          relaySeed: [_seed('a', vineId: 'd', originalLikes: 9)],
        );

        expect(result.videos, hasLength(1));
        // Max-merge keeps the relay's higher engagement count (#3384).
        expect(result.videos.single.originalLikes, equals(9));
      },
    );

    test(
      'caches the initial page and serves it without a second fetch',
      () async {
        stubAuthor(VideosByAuthorResponse(videos: [_stats(id: 'a')]));

        await repository.getAuthorFeed(authorPubkey: _author);
        final second = await repository.getAuthorFeed(authorPubkey: _author);

        expect(second.videos, hasLength(1));
        verify(
          () => funnelcake.getVideosByAuthor(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            before: any(named: 'before'),
          ),
        ).called(1);
      },
    );

    test('load-more pages (offset != null) bypass the cache', () async {
      stubAuthor(VideosByAuthorResponse(videos: [_stats(id: 'a')]));

      await repository.getAuthorFeed(authorPubkey: _author); // primes cache
      await repository.getAuthorFeed(authorPubkey: _author, offset: 50);

      verify(
        () => funnelcake.getVideosByAuthor(
          pubkey: _author,
          limit: any(named: 'limit'),
          offset: 50,
          before: any(named: 'before'),
        ),
      ).called(1);
    });

    test(
      'returns the relay seed alone when Funnelcake is unavailable',
      () async {
        when(() => funnelcake.isAvailable).thenReturn(false);

        final result = await repository.getAuthorFeed(
          authorPubkey: _author,
          relaySeed: [_seed('a')],
        );

        expect(result.videos.map((v) => v.id).toList(), equals(['a']));
        verifyNever(
          () => funnelcake.getVideosByAuthor(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            before: any(named: 'before'),
          ),
        );
      },
    );

    test('falls back to the relay seed on FunnelcakeException', () async {
      when(
        () => funnelcake.getVideosByAuthor(
          pubkey: any(named: 'pubkey'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          before: any(named: 'before'),
        ),
      ).thenThrow(const FunnelcakeException('boom'));

      final result = await repository.getAuthorFeed(
        authorPubkey: _author,
        relaySeed: [_seed('a')],
      );

      expect(result.videos.map((v) => v.id).toList(), equals(['a']));
    });
  });
}
