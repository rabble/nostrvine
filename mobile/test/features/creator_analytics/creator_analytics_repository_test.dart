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
  int? loops,
  int? views,
}) {
  return VideoStats(
    id: id,
    pubkey: pubkey,
    createdAt: DateTime.fromMillisecondsSinceEpoch(1739350000 * 1000),
    kind: 34236,
    dTag: id,
    title: id,
    thumbnail: 'thumb',
    videoUrl: 'videoUrl',
    reactions: 2,
    comments: 1,
    reposts: 0,
    engagementScore: 0,
    loops: loops,
    views: views,
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
    test('hydrates views from bulk stats when available', () async {
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
          videos: [_videoStats(id: 'a', pubkey: pubkey)],
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
  });
}
