import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:videos_repository/videos_repository.dart';

class MockNostrClient extends Mock implements NostrClient {}

class MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

class MockVideoLocalStorage extends Mock implements VideoLocalStorage {}

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
      group('Funnelcake API first', () {
        late MockFunnelcakeApiClient mockFunnelcakeClient;

        setUp(() {
          mockFunnelcakeClient = MockFunnelcakeApiClient();
        });

        test('returns API results when Funnelcake succeeds', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getRecentVideos(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => [
              _createVideoStats(
                id: 'event-1',
                pubkey: 'pubkey-1',
                dTag: 'dtag-1',
                videoUrl: 'https://example.com/video.mp4',
              ),
            ],
          );

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repositoryWithApi.getNewVideos();

          expect(result, hasLength(1));
          expect(
            result.first.videoUrl,
            equals('https://example.com/video.mp4'),
          );
          // Should NOT query Nostr relay
          verifyNever(() => mockNostrClient.queryEvents(any()));
        });

        test('passes limit and before to Funnelcake API', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getRecentVideos(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => [
              _createVideoStats(
                id: 'event-1',
                pubkey: 'pubkey-1',
                dTag: 'dtag-1',
                videoUrl: 'https://example.com/video.mp4',
              ),
            ],
          );

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          await repositoryWithApi.getNewVideos(limit: 10, until: 1704067200);

          verify(
            () => mockFunnelcakeClient.getRecentVideos(
              limit: 10,
              before: 1704067200,
            ),
          ).called(1);
        });

        test('falls back to Nostr when Funnelcake throws', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getRecentVideos(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenThrow(const FunnelcakeException('Network error'));

          final nostrEvent = _createVideoEvent(
            id: 'nostr-video',
            pubkey: 'test-pubkey',
            videoUrl: 'https://example.com/nostr.mp4',
            createdAt: 1704067200,
          );
          when(() => mockNostrClient.queryEvents(any())).thenAnswer(
            (_) async => [nostrEvent],
          );

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repositoryWithApi.getNewVideos();

          expect(result, hasLength(1));
          expect(result.first.id, equals('nostr-video'));
          verify(() => mockNostrClient.queryEvents(any())).called(1);
        });

        test('falls back to Nostr when Funnelcake returns empty', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getRecentVideos(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer((_) async => <VideoStats>[]);

          final nostrEvent = _createVideoEvent(
            id: 'nostr-video',
            pubkey: 'test-pubkey',
            videoUrl: 'https://example.com/nostr.mp4',
            createdAt: 1704067200,
          );
          when(() => mockNostrClient.queryEvents(any())).thenAnswer(
            (_) async => [nostrEvent],
          );

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repositoryWithApi.getNewVideos();

          expect(result, hasLength(1));
          expect(result.first.id, equals('nostr-video'));
        });

        test(
          'falls back to Nostr when all API results filtered out',
          () async {
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
            when(
              () => mockFunnelcakeClient.getRecentVideos(
                limit: any(named: 'limit'),
                before: any(named: 'before'),
              ),
            ).thenAnswer(
              (_) async => [
                _createVideoStats(
                  id: 'event-1',
                  pubkey: 'blocked-pubkey',
                  dTag: 'dtag-1',
                  videoUrl: 'https://example.com/video.mp4',
                ),
              ],
            );

            final nostrEvent = _createVideoEvent(
              id: 'nostr-video',
              pubkey: 'allowed-pubkey',
              videoUrl: 'https://example.com/nostr.mp4',
              createdAt: 1704067200,
            );
            when(() => mockNostrClient.queryEvents(any())).thenAnswer(
              (_) async => [nostrEvent],
            );

            final blockFilter = TestContentFilter(
              blockedPubkeys: {'blocked-pubkey'},
            );
            final repositoryWithApi = VideosRepository(
              nostrClient: mockNostrClient,
              funnelcakeApiClient: mockFunnelcakeClient,
              blockFilter: blockFilter.call,
            );

            final result = await repositoryWithApi.getNewVideos();

            expect(result, hasLength(1));
            expect(result.first.id, equals('nostr-video'));
          },
        );

        test('skips API when Funnelcake client is null', () async {
          when(() => mockNostrClient.queryEvents(any())).thenAnswer(
            (_) async => <Event>[],
          );

          // Default repository has no Funnelcake client
          await repository.getNewVideos();

          verify(() => mockNostrClient.queryEvents(any())).called(1);
        });

        test('skips API when Funnelcake is not available', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);
          when(() => mockNostrClient.queryEvents(any())).thenAnswer(
            (_) async => <Event>[],
          );

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          await repositoryWithApi.getNewVideos();

          verifyNever(
            () => mockFunnelcakeClient.getRecentVideos(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          );
          verify(() => mockNostrClient.queryEvents(any())).called(1);
        });

        test('applies content filters to API results', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getRecentVideos(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => [
              _createVideoStats(
                id: 'event-1',
                pubkey: 'blocked-pubkey',
                dTag: 'dtag-1',
                videoUrl: 'https://example.com/blocked.mp4',
              ),
              _createVideoStats(
                id: 'event-2',
                pubkey: 'allowed-pubkey',
                dTag: 'dtag-2',
                videoUrl: 'https://example.com/allowed.mp4',
              ),
            ],
          );

          final blockFilter = TestContentFilter(
            blockedPubkeys: {'blocked-pubkey'},
          );
          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            blockFilter: blockFilter.call,
          );

          final result = await repositoryWithApi.getNewVideos();

          expect(result, hasLength(1));
          expect(
            result.first.videoUrl,
            equals('https://example.com/allowed.mp4'),
          );
        });
      });

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
      group('Funnelcake API first', () {
        late MockFunnelcakeApiClient mockFunnelcakeClient;

        setUp(() {
          mockFunnelcakeClient = MockFunnelcakeApiClient();
        });

        test('returns API results when Funnelcake succeeds', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getHomeFeed(
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => HomeFeedResponse(
              videos: [
                _createVideoStats(
                  id: 'event-1',
                  pubkey: 'followed-user',
                  dTag: 'dtag-1',
                  videoUrl: 'https://example.com/video.mp4',
                ),
              ],
              hasMore: true,
              nextCursor: 1704067100,
            ),
          );

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repositoryWithApi.getHomeFeedVideos(
            authors: ['followed-user'],
            userPubkey: 'my-pubkey',
          );

          expect(result.videos, hasLength(1));
          expect(
            result.videos.first.videoUrl,
            equals('https://example.com/video.mp4'),
          );
          verifyNever(() => mockNostrClient.queryEvents(any()));
        });

        test('passes params to Funnelcake API', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getHomeFeed(
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => const HomeFeedResponse(videos: []),
          );
          when(() => mockNostrClient.queryEvents(any())).thenAnswer(
            (_) async => <Event>[],
          );

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          await repositoryWithApi.getHomeFeedVideos(
            authors: ['user1'],
            userPubkey: 'my-pubkey',
            limit: 10,
            until: 1704067200,
          );

          verify(
            () => mockFunnelcakeClient.getHomeFeed(
              pubkey: 'my-pubkey',
              limit: 10,
              before: 1704067200,
            ),
          ).called(1);
        });

        test('falls back to Nostr when Funnelcake throws', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getHomeFeed(
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenThrow(const FunnelcakeException('Network error'));

          final nostrEvent = _createVideoEvent(
            id: 'nostr-video',
            pubkey: 'followed-user',
            videoUrl: 'https://example.com/nostr.mp4',
            createdAt: 1704067200,
          );
          when(() => mockNostrClient.queryEvents(any())).thenAnswer(
            (_) async => [nostrEvent],
          );

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repositoryWithApi.getHomeFeedVideos(
            authors: ['followed-user'],
            userPubkey: 'my-pubkey',
          );

          expect(result.videos, hasLength(1));
          expect(result.videos.first.id, equals('nostr-video'));
          verify(() => mockNostrClient.queryEvents(any())).called(1);
        });

        test('falls back to Nostr when Funnelcake returns empty', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getHomeFeed(
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => const HomeFeedResponse(videos: []),
          );

          final nostrEvent = _createVideoEvent(
            id: 'nostr-video',
            pubkey: 'followed-user',
            videoUrl: 'https://example.com/nostr.mp4',
            createdAt: 1704067200,
          );
          when(() => mockNostrClient.queryEvents(any())).thenAnswer(
            (_) async => [nostrEvent],
          );

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repositoryWithApi.getHomeFeedVideos(
            authors: ['followed-user'],
            userPubkey: 'my-pubkey',
          );

          expect(result.videos, hasLength(1));
          expect(result.videos.first.id, equals('nostr-video'));
        });

        test('skips API when userPubkey is null', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(() => mockNostrClient.queryEvents(any())).thenAnswer(
            (_) async => <Event>[],
          );

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          await repositoryWithApi.getHomeFeedVideos(
            authors: ['user1'],
            // No userPubkey
          );

          verifyNever(
            () => mockFunnelcakeClient.getHomeFeed(
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          );
          verify(() => mockNostrClient.queryEvents(any())).called(1);
        });

        test('skips API when Funnelcake is not available', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);
          when(() => mockNostrClient.queryEvents(any())).thenAnswer(
            (_) async => <Event>[],
          );

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          await repositoryWithApi.getHomeFeedVideos(
            authors: ['user1'],
            userPubkey: 'my-pubkey',
          );

          verifyNever(
            () => mockFunnelcakeClient.getHomeFeed(
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          );
          verify(() => mockNostrClient.queryEvents(any())).called(1);
        });

        test('applies content filters to API results', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getHomeFeed(
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => HomeFeedResponse(
              videos: [
                _createVideoStats(
                  id: 'event-1',
                  pubkey: 'blocked-pubkey',
                  dTag: 'dtag-1',
                  videoUrl: 'https://example.com/blocked.mp4',
                ),
                _createVideoStats(
                  id: 'event-2',
                  pubkey: 'allowed-pubkey',
                  dTag: 'dtag-2',
                  videoUrl: 'https://example.com/allowed.mp4',
                ),
              ],
            ),
          );

          final blockFilter = TestContentFilter(
            blockedPubkeys: {'blocked-pubkey'},
          );
          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            blockFilter: blockFilter.call,
          );

          final result = await repositoryWithApi.getHomeFeedVideos(
            authors: ['blocked-pubkey', 'allowed-pubkey'],
            userPubkey: 'my-pubkey',
          );

          expect(result.videos, hasLength(1));
          expect(
            result.videos.first.videoUrl,
            equals('https://example.com/allowed.mp4'),
          );
        });
      });

      test('returns empty result when authors is empty', () async {
        final result = await repository.getHomeFeedVideos(authors: []);

        expect(result.videos, isEmpty);
        verifyNever(() => mockNostrClient.queryEvents(any()));
      });

      test('returns empty result when no events found', () async {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => <Event>[],
        );

        final result = await repository.getHomeFeedVideos(
          authors: ['pubkey1', 'pubkey2'],
        );

        expect(result.videos, isEmpty);
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

        expect(result.videos, hasLength(1));
        expect(result.videos.first.id, equals('home-video-123'));
        expect(result.videos.first.pubkey, equals('followed-user'));
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

        expect(result.videos, hasLength(2));
        expect(result.videos.first.id, equals('newer'));
        expect(result.videos.last.id, equals('older'));
      });
    });

    group('getHomeFeedVideos with videoRefs', () {
      test('empty videoRefs returns only following videos', () async {
        final event = _createVideoEvent(
          id: 'following-video',
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

        expect(result.videos, hasLength(1));
        expect(result.videos.first.id, equals('following-video'));
        expect(result.videoListSources, isEmpty);
        expect(result.listOnlyVideoIds, isEmpty);
      });

      test('merges list videos with following videos', () async {
        final followingEvent = _createVideoEvent(
          id: 'following-video',
          pubkey: 'followed-user',
          videoUrl: 'https://example.com/following.mp4',
          createdAt: 1704067200,
        );

        final listEvent = _createVideoEvent(
          id: 'list-video',
          pubkey: 'list-author',
          videoUrl: 'https://example.com/list.mp4',
          createdAt: 1704067300,
        );

        // Following fetch
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (invocation) async {
            final filters = invocation.positionalArguments[0] as List<Filter>;
            if (filters.first.authors != null) {
              return [followingEvent];
            }
            // Event ID fetch for list videos
            return [listEvent];
          },
        );

        final result = await repository.getHomeFeedVideos(
          authors: ['followed-user'],
          videoRefs: {
            'list-a': ['list-video'],
          },
        );

        expect(result.videos, hasLength(2));
        // Sorted by createdAt desc: list-video (300) then following (200)
        expect(result.videos.first.id, equals('list-video'));
        expect(result.videos.last.id, equals('following-video'));
        expect(result.videoListSources, hasLength(1));
        expect(result.videoListSources['list-video'], contains('list-a'));
        expect(result.listOnlyVideoIds, contains('list-video'));
      });

      test('deduplicates video in both following and list', () async {
        final sharedEvent = _createVideoEvent(
          id: 'shared-video',
          pubkey: 'followed-user',
          videoUrl: 'https://example.com/shared.mp4',
          createdAt: 1704067200,
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [sharedEvent],
        );

        final result = await repository.getHomeFeedVideos(
          authors: ['followed-user'],
          videoRefs: {
            'list-a': ['shared-video'],
          },
        );

        // Video appears only once (from following)
        expect(result.videos, hasLength(1));
        expect(result.videos.first.id, equals('shared-video'));
        // Still tracked in videoListSources (it IS in a list)
        expect(result.videoListSources['shared-video'], contains('list-a'));
        // NOT in listOnlyVideoIds (it's from a followed user)
        expect(result.listOnlyVideoIds, isEmpty);
      });

      test('builds correct videoListSources for multi-list refs', () async {
        final event = _createVideoEvent(
          id: 'multi-list-video',
          pubkey: 'some-author',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1704067200,
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (invocation) async {
            final filters = invocation.positionalArguments[0] as List<Filter>;
            if (filters.first.authors != null) return <Event>[];
            return [event];
          },
        );

        final result = await repository.getHomeFeedVideos(
          authors: ['followed-user'],
          videoRefs: {
            'list-a': ['multi-list-video'],
            'list-b': ['multi-list-video'],
          },
        );

        expect(result.videos, hasLength(1));
        expect(
          result.videoListSources['multi-list-video'],
          containsAll(['list-a', 'list-b']),
        );
        expect(result.listOnlyVideoIds, contains('multi-list-video'));
      });

      test('handles addressable coordinate refs', () async {
        final followingEvent = _createVideoEvent(
          id: 'following-video',
          pubkey: 'followed-user',
          videoUrl: 'https://example.com/following.mp4',
          createdAt: 1704067200,
        );

        final addressableEvent = _createVideoEventWithDTag(
          id: 'addressable-event-id',
          pubkey: 'list-author',
          dTag: 'my-vine',
          videoUrl: 'https://example.com/addressable.mp4',
          createdAt: 1704067300,
        );

        var callCount = 0;
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async {
            callCount++;
            if (callCount == 1) return [followingEvent]; // Following fetch
            return [addressableEvent]; // Addressable fetch
          },
        );

        final result = await repository.getHomeFeedVideos(
          authors: ['followed-user'],
          videoRefs: {
            'list-a': ['34236:list-author:my-vine'],
          },
        );

        expect(result.videos, hasLength(2));
        expect(result.listOnlyVideoIds, contains('addressable-event-id'));
      });

      test('handles mixed event ID and addressable refs', () async {
        final followingEvent = _createVideoEvent(
          id: 'following-video',
          pubkey: 'followed-user',
          videoUrl: 'https://example.com/following.mp4',
          createdAt: 1704067100,
        );

        final eventIdVideo = _createVideoEvent(
          id: 'event-id-video',
          pubkey: 'author-a',
          videoUrl: 'https://example.com/event.mp4',
          createdAt: 1704067200,
        );

        final addressableVideo = _createVideoEventWithDTag(
          id: 'addressable-id',
          pubkey: 'author-b',
          dTag: 'vine-dtag',
          videoUrl: 'https://example.com/addressable.mp4',
          createdAt: 1704067300,
        );

        var callCount = 0;
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async {
            callCount++;
            if (callCount == 1) return [followingEvent]; // Following
            if (callCount == 2) return [eventIdVideo]; // Event IDs
            return [addressableVideo]; // Addressable
          },
        );

        final result = await repository.getHomeFeedVideos(
          authors: ['followed-user'],
          videoRefs: {
            'list-a': ['event-id-video', '34236:author-b:vine-dtag'],
          },
        );

        expect(result.videos, hasLength(3));
        expect(result.listOnlyVideoIds, hasLength(2));
        expect(
          result.listOnlyVideoIds,
          containsAll(['event-id-video', 'addressable-id']),
        );
      });

      test('empty following + non-empty videoRefs', () async {
        final listEvent = _createVideoEvent(
          id: 'list-only-video',
          pubkey: 'list-author',
          videoUrl: 'https://example.com/list.mp4',
          createdAt: 1704067200,
        );

        var callCount = 0;
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async {
            callCount++;
            if (callCount == 1) return <Event>[]; // Following (empty)
            return [listEvent]; // List video fetch
          },
        );

        final result = await repository.getHomeFeedVideos(
          authors: ['followed-user'],
          videoRefs: {
            'list-a': ['list-only-video'],
          },
        );

        expect(result.videos, hasLength(1));
        expect(result.videos.first.id, equals('list-only-video'));
        expect(result.listOnlyVideoIds, contains('list-only-video'));
      });

      test('sorted by createdAt descending after merge', () async {
        final old = _createVideoEvent(
          id: 'old-following',
          pubkey: 'followed-user',
          videoUrl: 'https://example.com/old.mp4',
          createdAt: 1000,
        );

        final mid = _createVideoEvent(
          id: 'mid-list',
          pubkey: 'list-author',
          videoUrl: 'https://example.com/mid.mp4',
          createdAt: 2000,
        );

        final newest = _createVideoEvent(
          id: 'new-following',
          pubkey: 'followed-user',
          videoUrl: 'https://example.com/new.mp4',
          createdAt: 3000,
        );

        var callCount = 0;
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async {
            callCount++;
            if (callCount == 1) return [old, newest]; // Following
            return [mid]; // List videos
          },
        );

        final result = await repository.getHomeFeedVideos(
          authors: ['followed-user'],
          videoRefs: {
            'list-a': ['mid-list'],
          },
        );

        expect(result.videos, hasLength(3));
        expect(result.videos[0].id, equals('new-following'));
        expect(result.videos[1].id, equals('mid-list'));
        expect(result.videos[2].id, equals('old-following'));
      });

      test(
        'case-insensitive dedup between following and list',
        () async {
          final followingEvent = _createVideoEvent(
            id: 'AbCdEf',
            pubkey: 'followed-user',
            videoUrl: 'https://example.com/video.mp4',
            createdAt: 1704067200,
          );

          when(() => mockNostrClient.queryEvents(any())).thenAnswer(
            (invocation) async {
              final filters = invocation.positionalArguments[0] as List<Filter>;
              if (filters.first.authors != null) return [followingEvent];
              return [followingEvent]; // Same video from list fetch
            },
          );

          final result = await repository.getHomeFeedVideos(
            authors: ['followed-user'],
            videoRefs: {
              'list-a': ['AbCdEf'],
            },
          );

          // Video appears only once despite being in both
          expect(result.videos, hasLength(1));
          expect(result.listOnlyVideoIds, isEmpty);
        },
      );
    });

    group('getVideosForList', () {
      test('returns empty list when videoRefs is empty', () async {
        final result = await repository.getVideosForList([]);

        expect(result, isEmpty);
        verifyNever(() => mockNostrClient.queryEvents(any()));
      });

      test('fetches event ID refs correctly', () async {
        final event = _createVideoEvent(
          id: 'event-1',
          pubkey: 'author-1',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1704067200,
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [event],
        );

        final result = await repository.getVideosForList(['event-1']);

        expect(result, hasLength(1));
        expect(result.first.id, equals('event-1'));
      });

      test('fetches addressable refs correctly', () async {
        final event = _createVideoEventWithDTag(
          id: 'addr-event-id',
          pubkey: 'author-1',
          dTag: 'my-vine',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1704067200,
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [event],
        );

        final result = await repository.getVideosForList(
          ['34236:author-1:my-vine'],
        );

        expect(result, hasLength(1));
        expect(result.first.vineId, equals('my-vine'));
      });

      test('fetches mixed ref types in parallel', () async {
        final eventIdVideo = _createVideoEvent(
          id: 'event-video',
          pubkey: 'author-a',
          videoUrl: 'https://example.com/event.mp4',
          createdAt: 1704067200,
        );

        final addressableVideo = _createVideoEventWithDTag(
          id: 'addr-video',
          pubkey: 'author-b',
          dTag: 'vine-dtag',
          videoUrl: 'https://example.com/addressable.mp4',
          createdAt: 1704067300,
        );

        var callCount = 0;
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async {
            callCount++;
            if (callCount == 1) return [eventIdVideo];
            return [addressableVideo];
          },
        );

        final result = await repository.getVideosForList([
          'event-video',
          '34236:author-b:vine-dtag',
        ]);

        expect(result, hasLength(2));
        expect(result[0].id, equals('event-video'));
        expect(result[1].vineId, equals('vine-dtag'));
      });

      test('preserves ref order in result', () async {
        final video1 = _createVideoEvent(
          id: 'video-1',
          pubkey: 'author',
          videoUrl: 'https://example.com/1.mp4',
          createdAt: 1000,
        );

        final video2 = _createVideoEvent(
          id: 'video-2',
          pubkey: 'author',
          videoUrl: 'https://example.com/2.mp4',
          createdAt: 3000,
        );

        final video3 = _createVideoEvent(
          id: 'video-3',
          pubkey: 'author',
          videoUrl: 'https://example.com/3.mp4',
          createdAt: 2000,
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [video1, video2, video3],
        );

        // Request in specific order regardless of createdAt
        final result = await repository.getVideosForList([
          'video-3',
          'video-1',
          'video-2',
        ]);

        expect(result, hasLength(3));
        expect(result[0].id, equals('video-3'));
        expect(result[1].id, equals('video-1'));
        expect(result[2].id, equals('video-2'));
      });

      test('omits unresolved refs from result', () async {
        final video = _createVideoEvent(
          id: 'found-video',
          pubkey: 'author',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1704067200,
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [video],
        );

        final result = await repository.getVideosForList([
          'found-video',
          'missing-video',
        ]);

        expect(result, hasLength(1));
        expect(result.first.id, equals('found-video'));
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
      group('Funnelcake API first', () {
        late MockFunnelcakeApiClient mockFunnelcakeClient;

        setUp(() {
          mockFunnelcakeClient = MockFunnelcakeApiClient();
        });

        test('returns API results when Funnelcake succeeds', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getTrendingVideos(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => [
              _createVideoStats(
                id: 'event-1',
                pubkey: 'pubkey-1',
                dTag: 'dtag-1',
                videoUrl: 'https://example.com/trending.mp4',
              ),
            ],
          );

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repositoryWithApi.getPopularVideos();

          expect(result, hasLength(1));
          expect(
            result.first.videoUrl,
            equals('https://example.com/trending.mp4'),
          );
          // Should NOT query Nostr relay at all
          verifyNever(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          );
        });

        test('preserves API trending order (no re-sort)', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getTrendingVideos(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => [
              _createVideoStats(
                id: 'event-trending-1',
                pubkey: 'pubkey-1',
                dTag: 'dtag-1',
                videoUrl: 'https://example.com/video1.mp4',
              ),
              _createVideoStats(
                id: 'event-trending-2',
                pubkey: 'pubkey-2',
                dTag: 'dtag-2',
                videoUrl: 'https://example.com/video2.mp4',
              ),
            ],
          );

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repositoryWithApi.getPopularVideos(limit: 2);

          expect(result, hasLength(2));
          // Order should match API response, not sorted by createdAt
          expect(result[0].vineId, equals('dtag-1'));
          expect(result[1].vineId, equals('dtag-2'));
        });

        test('passes limit and before to Funnelcake API', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getTrendingVideos(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => [
              _createVideoStats(
                id: 'event-1',
                pubkey: 'pubkey-1',
                dTag: 'dtag-1',
                videoUrl: 'https://example.com/video.mp4',
              ),
            ],
          );

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          await repositoryWithApi.getPopularVideos(
            limit: 10,
            until: 1704067200,
          );

          verify(
            () => mockFunnelcakeClient.getTrendingVideos(
              limit: 10,
              before: 1704067200,
            ),
          ).called(1);
        });

        test('falls back to NIP-50 when Funnelcake throws', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getTrendingVideos(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenThrow(const FunnelcakeException('Network error'));

          final nip50Event = _createVideoEvent(
            id: 'nip50-video',
            pubkey: 'test-pubkey',
            videoUrl: 'https://example.com/nip50.mp4',
            createdAt: 1704067200,
          );
          when(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => [nip50Event]);

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repositoryWithApi.getPopularVideos();

          expect(result, hasLength(1));
          expect(result.first.id, equals('nip50-video'));
          verify(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).called(1);
        });

        test('falls back to NIP-50 when Funnelcake returns empty', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getTrendingVideos(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer((_) async => <VideoStats>[]);

          final nip50Event = _createVideoEvent(
            id: 'nip50-video',
            pubkey: 'test-pubkey',
            videoUrl: 'https://example.com/nip50.mp4',
            createdAt: 1704067200,
          );
          when(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => [nip50Event]);

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repositoryWithApi.getPopularVideos();

          expect(result, hasLength(1));
          expect(result.first.id, equals('nip50-video'));
        });

        test('skips API when Funnelcake client is null', () async {
          // getPopularVideos without Funnelcake goes straight to NIP-50
          when(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => <Event>[]);

          await repository.getPopularVideos();

          verify(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).called(greaterThanOrEqualTo(1));
        });

        test('skips API when Funnelcake is not available', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);
          when(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => <Event>[]);

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          await repositoryWithApi.getPopularVideos();

          verifyNever(
            () => mockFunnelcakeClient.getTrendingVideos(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          );
        });

        test('applies content filters to API results', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getTrendingVideos(
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => [
              _createVideoStats(
                id: 'event-1',
                pubkey: 'blocked-pubkey',
                dTag: 'dtag-1',
                videoUrl: 'https://example.com/blocked.mp4',
              ),
              _createVideoStats(
                id: 'event-2',
                pubkey: 'allowed-pubkey',
                dTag: 'dtag-2',
                videoUrl: 'https://example.com/allowed.mp4',
              ),
            ],
          );

          final blockFilter = TestContentFilter(
            blockedPubkeys: {'blocked-pubkey'},
          );
          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            blockFilter: blockFilter.call,
          );

          final result = await repositoryWithApi.getPopularVideos();

          expect(result, hasLength(1));
          expect(
            result.first.videoUrl,
            equals('https://example.com/allowed.mp4'),
          );
        });
      });

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

        expect(result.videos, hasLength(1));
        expect(result.videos.first.pubkey, equals(allowedPubkey));
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
        // No limit - addressable events are unique by kind:pubkey:d-tag
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

      group('Funnelcake API fallback', () {
        late MockFunnelcakeApiClient mockFunnelcakeClient;

        setUp(() {
          mockFunnelcakeClient = MockFunnelcakeApiClient();
        });

        test('does not call Funnelcake API when client is null', () async {
          // Repository without Funnelcake client
          when(() => mockNostrClient.queryEvents(any())).thenAnswer(
            (_) async => <Event>[],
          );

          final result = await repository.getVideosByAddressableIds([
            '${EventKind.videoVertical}:pubkey1:dtag1',
          ]);

          expect(result, isEmpty);
          // No FunnelcakeApiClient calls since none was provided
        });

        test(
          'does not call Funnelcake API when isAvailable is false',
          () async {
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

            final repositoryWithFunnelcake = VideosRepository(
              nostrClient: mockNostrClient,
              funnelcakeApiClient: mockFunnelcakeClient,
            );

            when(() => mockNostrClient.queryEvents(any())).thenAnswer(
              (_) async => <Event>[],
            );

            final result = await repositoryWithFunnelcake
                .getVideosByAddressableIds(
                  ['${EventKind.videoVertical}:pubkey1:dtag1'],
                );

            expect(result, isEmpty);
            verifyNever(
              () => mockFunnelcakeClient.getVideosByAuthor(
                pubkey: any(named: 'pubkey'),
                limit: any(named: 'limit'),
              ),
            );
          },
        );

        test(
          'does not call Funnelcake API when all videos found on Nostr',
          () async {
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);

            final repositoryWithFunnelcake = VideosRepository(
              nostrClient: mockNostrClient,
              funnelcakeApiClient: mockFunnelcakeClient,
            );

            final event = _createVideoEvent(
              id: 'dtag1',
              pubkey: 'pubkey1',
              videoUrl: 'https://example.com/video.mp4',
              createdAt: 1704067200,
            );

            when(() => mockNostrClient.queryEvents(any())).thenAnswer(
              (_) async => [event],
            );

            final result = await repositoryWithFunnelcake
                .getVideosByAddressableIds(
                  ['${EventKind.videoVertical}:pubkey1:dtag1'],
                );

            expect(result, hasLength(1));
            verifyNever(
              () => mockFunnelcakeClient.getVideosByAuthor(
                pubkey: any(named: 'pubkey'),
                limit: any(named: 'limit'),
              ),
            );
          },
        );

        test(
          'uses Funnelcake API fallback when Nostr returns no videos',
          () async {
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);

            final repositoryWithFunnelcake = VideosRepository(
              nostrClient: mockNostrClient,
              funnelcakeApiClient: mockFunnelcakeClient,
            );

            // Nostr returns nothing
            when(() => mockNostrClient.queryEvents(any())).thenAnswer(
              (_) async => <Event>[],
            );

            // Funnelcake returns the video
            final videoStats = _createVideoStats(
              id: 'event-id-1',
              pubkey: 'pubkey1',
              dTag: 'dtag1',
              videoUrl: 'https://example.com/video.mp4',
            );

            when(
              () => mockFunnelcakeClient.getVideosByAuthor(
                pubkey: 'pubkey1',
                limit: 100,
              ),
            ).thenAnswer((_) async => [videoStats]);

            final result = await repositoryWithFunnelcake
                .getVideosByAddressableIds(
                  ['${EventKind.videoVertical}:pubkey1:dtag1'],
                );

            expect(result, hasLength(1));
            expect(result.first.vineId, equals('dtag1'));
            verify(
              () => mockFunnelcakeClient.getVideosByAuthor(
                pubkey: 'pubkey1',
                limit: 100,
              ),
            ).called(1);
          },
        );

        test(
          'combines Nostr results with Funnelcake fallback results',
          () async {
            when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);

            final repositoryWithFunnelcake = VideosRepository(
              nostrClient: mockNostrClient,
              funnelcakeApiClient: mockFunnelcakeClient,
            );

            // Nostr returns only one video
            final nostrEvent = _createVideoEvent(
              id: 'dtag1',
              pubkey: 'pubkey1',
              videoUrl: 'https://example.com/video1.mp4',
              createdAt: 1704067200,
            );

            when(() => mockNostrClient.queryEvents(any())).thenAnswer(
              (_) async => [nostrEvent],
            );

            // Funnelcake returns the second video
            final videoStats = _createVideoStats(
              id: 'event-id-2',
              pubkey: 'pubkey2',
              dTag: 'dtag2',
              videoUrl: 'https://example.com/video2.mp4',
            );

            when(
              () => mockFunnelcakeClient.getVideosByAuthor(
                pubkey: 'pubkey2',
                limit: 100,
              ),
            ).thenAnswer((_) async => [videoStats]);

            final result = await repositoryWithFunnelcake
                .getVideosByAddressableIds(
                  [
                    '${EventKind.videoVertical}:pubkey1:dtag1',
                    '${EventKind.videoVertical}:pubkey2:dtag2',
                  ],
                );

            expect(result, hasLength(2));
            expect(result[0].vineId, equals('dtag1'));
            expect(result[1].vineId, equals('dtag2'));
          },
        );

        test('preserves original addressable ID order with fallback', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);

          final repositoryWithFunnelcake = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          // Nostr returns video 2 (not video 1 or 3)
          final nostrEvent = _createVideoEvent(
            id: 'dtag2',
            pubkey: 'pubkey2',
            videoUrl: 'https://example.com/video2.mp4',
            createdAt: 1704067200,
          );

          when(() => mockNostrClient.queryEvents(any())).thenAnswer(
            (_) async => [nostrEvent],
          );

          // Funnelcake returns videos 1 and 3
          final videoStats1 = _createVideoStats(
            id: 'event-id-1',
            pubkey: 'pubkey1',
            dTag: 'dtag1',
            videoUrl: 'https://example.com/video1.mp4',
          );
          final videoStats3 = _createVideoStats(
            id: 'event-id-3',
            pubkey: 'pubkey3',
            dTag: 'dtag3',
            videoUrl: 'https://example.com/video3.mp4',
          );

          when(
            () => mockFunnelcakeClient.getVideosByAuthor(
              pubkey: 'pubkey1',
              limit: 100,
            ),
          ).thenAnswer((_) async => [videoStats1]);

          when(
            () => mockFunnelcakeClient.getVideosByAuthor(
              pubkey: 'pubkey3',
              limit: 100,
            ),
          ).thenAnswer((_) async => [videoStats3]);

          final result = await repositoryWithFunnelcake
              .getVideosByAddressableIds(
                [
                  '${EventKind.videoVertical}:pubkey1:dtag1',
                  '${EventKind.videoVertical}:pubkey2:dtag2',
                  '${EventKind.videoVertical}:pubkey3:dtag3',
                ],
              );

          expect(result, hasLength(3));
          // Order should match input addressable IDs
          expect(result[0].vineId, equals('dtag1'));
          expect(result[1].vineId, equals('dtag2'));
          expect(result[2].vineId, equals('dtag3'));
        });

        test('handles Funnelcake API failure gracefully', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);

          final repositoryWithFunnelcake = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          // Nostr returns one video
          final nostrEvent = _createVideoEvent(
            id: 'dtag1',
            pubkey: 'pubkey1',
            videoUrl: 'https://example.com/video1.mp4',
            createdAt: 1704067200,
          );

          when(() => mockNostrClient.queryEvents(any())).thenAnswer(
            (_) async => [nostrEvent],
          );

          // Funnelcake throws an exception
          when(
            () => mockFunnelcakeClient.getVideosByAuthor(
              pubkey: 'pubkey2',
              limit: 100,
            ),
          ).thenThrow(const FunnelcakeException('Network error'));

          // Should not throw, just return what Nostr found
          final result = await repositoryWithFunnelcake
              .getVideosByAddressableIds(
                [
                  '${EventKind.videoVertical}:pubkey1:dtag1',
                  '${EventKind.videoVertical}:pubkey2:dtag2',
                ],
              );

          expect(result, hasLength(1));
          expect(result.first.vineId, equals('dtag1'));
        });

        test('applies block filter to Funnelcake API results', () async {
          const blockedPubkey = 'blocked-pubkey';

          final filter = TestContentFilter(blockedPubkeys: {blockedPubkey});
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);

          final repositoryWithFilter = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            blockFilter: filter.call,
          );

          // Nostr returns nothing
          when(() => mockNostrClient.queryEvents(any())).thenAnswer(
            (_) async => <Event>[],
          );

          // Funnelcake returns a video from blocked pubkey
          final videoStats = _createVideoStats(
            id: 'event-id-1',
            pubkey: blockedPubkey,
            dTag: 'dtag1',
            videoUrl: 'https://example.com/video.mp4',
          );

          when(
            () => mockFunnelcakeClient.getVideosByAuthor(
              pubkey: blockedPubkey,
              limit: 100,
            ),
          ).thenAnswer((_) async => [videoStats]);

          final result = await repositoryWithFilter.getVideosByAddressableIds([
            '${EventKind.videoVertical}:$blockedPubkey:dtag1',
          ]);

          // Should be filtered out
          expect(result, isEmpty);
        });

        test('filters out Funnelcake results without video URL', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);

          final repositoryWithFunnelcake = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          // Nostr returns nothing
          when(() => mockNostrClient.queryEvents(any())).thenAnswer(
            (_) async => <Event>[],
          );

          // Funnelcake returns a video without URL
          final videoStats = _createVideoStats(
            id: 'event-id-1',
            pubkey: 'pubkey1',
            dTag: 'dtag1',
            videoUrl: '', // No video URL
          );

          when(
            () => mockFunnelcakeClient.getVideosByAuthor(
              pubkey: 'pubkey1',
              limit: 100,
            ),
          ).thenAnswer((_) async => [videoStats]);

          final result = await repositoryWithFunnelcake
              .getVideosByAddressableIds(
                ['${EventKind.videoVertical}:pubkey1:dtag1'],
              );

          expect(result, isEmpty);
        });

        test('batches Funnelcake requests by pubkey', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);

          final repositoryWithFunnelcake = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          // Nostr returns nothing
          when(() => mockNostrClient.queryEvents(any())).thenAnswer(
            (_) async => <Event>[],
          );

          // Funnelcake returns both videos from the same author
          final videoStats1 = _createVideoStats(
            id: 'event-id-1',
            pubkey: 'same-pubkey',
            dTag: 'dtag1',
            videoUrl: 'https://example.com/video1.mp4',
          );
          final videoStats2 = _createVideoStats(
            id: 'event-id-2',
            pubkey: 'same-pubkey',
            dTag: 'dtag2',
            videoUrl: 'https://example.com/video2.mp4',
          );

          when(
            () => mockFunnelcakeClient.getVideosByAuthor(
              pubkey: 'same-pubkey',
              limit: 100,
            ),
          ).thenAnswer((_) async => [videoStats1, videoStats2]);

          final result = await repositoryWithFunnelcake
              .getVideosByAddressableIds(
                [
                  '${EventKind.videoVertical}:same-pubkey:dtag1',
                  '${EventKind.videoVertical}:same-pubkey:dtag2',
                ],
              );

          expect(result, hasLength(2));
          // Should only make one API call for the same pubkey
          verify(
            () => mockFunnelcakeClient.getVideosByAuthor(
              pubkey: 'same-pubkey',
              limit: 100,
            ),
          ).called(1);
        });
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

    group('local storage caching', () {
      late MockVideoLocalStorage mockLocalStorage;

      setUp(() {
        mockLocalStorage = MockVideoLocalStorage();
      });

      setUpAll(() {
        registerFallbackValue(<Event>[]);
      });

      group('getVideosByIds with localStorage', () {
        test('returns cached events from localStorage', () async {
          final cachedEvent = _createVideoEvent(
            id: 'cached-id',
            pubkey: 'test-pubkey',
            videoUrl: 'https://example.com/cached.mp4',
            createdAt: 1704067200,
          );

          when(() => mockLocalStorage.getEventsByIds(any())).thenAnswer(
            (_) async => [cachedEvent],
          );

          final repositoryWithCache = VideosRepository(
            nostrClient: mockNostrClient,
            localStorage: mockLocalStorage,
          );

          final result = await repositoryWithCache.getVideosByIds([
            'cached-id',
          ]);

          expect(result, hasLength(1));
          expect(result.first.id, equals('cached-id'));
          // Should not query relay since all events were cached
          verifyNever(() => mockNostrClient.queryEvents(any()));
        });

        test(
          'queries relay for missing events when cache partial hit',
          () async {
            final cachedEvent = _createVideoEvent(
              id: 'cached-id',
              pubkey: 'test-pubkey',
              videoUrl: 'https://example.com/cached.mp4',
              createdAt: 1704067200,
            );
            final relayEvent = _createVideoEvent(
              id: 'relay-id',
              pubkey: 'test-pubkey',
              videoUrl: 'https://example.com/relay.mp4',
              createdAt: 1704067201,
            );

            when(() => mockLocalStorage.getEventsByIds(any())).thenAnswer(
              (_) async => [cachedEvent],
            );
            when(() => mockNostrClient.queryEvents(any())).thenAnswer(
              (_) async => [relayEvent],
            );
            when(() => mockLocalStorage.saveEventsBatch(any())).thenAnswer(
              (_) async {},
            );

            final repositoryWithCache = VideosRepository(
              nostrClient: mockNostrClient,
              localStorage: mockLocalStorage,
            );

            final result = await repositoryWithCache.getVideosByIds(
              ['cached-id', 'relay-id'],
              cacheResults: true,
            );

            expect(result, hasLength(2));
            // Preserves input order
            expect(result[0].id, equals('cached-id'));
            expect(result[1].id, equals('relay-id'));
            // Should query relay for missing event
            verify(() => mockNostrClient.queryEvents(any())).called(1);
          },
        );

        test(
          'saves fetched events to cache when cacheResults is true',
          () async {
            final relayEvent = _createVideoEvent(
              id: 'relay-id',
              pubkey: 'test-pubkey',
              videoUrl: 'https://example.com/relay.mp4',
              createdAt: 1704067200,
            );

            when(() => mockLocalStorage.getEventsByIds(any())).thenAnswer(
              (_) async => <Event>[],
            );
            when(() => mockNostrClient.queryEvents(any())).thenAnswer(
              (_) async => [relayEvent],
            );
            when(() => mockLocalStorage.saveEventsBatch(any())).thenAnswer(
              (_) async {},
            );

            final repositoryWithCache = VideosRepository(
              nostrClient: mockNostrClient,
              localStorage: mockLocalStorage,
            );

            await repositoryWithCache.getVideosByIds(
              ['relay-id'],
              cacheResults: true,
            );

            verify(
              () => mockLocalStorage.saveEventsBatch([relayEvent]),
            ).called(1);
          },
        );

        test(
          'does not save to cache when cacheResults is false',
          () async {
            final relayEvent = _createVideoEvent(
              id: 'relay-id',
              pubkey: 'test-pubkey',
              videoUrl: 'https://example.com/relay.mp4',
              createdAt: 1704067200,
            );

            when(() => mockLocalStorage.getEventsByIds(any())).thenAnswer(
              (_) async => <Event>[],
            );
            when(() => mockNostrClient.queryEvents(any())).thenAnswer(
              (_) async => [relayEvent],
            );

            final repositoryWithCache = VideosRepository(
              nostrClient: mockNostrClient,
              localStorage: mockLocalStorage,
            );

            await repositoryWithCache.getVideosByIds(['relay-id']);

            verifyNever(() => mockLocalStorage.saveEventsBatch(any()));
          },
        );
      });

      group('getVideosByAddressableIds with localStorage', () {
        test(
          'saves fetched events to cache when cacheResults is true',
          () async {
            final relayEvent = _createVideoEvent(
              id: 'dtag1',
              pubkey: 'pubkey1',
              videoUrl: 'https://example.com/video.mp4',
              createdAt: 1704067200,
            );

            when(() => mockNostrClient.queryEvents(any())).thenAnswer(
              (_) async => [relayEvent],
            );
            when(() => mockLocalStorage.saveEventsBatch(any())).thenAnswer(
              (_) async {},
            );

            final repositoryWithCache = VideosRepository(
              nostrClient: mockNostrClient,
              localStorage: mockLocalStorage,
            );

            await repositoryWithCache.getVideosByAddressableIds(
              ['${EventKind.videoVertical}:pubkey1:dtag1'],
              cacheResults: true,
            );

            verify(
              () => mockLocalStorage.saveEventsBatch([relayEvent]),
            ).called(1);
          },
        );

        test(
          'does not save to cache when cacheResults is false',
          () async {
            final relayEvent = _createVideoEvent(
              id: 'dtag1',
              pubkey: 'pubkey1',
              videoUrl: 'https://example.com/video.mp4',
              createdAt: 1704067200,
            );

            when(() => mockNostrClient.queryEvents(any())).thenAnswer(
              (_) async => [relayEvent],
            );

            final repositoryWithCache = VideosRepository(
              nostrClient: mockNostrClient,
              localStorage: mockLocalStorage,
            );

            await repositoryWithCache.getVideosByAddressableIds(
              ['${EventKind.videoVertical}:pubkey1:dtag1'],
            );

            verifyNever(() => mockLocalStorage.saveEventsBatch(any()));
          },
        );

        test(
          'does not save to cache when no events are fetched',
          () async {
            when(() => mockNostrClient.queryEvents(any())).thenAnswer(
              (_) async => <Event>[],
            );

            final repositoryWithCache = VideosRepository(
              nostrClient: mockNostrClient,
              localStorage: mockLocalStorage,
            );

            await repositoryWithCache.getVideosByAddressableIds(
              ['${EventKind.videoVertical}:pubkey1:dtag1'],
              cacheResults: true,
            );

            verifyNever(() => mockLocalStorage.saveEventsBatch(any()));
          },
        );
      });
    });

    group('getCollabVideos', () {
      test('returns videos from relay fallback when no Funnelcake', () async {
        final event = _createVideoEvent(
          id: 'collab-video-1',
          pubkey: 'author-pubkey',
          videoUrl: 'https://example.com/collab.mp4',
          createdAt: 1704067200,
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [event],
        );

        final result = await repository.getCollabVideos(
          taggedPubkey: 'collab-pubkey',
        );

        expect(result, hasLength(1));
        expect(result.first.id, equals('collab-video-1'));

        final captured = verify(
          () => mockNostrClient.queryEvents(captureAny()),
        ).captured;
        final filters = captured.first as List<Filter>;
        expect(filters.first.kinds, contains(EventKind.videoVertical));
        expect(filters.first.p, equals(['collab-pubkey']));
      });

      test('passes limit and until to relay query', () async {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => <Event>[],
        );

        await repository.getCollabVideos(
          taggedPubkey: 'collab-pubkey',
          limit: 10,
          until: 1704067200,
        );

        final captured = verify(
          () => mockNostrClient.queryEvents(captureAny()),
        ).captured;
        final filters = captured.first as List<Filter>;
        expect(filters.first.limit, equals(10));
        expect(filters.first.until, equals(1704067200));
      });

      test('uses default limit of 5', () async {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => <Event>[],
        );

        await repository.getCollabVideos(taggedPubkey: 'collab-pubkey');

        final captured = verify(
          () => mockNostrClient.queryEvents(captureAny()),
        ).captured;
        final filters = captured.first as List<Filter>;
        expect(filters.first.limit, equals(5));
      });

      test('returns empty list when no events found', () async {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => <Event>[],
        );

        final result = await repository.getCollabVideos(
          taggedPubkey: 'collab-pubkey',
        );

        expect(result, isEmpty);
      });

      group('Funnelcake API first', () {
        late MockFunnelcakeApiClient mockFunnelcakeClient;

        setUp(() {
          mockFunnelcakeClient = MockFunnelcakeApiClient();
        });

        test('returns API results when Funnelcake succeeds', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getCollabVideos(
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => [
              _createVideoStats(
                id: 'collab-event-1',
                pubkey: 'author-pubkey',
                dTag: 'dtag-1',
                videoUrl: 'https://example.com/collab.mp4',
              ),
            ],
          );

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repositoryWithApi.getCollabVideos(
            taggedPubkey: 'collab-pubkey',
          );

          expect(result, hasLength(1));
          expect(
            result.first.videoUrl,
            equals('https://example.com/collab.mp4'),
          );
          verifyNever(() => mockNostrClient.queryEvents(any()));
        });

        test('passes parameters to Funnelcake API', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getCollabVideos(
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => [
              _createVideoStats(
                id: 'collab-event-1',
                pubkey: 'author-pubkey',
                dTag: 'dtag-1',
                videoUrl: 'https://example.com/collab.mp4',
              ),
            ],
          );

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          await repositoryWithApi.getCollabVideos(
            taggedPubkey: 'collab-pubkey',
            limit: 10,
            until: 1704067200,
          );

          verify(
            () => mockFunnelcakeClient.getCollabVideos(
              pubkey: 'collab-pubkey',
              limit: 10,
              before: 1704067200,
            ),
          ).called(1);
        });

        test('falls back to relay when Funnelcake throws', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getCollabVideos(
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenThrow(
            const FunnelcakeException('Server error'),
          );

          final event = _createVideoEvent(
            id: 'relay-collab-1',
            pubkey: 'author-pubkey',
            videoUrl: 'https://example.com/relay-collab.mp4',
            createdAt: 1704067200,
          );

          when(() => mockNostrClient.queryEvents(any())).thenAnswer(
            (_) async => [event],
          );

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          final result = await repositoryWithApi.getCollabVideos(
            taggedPubkey: 'collab-pubkey',
          );

          expect(result, hasLength(1));
          expect(result.first.id, equals('relay-collab-1'));
          verify(() => mockNostrClient.queryEvents(any())).called(1);
        });

        test('falls back to relay when Funnelcake returns empty', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getCollabVideos(
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer((_) async => <VideoStats>[]);

          when(() => mockNostrClient.queryEvents(any())).thenAnswer(
            (_) async => <Event>[],
          );

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          await repositoryWithApi.getCollabVideos(
            taggedPubkey: 'collab-pubkey',
          );

          verify(() => mockNostrClient.queryEvents(any())).called(1);
        });

        test('falls back to relay when Funnelcake not available', () async {
          when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

          when(() => mockNostrClient.queryEvents(any())).thenAnswer(
            (_) async => <Event>[],
          );

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
          );

          await repositoryWithApi.getCollabVideos(
            taggedPubkey: 'collab-pubkey',
          );

          verifyNever(
            () => mockFunnelcakeClient.getCollabVideos(
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          );
          verify(() => mockNostrClient.queryEvents(any())).called(1);
        });

        test('filters blocked pubkeys from API results', () async {
          final blockFilter = TestContentFilter(
            blockedPubkeys: {'blocked-author'},
          );

          when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
          when(
            () => mockFunnelcakeClient.getCollabVideos(
              pubkey: any(named: 'pubkey'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => [
              _createVideoStats(
                id: 'allowed-video',
                pubkey: 'good-author',
                dTag: 'dtag-1',
                videoUrl: 'https://example.com/good.mp4',
              ),
              _createVideoStats(
                id: 'blocked-video',
                pubkey: 'blocked-author',
                dTag: 'dtag-2',
                videoUrl: 'https://example.com/blocked.mp4',
              ),
            ],
          );

          final repositoryWithApi = VideosRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: mockFunnelcakeClient,
            blockFilter: blockFilter.call,
          );

          final result = await repositoryWithApi.getCollabVideos(
            taggedPubkey: 'collab-pubkey',
          );

          expect(result, hasLength(1));
          expect(result.first.id, equals('allowed-video'));
        });
      });
    });

    group('getVideosByLoops', () {
      late MockFunnelcakeApiClient mockFunnelcakeClient;

      setUp(() {
        mockFunnelcakeClient = MockFunnelcakeApiClient();
      });

      test('returns videos from Funnelcake API', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getVideosByLoops(
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer(
          (_) async => [
            _createVideoStats(
              id: 'event-1',
              pubkey: 'pubkey-1',
              dTag: 'dtag-1',
              videoUrl: 'https://example.com/video.mp4',
              loops: 100,
            ),
          ],
        );

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.getVideosByLoops();

        expect(result, hasLength(1));
        verify(
          () => mockFunnelcakeClient.getVideosByLoops(
            limit: 20,
          ),
        ).called(1);
      });

      test('returns empty list when API unavailable', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.getVideosByLoops();

        expect(result, isEmpty);
        verifyNever(
          () => mockFunnelcakeClient.getVideosByLoops(
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        );
      });

      test('returns empty list when API client is null', () async {
        final result = await repository.getVideosByLoops();

        expect(result, isEmpty);
      });

      test('propagates $FunnelcakeApiException', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getVideosByLoops(
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenThrow(
          const FunnelcakeApiException(
            message: 'error',
            statusCode: 500,
          ),
        );

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        expect(
          repo.getVideosByLoops,
          throwsA(isA<FunnelcakeApiException>()),
        );
      });

      test('applies block filter to results', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getVideosByLoops(
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer(
          (_) async => [
            _createVideoStats(
              id: 'event-1',
              pubkey: 'blocked-pubkey',
              dTag: 'dtag-1',
              videoUrl: 'https://example.com/video.mp4',
            ),
            _createVideoStats(
              id: 'event-2',
              pubkey: 'allowed-pubkey',
              dTag: 'dtag-2',
              videoUrl: 'https://example.com/video2.mp4',
            ),
          ],
        );

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
          blockFilter: (pubkey) => pubkey == 'blocked-pubkey',
        );

        final result = await repo.getVideosByLoops();

        expect(result, hasLength(1));
        expect(result.first.pubkey, equals('allowed-pubkey'));
      });

      test('passes parameters correctly', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getVideosByLoops(
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer((_) async => []);

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        await repo.getVideosByLoops(limit: 30, before: 1704067200);

        verify(
          () => mockFunnelcakeClient.getVideosByLoops(
            limit: 30,
            before: 1704067200,
          ),
        ).called(1);
      });
    });

    group('getVideosByHashtag', () {
      late MockFunnelcakeApiClient mockFunnelcakeClient;

      setUp(() {
        mockFunnelcakeClient = MockFunnelcakeApiClient();
      });

      test('returns videos from Funnelcake API', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getVideosByHashtag(
            hashtag: any(named: 'hashtag'),
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer(
          (_) async => [
            _createVideoStats(
              id: 'event-1',
              pubkey: 'pubkey-1',
              dTag: 'dtag-1',
              videoUrl: 'https://example.com/video.mp4',
            ),
          ],
        );

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.getVideosByHashtag(hashtag: 'bitcoin');

        expect(result, hasLength(1));
      });

      test('returns empty list when API unavailable', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.getVideosByHashtag(hashtag: 'bitcoin');

        expect(result, isEmpty);
      });

      test('returns empty list when API client is null', () async {
        final result = await repository.getVideosByHashtag(hashtag: 'bitcoin');

        expect(result, isEmpty);
      });

      test('propagates $FunnelcakeApiException', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getVideosByHashtag(
            hashtag: any(named: 'hashtag'),
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenThrow(
          const FunnelcakeApiException(
            message: 'error',
            statusCode: 500,
          ),
        );

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        expect(
          () => repo.getVideosByHashtag(hashtag: 'bitcoin'),
          throwsA(isA<FunnelcakeApiException>()),
        );
      });

      test('passes parameters correctly', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getVideosByHashtag(
            hashtag: any(named: 'hashtag'),
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer((_) async => []);

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        await repo.getVideosByHashtag(
          hashtag: 'nostr',
          limit: 30,
          before: 1704067200,
        );

        verify(
          () => mockFunnelcakeClient.getVideosByHashtag(
            hashtag: 'nostr',
            limit: 30,
            before: 1704067200,
          ),
        ).called(1);
      });
    });

    group('getClassicVideosByHashtag', () {
      late MockFunnelcakeApiClient mockFunnelcakeClient;

      setUp(() {
        mockFunnelcakeClient = MockFunnelcakeApiClient();
      });

      test('returns videos from Funnelcake API', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getClassicVideosByHashtag(
            hashtag: any(named: 'hashtag'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => [
            _createVideoStats(
              id: 'event-1',
              pubkey: 'pubkey-1',
              dTag: 'dtag-1',
              videoUrl: 'https://example.com/video.mp4',
            ),
          ],
        );

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.getClassicVideosByHashtag(
          hashtag: 'bitcoin',
        );

        expect(result, hasLength(1));
      });

      test('returns empty list when API unavailable', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.getClassicVideosByHashtag(
          hashtag: 'bitcoin',
        );

        expect(result, isEmpty);
      });

      test('returns empty list when API client is null', () async {
        final result = await repository.getClassicVideosByHashtag(
          hashtag: 'bitcoin',
        );

        expect(result, isEmpty);
      });

      test('propagates $FunnelcakeApiException', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getClassicVideosByHashtag(
            hashtag: any(named: 'hashtag'),
            limit: any(named: 'limit'),
          ),
        ).thenThrow(
          const FunnelcakeApiException(
            message: 'error',
            statusCode: 500,
          ),
        );

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        expect(
          () => repo.getClassicVideosByHashtag(hashtag: 'bitcoin'),
          throwsA(isA<FunnelcakeApiException>()),
        );
      });
    });

    group('searchVideos', () {
      late MockFunnelcakeApiClient mockFunnelcakeClient;

      setUp(() {
        mockFunnelcakeClient = MockFunnelcakeApiClient();
      });

      test('returns videos from Funnelcake API', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.searchVideos(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => [
            _createVideoStats(
              id: 'event-1',
              pubkey: 'pubkey-1',
              dTag: 'dtag-1',
              videoUrl: 'https://example.com/video.mp4',
            ),
          ],
        );

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.searchVideos(query: 'cats');

        expect(result, hasLength(1));
      });

      test('returns empty list when API unavailable', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.searchVideos(query: 'cats');

        expect(result, isEmpty);
      });

      test('returns empty list when API client is null', () async {
        final result = await repository.searchVideos(query: 'cats');

        expect(result, isEmpty);
      });

      test('propagates $FunnelcakeApiException', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.searchVideos(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
          ),
        ).thenThrow(
          const FunnelcakeApiException(
            message: 'error',
            statusCode: 500,
          ),
        );

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        expect(
          () => repo.searchVideos(query: 'cats'),
          throwsA(isA<FunnelcakeApiException>()),
        );
      });

      test('passes parameters correctly', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.searchVideos(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => []);

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        await repo.searchVideos(query: 'funny', limit: 30);

        verify(
          () => mockFunnelcakeClient.searchVideos(query: 'funny', limit: 30),
        ).called(1);
      });
    });

    group('getClassicVines', () {
      late MockFunnelcakeApiClient mockFunnelcakeClient;

      setUp(() {
        mockFunnelcakeClient = MockFunnelcakeApiClient();
      });

      test('returns videos from Funnelcake API', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getClassicVines(
            sort: any(named: 'sort'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            before: any(named: 'before'),
          ),
        ).thenAnswer(
          (_) async => [
            _createVideoStats(
              id: 'event-1',
              pubkey: 'pubkey-1',
              dTag: 'dtag-1',
              videoUrl: 'https://example.com/video.mp4',
            ),
          ],
        );

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.getClassicVines();

        expect(result, hasLength(1));
      });

      test('returns empty list when API unavailable', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.getClassicVines();

        expect(result, isEmpty);
      });

      test('returns empty list when API client is null', () async {
        final result = await repository.getClassicVines();

        expect(result, isEmpty);
      });

      test('propagates FunnelcakeException', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getClassicVines(
            sort: any(named: 'sort'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            before: any(named: 'before'),
          ),
        ).thenThrow(const FunnelcakeException('error'));

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        expect(
          repo.getClassicVines,
          throwsA(isA<FunnelcakeException>()),
        );
      });

      test('passes parameters correctly', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getClassicVines(
            sort: any(named: 'sort'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            before: any(named: 'before'),
          ),
        ).thenAnswer((_) async => []);

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        await repo.getClassicVines(
          sort: 'recent',
          limit: 30,
          offset: 10,
          before: 1704067200,
        );

        verify(
          () => mockFunnelcakeClient.getClassicVines(
            sort: 'recent',
            limit: 30,
            offset: 10,
            before: 1704067200,
          ),
        ).called(1);
      });
    });

    group('getVideosByAuthor', () {
      late MockFunnelcakeApiClient mockFunnelcakeClient;

      setUp(() {
        mockFunnelcakeClient = MockFunnelcakeApiClient();
      });

      test('returns videos from Funnelcake API', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getVideosByAuthor(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer(
          (_) async => [
            _createVideoStats(
              id: 'event-1',
              pubkey: 'author-pubkey',
              dTag: 'dtag-1',
              videoUrl: 'https://example.com/video.mp4',
            ),
          ],
        );

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.getVideosByAuthor(pubkey: 'author-pubkey');

        expect(result, hasLength(1));
      });

      test('returns empty list when API unavailable', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.getVideosByAuthor(pubkey: 'author-pubkey');

        expect(result, isEmpty);
      });

      test('returns empty list when API client is null', () async {
        final result = await repository.getVideosByAuthor(
          pubkey: 'author-pubkey',
        );

        expect(result, isEmpty);
      });

      test('propagates FunnelcakeException', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getVideosByAuthor(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenThrow(const FunnelcakeException('error'));

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        expect(
          () => repo.getVideosByAuthor(pubkey: 'author-pubkey'),
          throwsA(isA<FunnelcakeException>()),
        );
      });

      test('passes parameters correctly', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getVideosByAuthor(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer((_) async => []);

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        await repo.getVideosByAuthor(
          pubkey: 'author-pubkey',
          limit: 30,
          before: 1704067200,
        );

        verify(
          () => mockFunnelcakeClient.getVideosByAuthor(
            pubkey: 'author-pubkey',
            limit: 30,
            before: 1704067200,
          ),
        ).called(1);
      });
    });

    group('getVideoStats', () {
      late MockFunnelcakeApiClient mockFunnelcakeClient;

      setUp(() {
        mockFunnelcakeClient = MockFunnelcakeApiClient();
      });

      test('returns VideoStats on success', () async {
        final testStats = _createVideoStats(
          id: 'event-1',
          pubkey: 'pubkey-1',
          dTag: 'dtag-1',
          videoUrl: 'https://example.com/video.mp4',
          loops: 42,
        );

        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getVideoStats('event-1'),
        ).thenAnswer((_) async => testStats);

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.getVideoStats('event-1');

        expect(result, isNotNull);
        expect(result!.loops, equals(42));
      });

      test('returns null when API unavailable', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.getVideoStats('event-1');

        expect(result, isNull);
      });

      test('returns null when API client is null', () async {
        final result = await repository.getVideoStats('event-1');

        expect(result, isNull);
      });

      test('propagates FunnelcakeException', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getVideoStats(any()),
        ).thenThrow(const FunnelcakeException('error'));

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        expect(
          () => repo.getVideoStats('event-1'),
          throwsA(isA<FunnelcakeException>()),
        );
      });
    });

    group('getVideoViews', () {
      late MockFunnelcakeApiClient mockFunnelcakeClient;

      setUp(() {
        mockFunnelcakeClient = MockFunnelcakeApiClient();
      });

      test('returns view count on success', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getVideoViews('event-1'),
        ).thenAnswer((_) async => 1234);

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.getVideoViews('event-1');

        expect(result, equals(1234));
      });

      test('returns null when API unavailable', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.getVideoViews('event-1');

        expect(result, isNull);
      });

      test('returns null when API client is null', () async {
        final result = await repository.getVideoViews('event-1');

        expect(result, isNull);
      });

      test('propagates FunnelcakeException', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getVideoViews(any()),
        ).thenThrow(const FunnelcakeException('error'));

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        expect(
          () => repo.getVideoViews('event-1'),
          throwsA(isA<FunnelcakeException>()),
        );
      });
    });

    group('getBulkVideoStats', () {
      late MockFunnelcakeApiClient mockFunnelcakeClient;

      setUp(() {
        mockFunnelcakeClient = MockFunnelcakeApiClient();
      });

      test('returns BulkVideoStatsResponse on success', () async {
        const testResponse = BulkVideoStatsResponse(
          stats: {
            'event-1': BulkVideoStatsEntry(
              eventId: 'event-1',
              reactions: 10,
              comments: 5,
              reposts: 2,
            ),
          },
        );

        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getBulkVideoStats(['event-1']),
        ).thenAnswer((_) async => testResponse);

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.getBulkVideoStats(['event-1']);

        expect(result, isNotNull);
        expect(result!.stats, hasLength(1));
      });

      test('returns null when API unavailable', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.getBulkVideoStats(['event-1']);

        expect(result, isNull);
      });

      test('returns null when API client is null', () async {
        final result = await repository.getBulkVideoStats(['event-1']);

        expect(result, isNull);
      });

      test('propagates FunnelcakeException', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getBulkVideoStats(any()),
        ).thenThrow(const FunnelcakeException('error'));

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        expect(
          () => repo.getBulkVideoStats(['event-1']),
          throwsA(isA<FunnelcakeException>()),
        );
      });
    });

    group('getRecommendations', () {
      late MockFunnelcakeApiClient mockFunnelcakeClient;

      setUp(() {
        mockFunnelcakeClient = MockFunnelcakeApiClient();
      });

      test('returns RecommendationsResponse on success', () async {
        final testStats = _createVideoStats(
          id: 'event-1',
          pubkey: 'pubkey-1',
          dTag: 'dtag-1',
          videoUrl: 'https://example.com/video.mp4',
        );
        final testResponse = RecommendationsResponse(
          videos: [testStats],
          source: 'popular',
        );

        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getRecommendations(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
            fallback: any(named: 'fallback'),
            category: any(named: 'category'),
          ),
        ).thenAnswer((_) async => testResponse);

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.getRecommendations(pubkey: 'user-pubkey');

        expect(result, isNotNull);
        expect(result!.videos, hasLength(1));
        expect(result.source, equals('popular'));
      });

      test('returns null when API unavailable', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        final result = await repo.getRecommendations(pubkey: 'user-pubkey');

        expect(result, isNull);
      });

      test('returns null when API client is null', () async {
        final result = await repository.getRecommendations(
          pubkey: 'user-pubkey',
        );

        expect(result, isNull);
      });

      test('propagates FunnelcakeException', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getRecommendations(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
            fallback: any(named: 'fallback'),
            category: any(named: 'category'),
          ),
        ).thenThrow(const FunnelcakeException('error'));

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        expect(
          () => repo.getRecommendations(pubkey: 'user-pubkey'),
          throwsA(isA<FunnelcakeException>()),
        );
      });

      test('passes parameters correctly', () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getRecommendations(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
            fallback: any(named: 'fallback'),
            category: any(named: 'category'),
          ),
        ).thenAnswer(
          (_) async => const RecommendationsResponse(
            videos: [],
            source: 'category',
          ),
        );

        final repo = VideosRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: mockFunnelcakeClient,
        );

        await repo.getRecommendations(
          pubkey: 'user-pubkey',
          limit: 50,
          fallback: 'recent',
          category: 'sports',
        );

        verify(
          () => mockFunnelcakeClient.getRecommendations(
            pubkey: 'user-pubkey',
            limit: 50,
            fallback: 'recent',
            category: 'sports',
          ),
        ).called(1);
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

/// Creates a mock VideoStats for testing Funnelcake API fallback.
VideoStats _createVideoStats({
  required String id,
  required String pubkey,
  required String dTag,
  required String videoUrl,
  String title = 'Test Video',
  String thumbnail = 'https://example.com/thumb.jpg',
  int? loops,
}) {
  return VideoStats(
    id: id,
    pubkey: pubkey,
    createdAt: DateTime.fromMillisecondsSinceEpoch(1704067200 * 1000),
    kind: EventKind.videoVertical,
    dTag: dTag,
    title: title,
    thumbnail: thumbnail,
    videoUrl: videoUrl,
    reactions: 0,
    comments: 0,
    reposts: 0,
    engagementScore: 0,
    loops: loops,
  );
}
