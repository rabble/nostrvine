import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:videos_repository/videos_repository.dart';

class MockNostrClient extends Mock implements NostrClient {}

/// Test helper that tracks content filter calls.
class TestContentFilter {
  TestContentFilter({this.blockedPubkeys = const {}});

  final Set<String> blockedPubkeys;
  final List<String> calls = [];

  bool call(String pubkey) {
    calls.add(pubkey);
    return blockedPubkeys.contains(pubkey);
  }
}

/// Test helper that tracks video event filter calls.
class TestVideoEventFilter {
  TestVideoEventFilter({this.shouldFilter = false});

  final bool shouldFilter;
  final List<VideoEvent> calls = [];

  bool call(VideoEvent video) {
    calls.add(video);
    return shouldFilter;
  }
}

/// Test helper that filters videos with specific hashtags.
class TestNsfwFilter {
  TestNsfwFilter({this.filterNsfw = true});

  final bool filterNsfw;
  final List<VideoEvent> calls = [];

  bool call(VideoEvent video) {
    calls.add(video);
    if (!filterNsfw) return false;

    // Check for NSFW hashtags
    for (final hashtag in video.hashtags) {
      final lowerHashtag = hashtag.toLowerCase();
      if (lowerHashtag == 'nsfw' || lowerHashtag == 'adult') {
        return true;
      }
    }

    // Check for content-warning tag
    if (video.rawTags.containsKey('content-warning')) {
      return true;
    }

    return false;
  }
}

