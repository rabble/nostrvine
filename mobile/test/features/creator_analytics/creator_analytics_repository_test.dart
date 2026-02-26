import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/features/creator_analytics/creator_analytics_repository.dart';

class _FakeCreatorAnalyticsApi implements CreatorAnalyticsApi {
  _FakeCreatorAnalyticsApi({
    required this.videos,
    required this.bulkStats,
    required this.viewsById,
  });

  final List<VideoEvent> videos;
  final Map<String, BulkVideoStatsEntry> bulkStats;
  final Map<String, int?> viewsById;

  @override
  bool get isAvailable => true;

  @override
  Future<Map<String, BulkVideoStatsEntry>> getBulkVideoStats(
    List<String> eventIds,
  ) async {
    return {
      for (final id in eventIds)
        if (bulkStats.containsKey(id)) id: bulkStats[id]!,
    };
  }

  @override
  Future<SocialCounts?> getSocialCounts(String pubkey) async => null;

  @override
  Future<int?> getVideoViews(String eventId) async => viewsById[eventId];

  @override
  Future<List<VideoEvent>> getVideosByAuthor({
    required String pubkey,
    int limit = 50,
    int? before,
  }) async {
    return videos;
  }
}

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

void main() {
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
      final api = _FakeCreatorAnalyticsApi(
        videos: [_video(id: 'a')],
        bulkStats: {
          'a': const BulkVideoStatsEntry(
            eventId: 'a',
            reactions: 4,
            comments: 2,
            reposts: 1,
            loops: 12,
            views: 15,
          ),
        },
        viewsById: const {},
      );
      final repo = FunnelcakeCreatorAnalyticsRepository(api);
      final snapshot = await repo.fetchCreatorAnalytics('pubkey');

      expect(snapshot.diagnostics.totalVideos, 1);
      expect(snapshot.diagnostics.videosHydratedByBulkStats, 1);
      expect(snapshot.diagnostics.videosHydratedByViewsEndpoint, 0);
      expect(snapshot.diagnostics.videosWithAnyViews, 1);
      expect(snapshot.videos.first.rawTags['views'], '15');
    });

    test(
      'hydrates views from /views endpoint when bulk stats missing',
      () async {
        final api = _FakeCreatorAnalyticsApi(
          videos: [_video(id: 'b')],
          bulkStats: const {},
          viewsById: const {'b': 21},
        );
        final repo = FunnelcakeCreatorAnalyticsRepository(api);
        final snapshot = await repo.fetchCreatorAnalytics('pubkey');

        expect(snapshot.diagnostics.totalVideos, 1);
        expect(snapshot.diagnostics.videosHydratedByBulkStats, 0);
        expect(snapshot.diagnostics.videosHydratedByViewsEndpoint, 1);
        expect(snapshot.diagnostics.videosWithAnyViews, 1);
        expect(snapshot.videos.first.rawTags['views'], '21');
      },
    );

    test(
      'keeps missing-view diagnostics when no view source is available',
      () async {
        final api = _FakeCreatorAnalyticsApi(
          videos: [_video(id: 'c')],
          bulkStats: const {},
          viewsById: const {'c': null},
        );
        final repo = FunnelcakeCreatorAnalyticsRepository(api);
        final snapshot = await repo.fetchCreatorAnalytics('pubkey');

        expect(snapshot.diagnostics.totalVideos, 1);
        expect(snapshot.diagnostics.videosWithAnyViews, 0);
        expect(snapshot.diagnostics.videosMissingViews, 1);
        expect(snapshot.diagnostics.hasAnyViewData, isFalse);
      },
    );
  });
}
