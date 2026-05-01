// ABOUTME: Unit tests for VideoStatsHydrationService.
// ABOUTME: Verifies loop count and view stats are merged from bulk API response.

import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/services/video_stats_hydration_service.dart';

class MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

VideoEvent _video({required String id, int? loops, int? views}) {
  return VideoEvent(
    id: id,
    pubkey: 'pubkey',
    createdAt: 1739350000,
    content: 'content',
    timestamp: DateTime.fromMillisecondsSinceEpoch(1739350000 * 1000),
    title: id,
    rawTags: {if (views != null) 'views': '$views'},
    originalLoops: loops,
    originalLikes: 0,
    originalComments: 0,
    originalReposts: 0,
  );
}

BulkVideoStatsEntry _entry(
  String id, {
  int? loops,
  int? views,
}) => BulkVideoStatsEntry(
  eventId: id,
  reactions: 0,
  comments: 0,
  reposts: 0,
  loops: loops,
  views: views,
);

BulkVideoStatsResponse _statsResponse(Map<String, BulkVideoStatsEntry> stats) =>
    BulkVideoStatsResponse(stats: stats);

void main() {
  late MockFunnelcakeApiClient mockClient;

  setUp(() {
    mockClient = MockFunnelcakeApiClient();
  });

  group('VideoStatsHydrationService.hydrateVideo', () {
    test('returns null for video with empty id', () async {
      final video = _video(id: '');
      final result = await VideoStatsHydrationService.hydrateVideo(
        video,
        client: mockClient,
      );
      expect(result, isNull);
      verifyNever(() => mockClient.getBulkVideoStats(any()));
    });

    test('merges loop count from API response', () async {
      const videoId = 'abc123';
      final video = _video(id: videoId);

      when(() => mockClient.getBulkVideoStats([videoId])).thenAnswer(
        (_) async => _statsResponse({
          videoId: _entry(videoId, loops: 42, views: 100),
        }),
      );

      final result = await VideoStatsHydrationService.hydrateVideo(
        video,
        client: mockClient,
      );

      expect(result, isNotNull);
      expect(result!.originalLoops, equals(42));
      expect(result.rawTags['loops'], equals('42'));
      expect(result.rawTags['views'], equals('100'));
    });

    test('returns null when API has no entry for the video', () async {
      const videoId = 'no-entry';
      final video = _video(id: videoId);

      when(() => mockClient.getBulkVideoStats([videoId])).thenAnswer(
        (_) async => const BulkVideoStatsResponse(stats: {}),
      );

      final result = await VideoStatsHydrationService.hydrateVideo(
        video,
        client: mockClient,
      );

      expect(result, isNull);
    });

    test('preserves existing tags when merging stats', () async {
      const videoId = 'with-tags';
      final video = _video(id: videoId).copyWith(
        rawTags: const {'title': 'My Video', 'loops': '5'},
      );

      when(() => mockClient.getBulkVideoStats([videoId])).thenAnswer(
        (_) async => _statsResponse({videoId: _entry(videoId, loops: 99)}),
      );

      final result = await VideoStatsHydrationService.hydrateVideo(
        video,
        client: mockClient,
      );

      expect(result, isNotNull);
      expect(result!.rawTags['title'], equals('My Video'));
      expect(result.rawTags['loops'], equals('99'));
      expect(result.originalLoops, equals(99));
    });

    test(
      'does not overwrite originalLoops when API entry has null loops',
      () async {
        const videoId = 'existing-loops';
        final video = _video(id: videoId, loops: 7);

        when(() => mockClient.getBulkVideoStats([videoId])).thenAnswer(
          (_) async => _statsResponse({videoId: _entry(videoId, views: 50)}),
        );

        final result = await VideoStatsHydrationService.hydrateVideo(
          video,
          client: mockClient,
        );

        expect(result, isNotNull);
        expect(result!.originalLoops, equals(7));
        expect(result.rawTags['views'], equals('50'));
      },
    );
  });

  group('VideoStatsHydrationService.hydrateVideos', () {
    test('returns unchanged list when input is empty', () async {
      final result = await VideoStatsHydrationService.hydrateVideos(
        [],
        client: mockClient,
      );
      expect(result, isEmpty);
      verifyNever(() => mockClient.getBulkVideoStats(any()));
    });

    test('hydrates multiple videos in a single bulk call', () async {
      final videos = [_video(id: 'v1'), _video(id: 'v2')];

      when(() => mockClient.getBulkVideoStats(['v1', 'v2'])).thenAnswer(
        (_) async => _statsResponse({
          'v1': _entry('v1', loops: 10, views: 200),
          'v2': _entry('v2', loops: 20, views: 300),
        }),
      );

      final result = await VideoStatsHydrationService.hydrateVideos(
        videos,
        client: mockClient,
      );

      expect(result, hasLength(2));
      expect(result[0].originalLoops, equals(10));
      expect(result[1].originalLoops, equals(20));
    });

    test('returns videos unchanged when API stats are empty', () async {
      final videos = [_video(id: 'v1', loops: 5)];

      when(() => mockClient.getBulkVideoStats(['v1'])).thenAnswer(
        (_) async => const BulkVideoStatsResponse(stats: {}),
      );

      final result = await VideoStatsHydrationService.hydrateVideos(
        videos,
        client: mockClient,
      );

      expect(result, hasLength(1));
      expect(result.first.originalLoops, equals(5));
    });

    test('skips videos with empty IDs', () async {
      final videos = [_video(id: ''), _video(id: 'v2')];

      when(() => mockClient.getBulkVideoStats(['v2'])).thenAnswer(
        (_) async => _statsResponse({'v2': _entry('v2', loops: 15)}),
      );

      final result = await VideoStatsHydrationService.hydrateVideos(
        videos,
        client: mockClient,
      );

      expect(result, hasLength(2));
      expect(result[0].originalLoops, isNull);
      expect(result[1].originalLoops, equals(15));
    });
  });
}