void main() {
  group('VideosRepository', () {
    late MockNostrClient mockNostrClient;
    late VideosRepository repository;

    setUp(() {
      mockNostrClient = MockNostrClient();
      repository = VideosRepository(nostrClient: mockNostrClient);
    });

    setUpAll(() {
      registerFallbackValue(<Filter>[]);
    });

    test('can be instantiated', () {
      expect(repository, isNotNull);
    });

    group('getNewVideos', () {
      test('returns empty list when no events found', () async {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => <Event>[],
        );

        final result = await repository.getNewVideos();

        expect(result, isEmpty);
        verify(() => mockNostrClient.queryEvents(any())).called(1);
      });

      test('queries with correct filter for video kind', () async {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => <Event>[],
        );

        await repository.getNewVideos(limit: 10);

        final captured = verify(
          () => mockNostrClient.queryEvents(captureAny()),
        ).captured;
        final filters = captured.first as List<Filter>;

        expect(filters, hasLength(1));
        expect(filters.first.kinds, contains(EventKind.videoVertical));
        expect(filters.first.limit, equals(10));
      });

      test('passes until parameter for pagination', () async {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => <Event>[],
        );

        const until = 1704067200; // 2024-01-01 00:00:00 UTC
        await repository.getNewVideos(until: until);

        final captured = verify(
          () => mockNostrClient.queryEvents(captureAny()),
        ).captured;
        final filters = captured.first as List<Filter>;

        expect(filters.first.until, equals(until));
      });

      test('transforms valid events to VideoEvents', () async {
        final event = _createVideoEvent(
          id: 'test-id-123',
          pubkey: 'test-pubkey',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1704067200,
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [event],
        );

        final result = await repository.getNewVideos();

        expect(result, hasLength(1));
        expect(result.first.id, equals('test-id-123'));
        expect(result.first.videoUrl, equals('https://example.com/video.mp4'));
      });

      test('filters out videos without valid URL', () async {
        final validEvent = _createVideoEvent(
          id: 'valid-id',
          pubkey: 'test-pubkey',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1704067200,
        );
        final invalidEvent = _createVideoEvent(
          id: 'invalid-id',
          pubkey: 'test-pubkey',
          videoUrl: null,
          createdAt: 1704067201,
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [validEvent, invalidEvent],
        );

        final result = await repository.getNewVideos();

        expect(result, hasLength(1));
        expect(result.first.id, equals('valid-id'));
      });

      test('sorts videos by creation time (newest first)', () async {
        final olderEvent = _createVideoEvent(
          id: 'older',
          pubkey: 'test-pubkey',
          videoUrl: 'https://example.com/old.mp4',
          createdAt: 1704067200,
        );
        final newerEvent = _createVideoEvent(
          id: 'newer',
          pubkey: 'test-pubkey',
          videoUrl: 'https://example.com/new.mp4',
          createdAt: 1704153600,
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [olderEvent, newerEvent],
        );

        final result = await repository.getNewVideos();

        expect(result, hasLength(2));
        expect(result.first.id, equals('newer'));
        expect(result.last.id, equals('older'));
      });
    });

    group('getHomeFeedVideos', () {
      test('returns empty list when authors is empty', () async {
        final result = await repository.getHomeFeedVideos(authors: []);

        expect(result, isEmpty);
        verifyNever(() => mockNostrClient.queryEvents(any()));
      });

      test('returns empty list when no events found', () async {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => <Event>[],
        );

        final result = await repository.getHomeFeedVideos(
          authors: ['pubkey1', 'pubkey2'],
        );

        expect(result, isEmpty);
        verify(() => mockNostrClient.queryEvents(any())).called(1);
      });

      test('queries with correct filter including authors', () async {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => <Event>[],
        );

        final authors = ['pubkey1', 'pubkey2'];
        await repository.getHomeFeedVideos(authors: authors, limit: 10);

        final captured = verify(
          () => mockNostrClient.queryEvents(captureAny()),
        ).captured;
        final filters = captured.first as List<Filter>;

        expect(filters, hasLength(1));
        expect(filters.first.kinds, contains(EventKind.videoVertical));
        expect(filters.first.authors, equals(authors));
        expect(filters.first.limit, equals(10));
      });

      test('passes until parameter for pagination', () async {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => <Event>[],
        );

        const until = 1704067200;
        await repository.getHomeFeedVideos(
          authors: ['pubkey1'],
          until: until,
        );

        final captured = verify(
          () => mockNostrClient.queryEvents(captureAny()),
        ).captured;
        final filters = captured.first as List<Filter>;

        expect(filters.first.until, equals(until));
      });

      test('transforms and filters events correctly', () async {
        final event = _createVideoEvent(
          id: 'home-video-123',
          pubkey: 'followed-user',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1704067200,
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [event],
        );

        final result = await repository.getHomeFeedVideos(
          authors: ['followed-user'],
        );

        expect(result, hasLength(1));
        expect(result.first.id, equals('home-video-123'));
        expect(result.first.pubkey, equals('followed-user'));
      });

      test('sorts videos by creation time (newest first)', () async {
        final olderEvent = _createVideoEvent(
          id: 'older',
          pubkey: 'user1',
          videoUrl: 'https://example.com/old.mp4',
          createdAt: 1704067200,
        );
        final newerEvent = _createVideoEvent(
          id: 'newer',
          pubkey: 'user2',
          videoUrl: 'https://example.com/new.mp4',
          createdAt: 1704153600,
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [olderEvent, newerEvent],
        );

        final result = await repository.getHomeFeedVideos(
          authors: ['user1', 'user2'],
        );

        expect(result, hasLength(2));
        expect(result.first.id, equals('newer'));
        expect(result.last.id, equals('older'));
      });
    });

    group('getProfileVideos', () {
      test('returns empty list when no events found', () async {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => <Event>[],
        );

        final result = await repository.getProfileVideos(
          authorPubkey: 'test-pubkey',
        );

        expect(result, isEmpty);
        verify(() => mockNostrClient.queryEvents(any())).called(1);
      });

      test('queries with correct filter for single author', () async {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => <Event>[],
        );

        const authorPubkey = 'user-pubkey-123';
        await repository.getProfileVideos(
          authorPubkey: authorPubkey,
          limit: 10,
        );

        final captured = verify(
          () => mockNostrClient.queryEvents(captureAny()),
        ).captured;
        final filters = captured.first as List<Filter>;

        expect(filters, hasLength(1));
        expect(filters.first.kinds, contains(EventKind.videoVertical));
        expect(filters.first.authors, equals([authorPubkey]));
        expect(filters.first.limit, equals(10));
      });

      test('passes until parameter for pagination', () async {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => <Event>[],
        );

        const until = 1704067200;
        await repository.getProfileVideos(
          authorPubkey: 'test-pubkey',
          until: until,
        );

        final captured = verify(
          () => mockNostrClient.queryEvents(captureAny()),
        ).captured;
        final filters = captured.first as List<Filter>;

        expect(filters.first.until, equals(until));
      });

      test('transforms and filters events correctly', () async {
        final event = _createVideoEvent(
          id: 'profile-video-123',
          pubkey: 'user-pubkey',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1704067200,
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [event],
        );

        final result = await repository.getProfileVideos(
          authorPubkey: 'user-pubkey',
        );

        expect(result, hasLength(1));
        expect(result.first.id, equals('profile-video-123'));
        expect(result.first.pubkey, equals('user-pubkey'));
      });

      test('filters out videos without valid URL', () async {
        final validEvent = _createVideoEvent(
          id: 'valid-id',
          pubkey: 'user-pubkey',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1704067200,
        );
        final invalidEvent = _createVideoEvent(
          id: 'invalid-id',
          pubkey: 'user-pubkey',
          videoUrl: null,
          createdAt: 1704067201,
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [validEvent, invalidEvent],
        );

        final result = await repository.getProfileVideos(
          authorPubkey: 'user-pubkey',
        );

        expect(result, hasLength(1));
        expect(result.first.id, equals('valid-id'));
      });

      test('sorts videos by creation time (newest first)', () async {
        final olderEvent = _createVideoEvent(
          id: 'older',
          pubkey: 'user-pubkey',
          videoUrl: 'https://example.com/old.mp4',
          createdAt: 1704067200,
        );
        final newerEvent = _createVideoEvent(
          id: 'newer',
          pubkey: 'user-pubkey',
          videoUrl: 'https://example.com/new.mp4',
          createdAt: 1704153600,
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [olderEvent, newerEvent],
        );

        final result = await repository.getProfileVideos(
          authorPubkey: 'user-pubkey',
        );

        expect(result, hasLength(2));
        expect(result.first.id, equals('newer'));
        expect(result.last.id, equals('older'));
      });

      test('uses default limit of 5 when not specified', () async {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => <Event>[],
        );

        await repository.getProfileVideos(authorPubkey: 'test-pubkey');

        final captured = verify(
          () => mockNostrClient.queryEvents(captureAny()),
        ).captured;
        final filters = captured.first as List<Filter>;

        expect(filters.first.limit, equals(5));
      });
    });

    group('getPopularVideos', () {
      group('NIP-50 server-side sorting', () {
        test('tries NIP-50 query first with sort:hot', () async {
          final event = _createVideoEvent(
            id: 'popular-video',
            pubkey: 'test-pubkey',
            videoUrl: 'https://example.com/video.mp4',
            createdAt: 1704067200,
          );

          when(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => [event]);

          final result = await repository.getPopularVideos();

          final captured = verify(
            () => mockNostrClient.queryEvents(
              captureAny(),
              useCache: captureAny(named: 'useCache'),
            ),
          ).captured;
          final filters = captured[0] as List<Filter>;
          final useCache = captured[1] as bool;

          expect(filters.first.search, equals('sort:hot'));
          expect(
            filters.first.limit,
            equals(5),
          ); // Default limit, not multiplied
          expect(useCache, isFalse);
          expect(result, hasLength(1));
        });

        test('uses exact limit for NIP-50 query (no multiplier)', () async {
          final event = _createVideoEvent(
            id: 'video-1',
            pubkey: 'test-pubkey',
            videoUrl: 'https://example.com/video.mp4',
            createdAt: 1704067200,
          );

          when(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => [event]);

          await repository.getPopularVideos(limit: 10);

          final captured = verify(
            () => mockNostrClient.queryEvents(
              captureAny(),
              useCache: any(named: 'useCache'),
            ),
          ).captured;
          final filters = captured.first as List<Filter>;

          expect(filters.first.limit, equals(10));
        });

        test('passes until parameter to NIP-50 query', () async {
          final event = _createVideoEvent(
            id: 'video-1',
            pubkey: 'test-pubkey',
            videoUrl: 'https://example.com/video.mp4',
            createdAt: 1704067200,
          );

          when(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => [event]);

          const until = 1704067200;
          await repository.getPopularVideos(until: until);

          final captured = verify(
            () => mockNostrClient.queryEvents(
              captureAny(),
              useCache: any(named: 'useCache'),
            ),
          ).captured;
          final filters = captured.first as List<Filter>;

          expect(filters.first.until, equals(until));
        });

        test('returns NIP-50 results without client-side sorting', () async {
          // NIP-50 results come pre-sorted from relay
          final events = [
            _createVideoEvent(
              id: 'relay-sorted-1',
              pubkey: 'test-pubkey',
              videoUrl: 'https://example.com/video1.mp4',
              createdAt: 1704067200,
              loops: 10, // Lower loops but relay says it's #1
            ),
            _createVideoEvent(
              id: 'relay-sorted-2',
              pubkey: 'test-pubkey',
              videoUrl: 'https://example.com/video2.mp4',
              createdAt: 1704067201,
              loops: 1000, // Higher loops but relay says it's #2
            ),
          ];

          when(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => events);

          final result = await repository.getPopularVideos(limit: 2);

          // Should preserve relay order, not re-sort by loops
          expect(result, hasLength(2));
          expect(result.first.id, equals('relay-sorted-1'));
          expect(result.last.id, equals('relay-sorted-2'));

          // Only one query should be made (no fallback)
          verify(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).called(1);
        });
      });

      group('fallback to client-side sorting', () {
        test('falls back when NIP-50 returns empty', () async {
          // First call (NIP-50) returns empty
          // Second call (fallback) returns events
          var callCount = 0;
          when(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async {
            callCount++;
            if (callCount == 1) return <Event>[]; // NIP-50 empty
            return [
              _createVideoEvent(
                id: 'fallback-video',
                pubkey: 'test-pubkey',
                videoUrl: 'https://example.com/video.mp4',
                createdAt: 1704067200,
              ),
            ];
          });

          final result = await repository.getPopularVideos();

          expect(result, hasLength(1));
          expect(result.first.id, equals('fallback-video'));
          verify(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).called(2);
        });

        test('fallback fetches more events than limit for sorting', () async {
          when(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => <Event>[]);

          await repository.getPopularVideos();

          final captured = verify(
            () => mockNostrClient.queryEvents(
              captureAny(),
              useCache: any(named: 'useCache'),
            ),
          ).captured;

          // First call: NIP-50 with exact limit
          final nip50Filters = captured[0] as List<Filter>;
          expect(nip50Filters.first.limit, equals(5));
          expect(nip50Filters.first.search, equals('sort:hot'));

          // Second call: fallback with multiplied limit
          // captured[1] contains filters from second call
          // (only filters are captured)
          final fallbackFilters = captured[1] as List<Filter>;
          expect(fallbackFilters.first.limit, equals(20)); // 5 * 4
          expect(fallbackFilters.first.search, isNull);
        });

        test('fallback respects custom fetch multiplier', () async {
          when(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => <Event>[]);

          await repository.getPopularVideos(fetchMultiplier: 2);

          final captured = verify(
            () => mockNostrClient.queryEvents(
              captureAny(),
              useCache: any(named: 'useCache'),
            ),
          ).captured;

          // Second call: fallback with multiplied limit
          // captured[1] contains filters from second call
          // (only filters are captured)
          final fallbackFilters = captured[1] as List<Filter>;
          expect(fallbackFilters.first.limit, equals(10)); // 5 * 2
        });

        test('fallback sorts by engagement score (highest first)', () async {
          final lowEngagement = _createVideoEvent(
            id: 'low',
            pubkey: 'test-pubkey',
            videoUrl: 'https://example.com/low.mp4',
            createdAt: 1704067200,
            loops: 10,
          );
          final highEngagement = _createVideoEvent(
            id: 'high',
            pubkey: 'test-pubkey',
            videoUrl: 'https://example.com/high.mp4',
            createdAt: 1704067201,
            loops: 1000,
          );

          var callCount = 0;
          when(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async {
            callCount++;
            if (callCount == 1) return <Event>[]; // NIP-50 empty
            return [lowEngagement, highEngagement];
          });

          final result = await repository.getPopularVideos(limit: 2);

          expect(result, hasLength(2));
          expect(result.first.id, equals('high'));
          expect(result.last.id, equals('low'));
        });

        test('fallback returns only requested limit after sorting', () async {
          final events = List.generate(
            10,
            (i) => _createVideoEvent(
              id: 'video-$i',
              pubkey: 'test-pubkey',
              videoUrl: 'https://example.com/video$i.mp4',
              createdAt: 1704067200 + i,
              loops: i * 100,
            ),
          );

          var callCount = 0;
          when(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async {
            callCount++;
            if (callCount == 1) return <Event>[]; // NIP-50 empty
            return events;
          });

          final result = await repository.getPopularVideos(limit: 3);

          expect(result, hasLength(3));
        });
      });

      test(
        'returns empty list when both NIP-50 and fallback return empty',
        () async {
          when(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => <Event>[]);

          final result = await repository.getPopularVideos();

          expect(result, isEmpty);
        },
      );
    });

    group('content filtering', () {
      test('filters out videos from blocked pubkeys', () async {
        const blockedPubkey = 'blocked-user-pubkey';
        const allowedPubkey = 'allowed-user-pubkey';

        final filter = TestContentFilter(
          blockedPubkeys: {blockedPubkey},
        );
        final repositoryWithFilter = VideosRepository(
          nostrClient: mockNostrClient,
          blockFilter: filter.call,
        );

        final blockedEvent = _createVideoEvent(
          id: 'blocked-video',
          pubkey: blockedPubkey,
          videoUrl: 'https://example.com/blocked.mp4',
          createdAt: 1704067200,
        );
        final allowedEvent = _createVideoEvent(
          id: 'allowed-video',
          pubkey: allowedPubkey,
          videoUrl: 'https://example.com/allowed.mp4',
          createdAt: 1704067201,
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [blockedEvent, allowedEvent],
        );

        final result = await repositoryWithFilter.getNewVideos();

        expect(result, hasLength(1));
        expect(result.first.id, equals('allowed-video'));
        expect(result.first.pubkey, equals(allowedPubkey));

        // Verify filter was called for both pubkeys
        expect(filter.calls, contains(blockedPubkey));
        expect(filter.calls, contains(allowedPubkey));
      });

      test('filters blocked pubkeys in home feed', () async {
        const blockedPubkey = 'blocked-followed-user';
        const allowedPubkey = 'allowed-followed-user';

        final filter = TestContentFilter(
          blockedPubkeys: {blockedPubkey},
        );
        final repositoryWithFilter = VideosRepository(
          nostrClient: mockNostrClient,
          blockFilter: filter.call,
        );

        final blockedEvent = _createVideoEvent(
          id: 'blocked-video',
          pubkey: blockedPubkey,
          videoUrl: 'https://example.com/blocked.mp4',
          createdAt: 1704067200,
        );
        final allowedEvent = _createVideoEvent(
          id: 'allowed-video',
          pubkey: allowedPubkey,
          videoUrl: 'https://example.com/allowed.mp4',
          createdAt: 1704067201,
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [blockedEvent, allowedEvent],
        );

        final result = await repositoryWithFilter.getHomeFeedVideos(
          authors: [blockedPubkey, allowedPubkey],
        );

        expect(result, hasLength(1));
        expect(result.first.pubkey, equals(allowedPubkey));
      });

      test('filters blocked pubkeys in popular feed', () async {
        const blockedPubkey = 'blocked-popular-user';
        const allowedPubkey = 'allowed-popular-user';

        final filter = TestContentFilter(
          blockedPubkeys: {blockedPubkey},
        );
        final repositoryWithFilter = VideosRepository(
          nostrClient: mockNostrClient,
          blockFilter: filter.call,
        );

        final blockedEvent = _createVideoEvent(
          id: 'blocked-video',
          pubkey: blockedPubkey,
          videoUrl: 'https://example.com/blocked.mp4',
          createdAt: 1704067200,
          loops: 1000,
        );
        final allowedEvent = _createVideoEvent(
          id: 'allowed-video',
          pubkey: allowedPubkey,
          videoUrl: 'https://example.com/allowed.mp4',
          createdAt: 1704067201,
          loops: 500,
        );

        when(
          () => mockNostrClient.queryEvents(
            any(),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) async => [blockedEvent, allowedEvent]);

        final result = await repositoryWithFilter.getPopularVideos();

        expect(result, hasLength(1));
        expect(result.first.pubkey, equals(allowedPubkey));
      });

      test('works correctly without content filter (null)', () async {
        // Use the default repository without filter
        final event = _createVideoEvent(
          id: 'video-1',
          pubkey: 'any-pubkey',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1704067200,
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [event],
        );

        final result = await repository.getNewVideos();

        expect(result, hasLength(1));
        expect(result.first.id, equals('video-1'));
      });

      test('filters all videos if all pubkeys are blocked', () async {
        final filter = TestContentFilter(
          blockedPubkeys: {'user-1', 'user-2'},
        );
        final repositoryWithFilter = VideosRepository(
          nostrClient: mockNostrClient,
          blockFilter: filter.call,
        );

        final events = [
          _createVideoEvent(
            id: 'video-1',
            pubkey: 'user-1',
            videoUrl: 'https://example.com/video1.mp4',
            createdAt: 1704067200,
          ),
          _createVideoEvent(
            id: 'video-2',
            pubkey: 'user-2',
            videoUrl: 'https://example.com/video2.mp4',
            createdAt: 1704067201,
          ),
        ];

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => events,
        );

        final result = await repositoryWithFilter.getNewVideos();

        expect(result, isEmpty);
      });

      test('checks filter before parsing event to VideoEvent', () async {
        // This test verifies that filtering happens before the potentially
        // expensive VideoEvent.fromNostrEvent() call
        const blockedPubkey = 'blocked-user';

        final filter = TestContentFilter(
          blockedPubkeys: {blockedPubkey},
        );
        final repositoryWithFilter = VideosRepository(
          nostrClient: mockNostrClient,
          blockFilter: filter.call,
        );

        final blockedEvent = _createVideoEvent(
          id: 'blocked-video',
          pubkey: blockedPubkey,
          videoUrl: 'https://example.com/blocked.mp4',
          createdAt: 1704067200,
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [blockedEvent],
        );

        final result = await repositoryWithFilter.getNewVideos();

        expect(result, isEmpty);
        // Filter was called with the raw event pubkey
        expect(filter.calls, contains(blockedPubkey));
      });
    });

    group('getVideosByIds', () {
      test('returns empty list when eventIds is empty', () async {
        final result = await repository.getVideosByIds([]);

        expect(result, isEmpty);
        verifyNever(() => mockNostrClient.queryEvents(any()));
      });

      test('queries with correct filter for event IDs', () async {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => <Event>[],
        );

        final eventIds = ['id-1', 'id-2', 'id-3'];
        await repository.getVideosByIds(eventIds);

        final captured = verify(
          () => mockNostrClient.queryEvents(captureAny()),
        ).captured;
        final filters = captured.first as List<Filter>;

        expect(filters, hasLength(1));
        expect(filters.first.ids, equals(eventIds));
        expect(
          filters.first.kinds,
          equals(NIP71VideoKinds.getAllVideoKinds()),
        );
      });

      test('transforms valid events to VideoEvents', () async {
        final event = _createVideoEvent(
          id: 'test-id-123',
          pubkey: 'test-pubkey',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1704067200,
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [event],
        );

        final result = await repository.getVideosByIds(['test-id-123']);

        expect(result, hasLength(1));
        expect(result.first.id, equals('test-id-123'));
        expect(result.first.videoUrl, equals('https://example.com/video.mp4'));
      });

      test('preserves input order of event IDs', () async {
        final event1 = _createVideoEvent(
          id: 'id-1',
          pubkey: 'test-pubkey',
          videoUrl: 'https://example.com/video1.mp4',
          createdAt: 1704067200,
        );
        final event2 = _createVideoEvent(
          id: 'id-2',
          pubkey: 'test-pubkey',
          videoUrl: 'https://example.com/video2.mp4',
          createdAt: 1704067201,
        );
        final event3 = _createVideoEvent(
          id: 'id-3',
          pubkey: 'test-pubkey',
          videoUrl: 'https://example.com/video3.mp4',
          createdAt: 1704067202,
        );

        // Return events in different order than requested
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [event3, event1, event2],
        );

        final result = await repository.getVideosByIds([
          'id-1',
          'id-2',
          'id-3',
        ]);

        expect(result, hasLength(3));
        expect(result[0].id, equals('id-1'));
        expect(result[1].id, equals('id-2'));
        expect(result[2].id, equals('id-3'));
      });

      test('filters out videos without valid URL', () async {
        final validEvent = _createVideoEvent(
          id: 'valid-id',
          pubkey: 'test-pubkey',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1704067200,
        );
        final invalidEvent = _createVideoEvent(
          id: 'invalid-id',
          pubkey: 'test-pubkey',
          videoUrl: null,
          createdAt: 1704067201,
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [validEvent, invalidEvent],
        );

        final result = await repository.getVideosByIds([
          'valid-id',
          'invalid-id',
        ]);

        expect(result, hasLength(1));
        expect(result.first.id, equals('valid-id'));
      });

      test('handles missing events gracefully', () async {
        final event = _createVideoEvent(
          id: 'found-id',
          pubkey: 'test-pubkey',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1704067200,
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [event],
        );

        final result = await repository.getVideosByIds([
          'found-id',
          'missing-id-1',
          'missing-id-2',
        ]);

        expect(result, hasLength(1));
        expect(result.first.id, equals('found-id'));
      });

      test('filters out videos from blocked pubkeys', () async {
        const blockedPubkey = 'blocked-user-pubkey';
        const allowedPubkey = 'allowed-user-pubkey';

        final filter = TestContentFilter(
          blockedPubkeys: {blockedPubkey},
        );
        final repositoryWithFilter = VideosRepository(
          nostrClient: mockNostrClient,
          blockFilter: filter.call,
        );

        final blockedEvent = _createVideoEvent(
          id: 'blocked-video',
          pubkey: blockedPubkey,
          videoUrl: 'https://example.com/blocked.mp4',
          createdAt: 1704067200,
        );
        final allowedEvent = _createVideoEvent(
          id: 'allowed-video',
          pubkey: allowedPubkey,
          videoUrl: 'https://example.com/allowed.mp4',
          createdAt: 1704067201,
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [blockedEvent, allowedEvent],
        );

        final result = await repositoryWithFilter.getVideosByIds([
          'blocked-video',
          'allowed-video',
        ]);

        expect(result, hasLength(1));
        expect(result.first.id, equals('allowed-video'));
      });

      test('filters videos with NSFW hashtag when filter is active', () async {
        final nsfwFilter = TestNsfwFilter();
        final repositoryWithFilter = VideosRepository(
          nostrClient: mockNostrClient,
          contentFilter: nsfwFilter.call,
        );

        final nsfwEvent = _createVideoEvent(
          id: 'nsfw-video',
          pubkey: 'user-1',
          videoUrl: 'https://example.com/nsfw.mp4',
          createdAt: 1704067200,
          hashtags: ['nsfw'],
        );
        final safeEvent = _createVideoEvent(
          id: 'safe-video',
          pubkey: 'user-2',
          videoUrl: 'https://example.com/safe.mp4',
          createdAt: 1704067201,
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [nsfwEvent, safeEvent],
        );

        final result = await repositoryWithFilter.getVideosByIds([
          'nsfw-video',
          'safe-video',
        ]);

        expect(result, hasLength(1));
        expect(result.first.id, equals('safe-video'));
      });
    });

    group('getVideosByAddressableIds', () {
      test('returns empty list when addressableIds is empty', () async {
        final result = await repository.getVideosByAddressableIds([]);

        expect(result, isEmpty);
        verifyNever(() => mockNostrClient.queryEvents(any()));
      });

      test('returns empty list when all addressableIds are invalid', () async {
        final result = await repository.getVideosByAddressableIds([
          'invalid-format',
          'also:invalid', // missing d-tag
        ]);

        expect(result, isEmpty);
        verifyNever(() => mockNostrClient.queryEvents(any()));
      });

      test('queries with correct filters for addressable IDs', () async {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => <Event>[],
        );

        final addressableIds = [
          '${EventKind.videoVertical}:pubkey1:dtag1',
          '${EventKind.videoVertical}:pubkey2:dtag2',
        ];
        await repository.getVideosByAddressableIds(addressableIds);

        final captured = verify(
          () => mockNostrClient.queryEvents(captureAny()),
        ).captured;
        final filters = captured.first as List<Filter>;

        expect(filters, hasLength(2));
        expect(filters[0].kinds, equals([EventKind.videoVertical]));
        expect(filters[0].authors, equals(['pubkey1']));
        expect(filters[0].d, equals(['dtag1']));
        expect(filters[1].kinds, equals([EventKind.videoVertical]));
        expect(filters[1].authors, equals(['pubkey2']));
        expect(filters[1].d, equals(['dtag2']));
      });

      test('transforms valid events to VideoEvents', () async {
        final event = _createVideoEvent(
          id: 'test-id-123',
          pubkey: 'test-pubkey',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1704067200,
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [event],
        );

        final result = await repository.getVideosByAddressableIds([
          '${EventKind.videoVertical}:test-pubkey:test-id-123',
        ]);

        expect(result, hasLength(1));
        expect(result.first.id, equals('test-id-123'));
        expect(result.first.videoUrl, equals('https://example.com/video.mp4'));
      });

      test('preserves input order of addressable IDs', () async {
        final event1 = _createVideoEvent(
          id: 'dtag-1',
          pubkey: 'pubkey-1',
          videoUrl: 'https://example.com/video1.mp4',
          createdAt: 1704067200,
        );
        final event2 = _createVideoEvent(
          id: 'dtag-2',
          pubkey: 'pubkey-2',
          videoUrl: 'https://example.com/video2.mp4',
          createdAt: 1704067201,
        );
        final event3 = _createVideoEvent(
          id: 'dtag-3',
          pubkey: 'pubkey-3',
          videoUrl: 'https://example.com/video3.mp4',
          createdAt: 1704067202,
        );

        // Return events in different order than requested
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [event3, event1, event2],
        );

        final result = await repository.getVideosByAddressableIds([
          '${EventKind.videoVertical}:pubkey-1:dtag-1',
          '${EventKind.videoVertical}:pubkey-2:dtag-2',
          '${EventKind.videoVertical}:pubkey-3:dtag-3',
        ]);

        expect(result, hasLength(3));
        expect(result[0].vineId, equals('dtag-1'));
        expect(result[1].vineId, equals('dtag-2'));
        expect(result[2].vineId, equals('dtag-3'));
      });

      test('handles d-tags with colons', () async {
        final event = _createVideoEventWithDTag(
          id: 'test-id',
          pubkey: 'test-pubkey',
          dTag: 'dtag:with:colons',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1704067200,
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [event],
        );

        final result = await repository.getVideosByAddressableIds([
          '${EventKind.videoVertical}:test-pubkey:dtag:with:colons',
        ]);

        expect(result, hasLength(1));
        expect(result.first.vineId, equals('dtag:with:colons'));
      });

      test('filters out videos without valid URL', () async {
        final validEvent = _createVideoEvent(
          id: 'valid-dtag',
          pubkey: 'test-pubkey',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1704067200,
        );
        final invalidEvent = _createVideoEvent(
          id: 'invalid-dtag',
          pubkey: 'test-pubkey',
          videoUrl: null,
          createdAt: 1704067201,
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [validEvent, invalidEvent],
        );

        final result = await repository.getVideosByAddressableIds([
          '${EventKind.videoVertical}:test-pubkey:valid-dtag',
          '${EventKind.videoVertical}:test-pubkey:invalid-dtag',
        ]);

        expect(result, hasLength(1));
        expect(result.first.vineId, equals('valid-dtag'));
      });

      test('handles missing events gracefully', () async {
        final event = _createVideoEvent(
          id: 'found-dtag',
          pubkey: 'test-pubkey',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1704067200,
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [event],
        );

        final result = await repository.getVideosByAddressableIds([
          '${EventKind.videoVertical}:test-pubkey:found-dtag',
          '${EventKind.videoVertical}:other-pubkey:missing-dtag-1',
          '${EventKind.videoVertical}:another-pubkey:missing-dtag-2',
        ]);

        expect(result, hasLength(1));
        expect(result.first.vineId, equals('found-dtag'));
      });

      test('filters out non-video kinds', () async {
        // Should skip filters for non-video kinds
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => <Event>[],
        );

        final result = await repository.getVideosByAddressableIds([
          '1:pubkey:dtag', // kind 1 is not a video kind
          '30023:pubkey:dtag', // kind 30023 is not a video kind
        ]);

        expect(result, isEmpty);
        verifyNever(() => mockNostrClient.queryEvents(any()));
      });

      test('filters out videos from blocked pubkeys', () async {
        const blockedPubkey = 'blocked-user-pubkey';
        const allowedPubkey = 'allowed-user-pubkey';

        final filter = TestContentFilter(
          blockedPubkeys: {blockedPubkey},
        );
        final repositoryWithFilter = VideosRepository(
          nostrClient: mockNostrClient,
          blockFilter: filter.call,
        );

        final blockedEvent = _createVideoEvent(
          id: 'blocked-dtag',
          pubkey: blockedPubkey,
          videoUrl: 'https://example.com/blocked.mp4',
          createdAt: 1704067200,
        );
        final allowedEvent = _createVideoEvent(
          id: 'allowed-dtag',
          pubkey: allowedPubkey,
          videoUrl: 'https://example.com/allowed.mp4',
          createdAt: 1704067201,
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [blockedEvent, allowedEvent],
        );

        final result = await repositoryWithFilter.getVideosByAddressableIds([
          '${EventKind.videoVertical}:$blockedPubkey:blocked-dtag',
          '${EventKind.videoVertical}:$allowedPubkey:allowed-dtag',
        ]);

        expect(result, hasLength(1));
        expect(result.first.vineId, equals('allowed-dtag'));
      });

      test('filters videos with NSFW hashtag when filter is active', () async {
        final nsfwFilter = TestNsfwFilter();
        final repositoryWithFilter = VideosRepository(
          nostrClient: mockNostrClient,
          contentFilter: nsfwFilter.call,
        );

        final nsfwEvent = _createVideoEvent(
          id: 'nsfw-dtag',
          pubkey: 'user-1',
          videoUrl: 'https://example.com/nsfw.mp4',
          createdAt: 1704067200,
          hashtags: ['nsfw'],
        );
        final safeEvent = _createVideoEvent(
          id: 'safe-dtag',
          pubkey: 'user-2',
          videoUrl: 'https://example.com/safe.mp4',
          createdAt: 1704067201,
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [nsfwEvent, safeEvent],
        );

        final result = await repositoryWithFilter.getVideosByAddressableIds([
          '${EventKind.videoVertical}:user-1:nsfw-dtag',
          '${EventKind.videoVertical}:user-2:safe-dtag',
        ]);

        expect(result, hasLength(1));
        expect(result.first.vineId, equals('safe-dtag'));
      });
    });

    group('video event filtering (stage 2)', () {
      test('filters videos with NSFW hashtag when filter is active', () async {
        final nsfwFilter = TestNsfwFilter();
        final repositoryWithFilter = VideosRepository(
          nostrClient: mockNostrClient,
          contentFilter: nsfwFilter.call,
        );

        final nsfwEvent = _createVideoEvent(
          id: 'nsfw-video',
          pubkey: 'user-1',
          videoUrl: 'https://example.com/nsfw.mp4',
          createdAt: 1704067200,
          hashtags: ['nsfw', 'other'],
        );
        final safeEvent = _createVideoEvent(
          id: 'safe-video',
          pubkey: 'user-2',
          videoUrl: 'https://example.com/safe.mp4',
          createdAt: 1704067201,
          hashtags: ['funny', 'cat'],
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [nsfwEvent, safeEvent],
        );

        final result = await repositoryWithFilter.getNewVideos();

        expect(result, hasLength(1));
        expect(result.first.id, equals('safe-video'));
        expect(nsfwFilter.calls, hasLength(2));
      });

      test('filters videos with adult hashtag', () async {
        final nsfwFilter = TestNsfwFilter();
        final repositoryWithFilter = VideosRepository(
          nostrClient: mockNostrClient,
          contentFilter: nsfwFilter.call,
        );

        final adultEvent = _createVideoEvent(
          id: 'adult-video',
          pubkey: 'user-1',
          videoUrl: 'https://example.com/adult.mp4',
          createdAt: 1704067200,
          hashtags: ['adult'],
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [adultEvent],
        );

        final result = await repositoryWithFilter.getNewVideos();

        expect(result, isEmpty);
      });

      test('filters videos with content-warning tag', () async {
        final nsfwFilter = TestNsfwFilter();
        final repositoryWithFilter = VideosRepository(
          nostrClient: mockNostrClient,
          contentFilter: nsfwFilter.call,
        );

        final cwEvent = _createVideoEvent(
          id: 'cw-video',
          pubkey: 'user-1',
          videoUrl: 'https://example.com/cw.mp4',
          createdAt: 1704067200,
          hasContentWarning: true,
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [cwEvent],
        );

        final result = await repositoryWithFilter.getNewVideos();

        expect(result, isEmpty);
      });

      test('does not filter when videoEventFilter is null', () async {
        // Use default repository without filter
        final nsfwEvent = _createVideoEvent(
          id: 'nsfw-video',
          pubkey: 'user-1',
          videoUrl: 'https://example.com/nsfw.mp4',
          createdAt: 1704067200,
          hashtags: ['nsfw'],
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [nsfwEvent],
        );

        final result = await repository.getNewVideos();

        expect(result, hasLength(1));
        expect(result.first.id, equals('nsfw-video'));
      });

      test('does not filter NSFW when filter returns false', () async {
        final nsfwFilter = TestNsfwFilter(filterNsfw: false);
        final repositoryWithFilter = VideosRepository(
          nostrClient: mockNostrClient,
          contentFilter: nsfwFilter.call,
        );

        final nsfwEvent = _createVideoEvent(
          id: 'nsfw-video',
          pubkey: 'user-1',
          videoUrl: 'https://example.com/nsfw.mp4',
          createdAt: 1704067200,
          hashtags: ['nsfw'],
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [nsfwEvent],
        );

        final result = await repositoryWithFilter.getNewVideos();

        expect(result, hasLength(1));
        expect(nsfwFilter.calls, hasLength(1));
      });

      test('applies both content filter and video event filter', () async {
        const blockedPubkey = 'blocked-user';
        final contentFilter = TestContentFilter(
          blockedPubkeys: {blockedPubkey},
        );
        final nsfwFilter = TestNsfwFilter();

        final repositoryWithBothFilters = VideosRepository(
          nostrClient: mockNostrClient,
          blockFilter: contentFilter.call,
          contentFilter: nsfwFilter.call,
        );

        final blockedEvent = _createVideoEvent(
          id: 'blocked-video',
          pubkey: blockedPubkey,
          videoUrl: 'https://example.com/blocked.mp4',
          createdAt: 1704067200,
        );
        final nsfwEvent = _createVideoEvent(
          id: 'nsfw-video',
          pubkey: 'user-1',
          videoUrl: 'https://example.com/nsfw.mp4',
          createdAt: 1704067201,
          hashtags: ['nsfw'],
        );
        final safeEvent = _createVideoEvent(
          id: 'safe-video',
          pubkey: 'user-2',
          videoUrl: 'https://example.com/safe.mp4',
          createdAt: 1704067202,
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [blockedEvent, nsfwEvent, safeEvent],
        );

        final result = await repositoryWithBothFilters.getNewVideos();

        expect(result, hasLength(1));
        expect(result.first.id, equals('safe-video'));

        // Content filter was called for all events
        expect(contentFilter.calls, hasLength(3));

        // Video event filter was only called for non-blocked events
        // (blocked event filtered in stage 1, so stage 2 only sees 2 events)
        expect(nsfwFilter.calls, hasLength(2));
      });

      test('video event filter is called after parsing', () async {
        final filter = TestVideoEventFilter();
        final repositoryWithFilter = VideosRepository(
          nostrClient: mockNostrClient,
          contentFilter: filter.call,
        );

        final event = _createVideoEvent(
          id: 'video-1',
          pubkey: 'user-1',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1704067200,
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [event],
        );

        await repositoryWithFilter.getNewVideos();

        // Filter received a parsed VideoEvent, not raw Event
        expect(filter.calls, hasLength(1));
        expect(filter.calls.first.id, equals('video-1'));
        expect(filter.calls.first.pubkey, equals('user-1'));
      });
    });
  });
}

