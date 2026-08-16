import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/creator_analytics/creator_analytics_repository.dart';

class MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

VideoEvent _video({
  required String id,
  int? loops,
  Map<String, String> rawTags = const {},
}) {
  return VideoEvent(
    id: id,
    pubkey: 'pubkey',
    createdAt: 1739350000,
    content: 'content',
    timestamp: DateTime.fromMillisecondsSinceEpoch(1739350000 * 1000),
    title: id,
    rawTags: rawTags,
    originalLoops: loops,
    originalLikes: 2,
    originalComments: 1,
    originalReposts: 0,
  );
}

VideoStats _videoStats({
  required String id,
  required String pubkey,
  String? dTag,
  int createdAtSeconds = 1739350000,
  int reactions = 2,
  int comments = 1,
  int reposts = 0,
  int? loops,
  int? views,
  Map<String, String> rawTags = const {},
}) {
  return VideoStats(
    id: id,
    pubkey: pubkey,
    createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtSeconds * 1000),
    kind: 34236,
    dTag: dTag ?? id,
    title: id,
    thumbnail: 'thumb',
    videoUrl: 'videoUrl',
    reactions: reactions,
    comments: comments,
    reposts: reposts,
    engagementScore: reactions + comments + reposts,
    loops: loops,
    views: views,
    rawTags: rawTags,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue('');
    registerFallbackValue(<String>[]);
  });

  group('extractViewLikeCount', () {
    test('prefers explicit views tag', () {
      final event = _video(id: 'v1', rawTags: const {'views': '55'}, loops: 9);
      expect(extractViewLikeCount(event), 55);
    });

    test('falls back to loops/originalLoops', () {
      final event = _video(id: 'v2', rawTags: const {'loops': '44'});
      expect(extractViewLikeCount(event), 44);
    });

    test('returns null when no view-like value exists', () {
      final event = _video(id: 'v3');
      expect(extractViewLikeCount(event), isNull);
    });
  });

  group('FunnelcakeCreatorAnalyticsRepository', () {
    test('hydrates views and live engagement from bulk stats', () async {
      const pubkey = 'pubkey';
      final api = MockFunnelcakeApiClient();

      when(() => api.isAvailable).thenReturn(true);
      when(() => api.getSocialCounts(pubkey)).thenAnswer((_) async => null);
      when(() => api.getVideoViews(any())).thenAnswer((_) async => 0);
      when(() => api.getBulkVideoStats(any())).thenAnswer((invocation) async {
        final ids = invocation.positionalArguments[0] as List<String>;
        if (ids.length == 1 && ids.first == 'a') {
          return const BulkVideoStatsResponse(
            stats: {
              'a': BulkVideoStatsEntry(
                eventId: 'a',
                reactions: 4,
                comments: 2,
                reposts: 1,
                loops: 12,
                views: 15,
              ),
            },
          );
        }
        return const BulkVideoStatsResponse(stats: {});
      });

      when(
        () => api.getVideosByAuthor(
          pubkey: pubkey,
          limit: 100,
          before: any(named: 'before'),
        ),
      ).thenAnswer(
        (_) async => VideosByAuthorResponse(
          videos: [
            _videoStats(id: 'a', pubkey: pubkey, reactions: 0, comments: 0),
          ],
        ),
      );

      final repo = FunnelcakeCreatorAnalyticsRepository(api);
      final snapshot = await repo.fetchCreatorAnalytics('pubkey');

      expect(snapshot.diagnostics.totalVideos, 1);
      expect(snapshot.diagnostics.videosHydratedByBulkStats, 1);
      expect(snapshot.diagnostics.videosHydratedByViewsEndpoint, 0);
      expect(snapshot.diagnostics.videosWithAnyViews, 1);
      expect(snapshot.diagnostics.videosMissingViews, 0);
      expect(snapshot.videos.first.rawTags['views'], '15');
      expect(snapshot.videos.first.originalLikes, isNull);
      expect(snapshot.videos.first.originalComments, isNull);
      expect(snapshot.videos.first.originalReposts, isNull);
      expect(snapshot.videos.first.nostrLikeCount, 4);
      expect(snapshot.videos.first.nostrCommentCount, 2);
      expect(snapshot.videos.first.nostrRepostCount, 1);
    });

    test(
      'hydrates views from /views endpoint when bulk stats missing',
      () async {
        const pubkey = 'pubkey';
        final api = MockFunnelcakeApiClient();

        when(() => api.isAvailable).thenReturn(true);
        when(() => api.getSocialCounts(pubkey)).thenAnswer((_) async => null);

        when(
          () => api.getBulkVideoStats(any()),
        ).thenAnswer((_) async => const BulkVideoStatsResponse(stats: {}));
        when(() => api.getVideoViews(any())).thenAnswer((invocation) async {
          final eventId = invocation.positionalArguments[0] as String;
          return eventId == 'b' ? 21 : 0;
        });

        when(
          () => api.getVideosByAuthor(
            pubkey: pubkey,
            limit: 100,
            before: any(named: 'before'),
          ),
        ).thenAnswer(
          (_) async => VideosByAuthorResponse(
            videos: [_videoStats(id: 'b', pubkey: pubkey)],
          ),
        );

        final repo = FunnelcakeCreatorAnalyticsRepository(api);
        final snapshot = await repo.fetchCreatorAnalytics('pubkey');

        expect(snapshot.diagnostics.totalVideos, 1);
        expect(snapshot.diagnostics.videosHydratedByBulkStats, 0);
        expect(snapshot.diagnostics.videosHydratedByViewsEndpoint, 1);
        expect(snapshot.diagnostics.videosWithAnyViews, 1);
        expect(snapshot.diagnostics.videosMissingViews, 0);
        expect(snapshot.videos.first.rawTags['views'], '21');
      },
    );

    test(
      'hydrates views from /views endpoint when endpoint returns 0',
      () async {
        const pubkey = 'pubkey';
        final api = MockFunnelcakeApiClient();

        when(() => api.isAvailable).thenReturn(true);
        when(() => api.getSocialCounts(pubkey)).thenAnswer((_) async => null);

        when(
          () => api.getBulkVideoStats(any()),
        ).thenAnswer((_) async => const BulkVideoStatsResponse(stats: {}));
        when(() => api.getVideoViews(any())).thenAnswer((invocation) async {
          final eventId = invocation.positionalArguments[0] as String;
          return eventId == 'c' ? 0 : 0;
        });

        when(
          () => api.getVideosByAuthor(
            pubkey: pubkey,
            limit: 100,
            before: any(named: 'before'),
          ),
        ).thenAnswer(
          (_) async => VideosByAuthorResponse(
            videos: [_videoStats(id: 'c', pubkey: pubkey)],
          ),
        );

        final repo = FunnelcakeCreatorAnalyticsRepository(api);
        final snapshot = await repo.fetchCreatorAnalytics('pubkey');

        expect(snapshot.diagnostics.totalVideos, 1);
        expect(snapshot.diagnostics.videosHydratedByBulkStats, 0);
        expect(snapshot.diagnostics.videosHydratedByViewsEndpoint, 1);
        expect(snapshot.diagnostics.videosWithAnyViews, 1);
        expect(snapshot.diagnostics.videosMissingViews, 0);
        expect(snapshot.videos.first.rawTags['views'], '0');
      },
    );

    test(
      'collapses edit siblings after hydration so higher counts survive',
      () async {
        const pubkey = 'pubkey';
        final api = MockFunnelcakeApiClient();

        when(() => api.isAvailable).thenReturn(true);
        when(() => api.getSocialCounts(pubkey)).thenAnswer((_) async => null);
        when(() => api.getVideoViews(any())).thenAnswer((_) async => 0);
        // Per-event-id stats: the older edit accumulated more views while it
        // was live than the newer edit has since.
        when(() => api.getBulkVideoStats(any())).thenAnswer((invocation) async {
          final ids = invocation.positionalArguments[0] as List<String>;
          return BulkVideoStatsResponse(
            stats: {
              for (final id in ids)
                id: BulkVideoStatsEntry(
                  eventId: id,
                  reactions: 0,
                  comments: 0,
                  reposts: 0,
                  loops: 0,
                  views: id == 'older-event' ? 1000 : 5,
                ),
            },
          );
        });

        when(
          () => api.getVideosByAuthor(
            pubkey: pubkey,
            limit: 100,
            before: any(named: 'before'),
          ),
        ).thenAnswer(
          (_) async => VideosByAuthorResponse(
            videos: [
              _videoStats(
                id: 'older-event',
                pubkey: pubkey,
                dTag: 'same-video',
              ),
              _videoStats(
                id: 'newer-event',
                pubkey: pubkey,
                dTag: 'same-video',
                createdAtSeconds: 1739350100,
              ),
            ],
          ),
        );

        final repo = FunnelcakeCreatorAnalyticsRepository(api);
        final snapshot = await repo.fetchCreatorAnalytics(pubkey);

        // Both edit siblings collapse to one video keyed on the newest event
        // id, but stats are hydrated for every sibling BEFORE the collapse, so
        // the max-merge keeps the older edit's higher view count.
        expect(snapshot.diagnostics.totalVideos, 1);
        expect(snapshot.videos.single.id, 'newer-event');
        expect(snapshot.videos.single.rawTags['views'], '1000');
        verify(
          () => api.getBulkVideoStats(['older-event', 'newer-event']),
        ).called(1);
      },
    );

    test('excludes collaborator rows leaked by author endpoint', () async {
      const pubkey = 'pubkey';
      final api = MockFunnelcakeApiClient();

      when(() => api.isAvailable).thenReturn(true);
      when(() => api.getSocialCounts(pubkey)).thenAnswer((_) async => null);
      when(
        () => api.getBulkVideoStats(any()),
      ).thenAnswer((_) async => const BulkVideoStatsResponse(stats: {}));
      when(() => api.getVideoViews(any())).thenAnswer((_) async => 0);

      when(
        () => api.getVideosByAuthor(
          pubkey: pubkey,
          limit: 100,
          before: any(named: 'before'),
        ),
      ).thenAnswer(
        (_) async => VideosByAuthorResponse(
          videos: [
            _videoStats(id: 'authored', pubkey: pubkey),
            _videoStats(id: 'collaborator-leak', pubkey: 'collaborator-pubkey'),
          ],
        ),
      );

      final repo = FunnelcakeCreatorAnalyticsRepository(api);
      final snapshot = await repo.fetchCreatorAnalytics(pubkey);

      expect(snapshot.diagnostics.totalVideos, 1);
      expect(snapshot.videos.single.id, 'authored');
      // Bulk stats are batched into one call, so a filter regression would
      // surface as ['authored', 'collaborator-leak'] here — assert the exact
      // surviving-id list rather than the (unreachable) single-leak list.
      verify(() => api.getBulkVideoStats(['authored'])).called(1);
      verifyNever(() => api.getVideoViews('collaborator-leak'));
    });

    test(
      'continues pagination when a full raw page contains expired videos',
      () async {
        const pubkey = 'pubkey';
        final api = MockFunnelcakeApiClient();
        var calls = 0;
        final expiredAt =
            (DateTime.now().millisecondsSinceEpoch ~/ 1000) - 3600;

        when(() => api.isAvailable).thenReturn(true);
        when(() => api.getSocialCounts(pubkey)).thenAnswer((_) async => null);
        when(
          () => api.getBulkVideoStats(any()),
        ).thenAnswer((_) async => const BulkVideoStatsResponse(stats: {}));
        when(() => api.getVideoViews(any())).thenAnswer((_) async => 0);
        when(
          () => api.getVideosByAuthor(
            pubkey: pubkey,
            limit: 100,
            before: any(named: 'before'),
          ),
        ).thenAnswer((_) async {
          calls++;
          if (calls == 1) {
            return VideosByAuthorResponse(
              videos: [
                for (var i = 0; i < 99; i++)
                  _videoStats(
                    id: 'page-1-$i',
                    pubkey: pubkey,
                    createdAtSeconds: 1739350000 - i,
                    views: 1,
                  ),
                _videoStats(
                  id: 'expired',
                  pubkey: pubkey,
                  createdAtSeconds: 1739349900,
                  views: 1,
                  rawTags: {'expiration': '$expiredAt'},
                ),
              ],
            );
          }
          return VideosByAuthorResponse(
            videos: [_videoStats(id: 'page-2', pubkey: pubkey, views: 1)],
            hasMore: false,
          );
        });

        final repo = FunnelcakeCreatorAnalyticsRepository(api);
        final snapshot = await repo.fetchCreatorAnalytics(pubkey);

        expect(snapshot.diagnostics.totalVideos, 100);
        expect(snapshot.videos.map((video) => video.id), contains('page-2'));
        expect(
          snapshot.videos.map((video) => video.id),
          isNot(contains('expired')),
        );
        expect(snapshot.diagnostics.videoCatalogTruncated, isFalse);
      },
    );

    test('marks diagnostics truncated when the page cap is reached', () async {
      const pubkey = 'pubkey';
      final api = MockFunnelcakeApiClient();
      var calls = 0;

      when(() => api.isAvailable).thenReturn(true);
      when(() => api.getSocialCounts(pubkey)).thenAnswer((_) async => null);
      when(
        () => api.getBulkVideoStats(any()),
      ).thenAnswer((_) async => const BulkVideoStatsResponse(stats: {}));
      when(() => api.getVideoViews(any())).thenAnswer((_) async => 0);
      when(
        () => api.getVideosByAuthor(
          pubkey: pubkey,
          limit: 100,
          before: any(named: 'before'),
        ),
      ).thenAnswer((_) async {
        final page = calls++;
        return VideosByAuthorResponse(
          videos: [
            for (var i = 0; i < 100; i++)
              _videoStats(
                id: 'page-$page-$i',
                pubkey: pubkey,
                createdAtSeconds: 1739350000 - (page * 100) - i,
                views: 1,
              ),
          ],
        );
      });

      final repo = FunnelcakeCreatorAnalyticsRepository(api);
      final snapshot = await repo.fetchCreatorAnalytics(pubkey);

      expect(snapshot.diagnostics.totalVideos, 400);
      expect(snapshot.diagnostics.videoCatalogTruncated, isTrue);
    });

    test('keeps author videos when bulk stats hydration fails', () async {
      const pubkey = 'pubkey';
      final api = MockFunnelcakeApiClient();

      when(() => api.isAvailable).thenReturn(true);
      when(() => api.getSocialCounts(pubkey)).thenAnswer((_) async => null);
      when(() => api.getBulkVideoStats(any())).thenThrow(
        const FunnelcakeApiException(
          message: 'bulk failed',
          statusCode: 500,
          url: 'https://api.divine.video/api/videos/stats/bulk',
        ),
      );
      when(() => api.getVideoViews(any())).thenThrow(
        const FunnelcakeApiException(message: 'views failed', statusCode: 500),
      );
      when(
        () => api.getVideosByAuthor(
          pubkey: pubkey,
          limit: 100,
          before: any(named: 'before'),
        ),
      ).thenAnswer(
        (_) async => VideosByAuthorResponse(
          videos: [_videoStats(id: 'bulk-failure-video', pubkey: pubkey)],
        ),
      );

      final repo = FunnelcakeCreatorAnalyticsRepository(api);
      final snapshot = await repo.fetchCreatorAnalytics(pubkey);

      expect(snapshot.videos.single.id, 'bulk-failure-video');
      expect(snapshot.diagnostics.videosWithAnyViews, 0);
      expect(snapshot.diagnostics.videosMissingViews, 1);
      expect(snapshot.diagnostics.videosHydratedByBulkStats, 0);
      expect(snapshot.diagnostics.failedSources, {
        AnalyticsDataSource.bulkVideoStats,
        AnalyticsDataSource.videoViewsEndpoint,
      });
    });

    test('keeps author videos when a video views request fails', () async {
      const pubkey = 'pubkey';
      final api = MockFunnelcakeApiClient();

      when(() => api.isAvailable).thenReturn(true);
      when(() => api.getSocialCounts(pubkey)).thenAnswer((_) async => null);
      when(
        () => api.getBulkVideoStats(any()),
      ).thenAnswer((_) async => const BulkVideoStatsResponse(stats: {}));
      when(() => api.getVideoViews('views-failure-video')).thenThrow(
        const FunnelcakeApiException(message: 'views failed', statusCode: 500),
      );
      when(
        () => api.getVideosByAuthor(
          pubkey: pubkey,
          limit: 100,
          before: any(named: 'before'),
        ),
      ).thenAnswer(
        (_) async => VideosByAuthorResponse(
          videos: [_videoStats(id: 'views-failure-video', pubkey: pubkey)],
        ),
      );

      final repo = FunnelcakeCreatorAnalyticsRepository(api);
      final snapshot = await repo.fetchCreatorAnalytics(pubkey);

      expect(snapshot.videos.single.id, 'views-failure-video');
      expect(snapshot.diagnostics.videosWithAnyViews, 0);
      expect(snapshot.diagnostics.videosMissingViews, 1);
      expect(snapshot.diagnostics.videosHydratedByViewsEndpoint, 0);
      expect(snapshot.diagnostics.failedSources, {
        AnalyticsDataSource.videoViewsEndpoint,
      });
    });

    test('hydrates remaining video views when one request fails', () async {
      const pubkey = 'pubkey';
      final api = MockFunnelcakeApiClient();

      when(() => api.isAvailable).thenReturn(true);
      when(() => api.getSocialCounts(pubkey)).thenAnswer((_) async => null);
      when(
        () => api.getBulkVideoStats(any()),
      ).thenAnswer((_) async => const BulkVideoStatsResponse(stats: {}));
      when(() => api.getVideoViews('bad-video')).thenThrow(
        const FunnelcakeApiException(message: 'views failed', statusCode: 500),
      );
      when(() => api.getVideoViews('good-video')).thenAnswer((_) async => 33);
      when(
        () => api.getVideosByAuthor(
          pubkey: pubkey,
          limit: 100,
          before: any(named: 'before'),
        ),
      ).thenAnswer(
        (_) async => VideosByAuthorResponse(
          videos: [
            _videoStats(id: 'bad-video', pubkey: pubkey),
            _videoStats(id: 'good-video', pubkey: pubkey),
          ],
        ),
      );

      final repo = FunnelcakeCreatorAnalyticsRepository(api);
      final snapshot = await repo.fetchCreatorAnalytics(pubkey);

      expect(snapshot.diagnostics.videosHydratedByViewsEndpoint, 1);
      expect(snapshot.diagnostics.videosWithAnyViews, 1);
      expect(snapshot.diagnostics.videosMissingViews, 1);
      expect(
        snapshot.videos
            .singleWhere((video) => video.id == 'good-video')
            .rawTags['views'],
        '33',
      );
      expect(snapshot.diagnostics.failedSources, {
        AnalyticsDataSource.videoViewsEndpoint,
      });
    });

    test(
      'keeps videos and nulls social counts when social counts fail',
      () async {
        const pubkey = 'pubkey';
        final api = MockFunnelcakeApiClient();

        when(() => api.isAvailable).thenReturn(true);
        when(() => api.getSocialCounts(pubkey)).thenThrow(
          const FunnelcakeApiException(
            message: 'social failed',
            statusCode: 500,
          ),
        );
        when(
          () => api.getBulkVideoStats(any()),
        ).thenAnswer((_) async => const BulkVideoStatsResponse(stats: {}));
        when(() => api.getVideoViews(any())).thenAnswer((_) async => 12);
        when(
          () => api.getVideosByAuthor(
            pubkey: pubkey,
            limit: 100,
            before: any(named: 'before'),
          ),
        ).thenAnswer(
          (_) async => VideosByAuthorResponse(
            videos: [_videoStats(id: 'social-failure-video', pubkey: pubkey)],
          ),
        );

        final repo = FunnelcakeCreatorAnalyticsRepository(api);
        final snapshot = await repo.fetchCreatorAnalytics(pubkey);

        expect(snapshot.videos.single.id, 'social-failure-video');
        expect(snapshot.socialCounts, isNull);
        expect(snapshot.diagnostics.failedSources, {
          AnalyticsDataSource.socialCounts,
        });
      },
    );

    test(
      'records social counts as used when the endpoint returns null',
      () async {
        const pubkey = 'pubkey';
        final api = MockFunnelcakeApiClient();

        when(() => api.isAvailable).thenReturn(true);
        when(() => api.getSocialCounts(pubkey)).thenAnswer((_) async => null);
        when(
          () => api.getBulkVideoStats(any()),
        ).thenAnswer((_) async => const BulkVideoStatsResponse(stats: {}));
        when(() => api.getVideoViews(any())).thenAnswer((_) async => 12);
        when(
          () => api.getVideosByAuthor(
            pubkey: pubkey,
            limit: 100,
            before: any(named: 'before'),
          ),
        ).thenAnswer(
          (_) async => VideosByAuthorResponse(
            videos: [_videoStats(id: 'social-null-video', pubkey: pubkey)],
          ),
        );

        final repo = FunnelcakeCreatorAnalyticsRepository(api);
        final snapshot = await repo.fetchCreatorAnalytics(pubkey);

        expect(
          snapshot.diagnostics.sourcesUsed,
          contains(AnalyticsDataSource.socialCounts),
        );
        expect(
          snapshot.diagnostics.failedSources,
          isNot(contains(AnalyticsDataSource.socialCounts)),
        );
      },
    );

    test('does not tolerate invariant failures from bulk hydration', () async {
      const pubkey = 'pubkey';
      final api = MockFunnelcakeApiClient();

      when(() => api.isAvailable).thenReturn(true);
      when(() => api.getSocialCounts(pubkey)).thenAnswer((_) async => null);
      when(() => api.getBulkVideoStats(any())).thenThrow(
        StateError('bulk stats invariant failed'),
      );
      when(
        () => api.getVideosByAuthor(
          pubkey: pubkey,
          limit: 100,
          before: any(named: 'before'),
        ),
      ).thenAnswer(
        (_) async => VideosByAuthorResponse(
          videos: [_videoStats(id: 'bulk-invariant-video', pubkey: pubkey)],
        ),
      );

      final repo = FunnelcakeCreatorAnalyticsRepository(api);

      await expectLater(
        repo.fetchCreatorAnalytics(pubkey),
        throwsA(isA<StateError>()),
      );
    });

    test('rethrows author video failures', () async {
      const pubkey = 'pubkey';
      final api = MockFunnelcakeApiClient();

      when(() => api.isAvailable).thenReturn(true);
      when(() => api.getSocialCounts(pubkey)).thenAnswer((_) async => null);
      when(
        () => api.getVideosByAuthor(
          pubkey: pubkey,
          limit: 100,
          before: any(named: 'before'),
        ),
      ).thenThrow(
        const FunnelcakeApiException(message: 'author failed', statusCode: 500),
      );

      final repo = FunnelcakeCreatorAnalyticsRepository(api);

      await expectLater(
        repo.fetchCreatorAnalytics(pubkey),
        throwsA(
          isA<CreatorAnalyticsLoadException>().having(
            (error) => error.kind,
            'kind',
            CreatorAnalyticsFailureKind.serverUnavailable,
          ),
        ),
      );
    });

    test('classifies wrapped DNS failures as connection issues', () async {
      const pubkey = 'pubkey';
      final api = MockFunnelcakeApiClient();

      when(() => api.isAvailable).thenReturn(true);
      when(() => api.getSocialCounts(pubkey)).thenAnswer((_) async => null);
      when(
        () => api.getVideosByAuthor(
          pubkey: pubkey,
          limit: 100,
          before: any(named: 'before'),
        ),
      ).thenThrow(
        const FunnelcakeException(
          'Failed to fetch author videos',
          cause: SocketException("Failed host lookup: 'api.divine.video'"),
        ),
      );

      final repo = FunnelcakeCreatorAnalyticsRepository(api);

      await expectLater(
        repo.fetchCreatorAnalytics(pubkey),
        throwsA(
          isA<CreatorAnalyticsLoadException>().having(
            (error) => error.kind,
            'kind',
            CreatorAnalyticsFailureKind.connectionIssue,
          ),
        ),
      );
    });

    test('handles social failure when author video fetch also fails', () async {
      const pubkey = 'pubkey';
      final api = MockFunnelcakeApiClient();
      final unhandledErrors = <Object>[];

      when(() => api.isAvailable).thenReturn(true);
      when(() => api.getSocialCounts(pubkey)).thenAnswer((_) async {
        await Future<void>.delayed(Duration.zero);
        throw const FunnelcakeApiException(
          message: 'social failed',
          statusCode: 500,
        );
      });
      when(
        () => api.getVideosByAuthor(
          pubkey: pubkey,
          limit: 100,
          before: any(named: 'before'),
        ),
      ).thenThrow(
        const FunnelcakeApiException(message: 'author failed', statusCode: 500),
      );

      final repo = FunnelcakeCreatorAnalyticsRepository(api);

      await runZonedGuarded<Future<void>>(
        () async {
          await expectLater(
            repo.fetchCreatorAnalytics(pubkey),
            throwsA(isA<CreatorAnalyticsLoadException>()),
          );
          await Future<void>.delayed(Duration.zero);
        },
        (error, stackTrace) {
          unhandledErrors.add(error);
        },
      );

      expect(unhandledErrors, isEmpty);
    });
  });
}