/// Creates a mock video event for testing.
Event _createVideoEvent({
  required String id,
  required String pubkey,
  required String? videoUrl,
  required int createdAt,
  int? loops,
  List<String>? hashtags,
  bool hasContentWarning = false,
}) {
  final tags = <List<String>>[
    if (videoUrl != null) ['url', videoUrl],
    if (loops != null) ['loops', loops.toString()],
    ['d', id], // Required for addressable events
    if (hashtags != null)
      for (final tag in hashtags) ['t', tag],
    if (hasContentWarning) ['content-warning', 'adult content'],
  ];

  return Event.fromJson({
    'id': id,
    'pubkey': pubkey,
    'created_at': createdAt,
    'kind': EventKind.videoVertical,
    'tags': tags,
    'content': '',
    'sig': '',
  });
}

/// Creates a mock video event with a custom d-tag for testing.
Event _createVideoEventWithDTag({
  required String id,
  required String pubkey,
  required String dTag,
  required String? videoUrl,
  required int createdAt,
  int? loops,
  List<String>? hashtags,
  bool hasContentWarning = false,
}) {
  final tags = <List<String>>[
    if (videoUrl != null) ['url', videoUrl],
    if (loops != null) ['loops', loops.toString()],
    ['d', dTag], // Custom d-tag
    if (hashtags != null)
      for (final tag in hashtags) ['t', tag],
    if (hasContentWarning) ['content-warning', 'adult content'],
  ];

  return Event.fromJson({
    'id': id,
    'pubkey': pubkey,
    'created_at': createdAt,
    'kind': EventKind.videoVertical,
    'tags': tags,
    'content': '',
    'sig': '',
  });
}
