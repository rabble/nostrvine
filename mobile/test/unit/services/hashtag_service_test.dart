// ABOUTME: Unit tests for HashtagService functionality
// ABOUTME: Tests hashtag statistics, filtering, and video retrieval

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/hashtag_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/models/video_event.dart';

class MockVideoEventService extends Mock implements VideoEventService {
  @override
  List<VideoEvent> get videoEvents => super.noSuchMethod(
    Invocation.getter(#videoEvents),
  ) as List<VideoEvent>? ?? <VideoEvent>[];
}

void main() {
  group('HashtagService', () {
    late HashtagService hashtagService;
    late MockVideoEventService mockVideoService;

    setUp(() {
      mockVideoService = MockVideoEventService();
      hashtagService = HashtagService(mockVideoService);
    });

    tearDown(() {
      hashtagService.dispose();
    });

    test('should return empty list when no videos exist', () {
      when(() => mockVideoService.videoEvents).thenReturn([]);

      final hashtags = hashtagService.allHashtags;
      final trending = hashtagService.getTrendingHashtags();
      final popular = hashtagService.getPopularHashtags();

      expect(hashtags, isEmpty);
      expect(trending, isEmpty);
      expect(popular, isEmpty);
    });

    test('should collect hashtags from video events', () {
      final videoEvents = [
        _createTestVideoEvent('1', ['bitcoin', 'crypto'], 'user1'),
        _createTestVideoEvent('2', ['nostr', 'protocol'], 'user2'),
        _createTestVideoEvent('3', ['bitcoin', 'nostr'], 'user3'),
      ];

      when(() => mockVideoService.videoEvents).thenReturn(videoEvents);

      // Trigger stats update
      hashtagService.dispose();
      hashtagService = HashtagService(mockVideoService);

      final allHashtags = hashtagService.allHashtags;
      expect(allHashtags, containsAll(['bitcoin', 'nostr', 'crypto', 'protocol']));
    });

    test('should calculate hashtag statistics correctly', () {
      final now = DateTime.now();
      final recent = now.subtract(Duration(hours: 12));
      final old = now.subtract(Duration(days: 2));

      final videoEvents = [
        _createTestVideoEvent('1', ['bitcoin'], 'user1', recent.millisecondsSinceEpoch ~/ 1000),
        _createTestVideoEvent('2', ['bitcoin'], 'user2', recent.millisecondsSinceEpoch ~/ 1000),
        _createTestVideoEvent('3', ['bitcoin'], 'user3', old.millisecondsSinceEpoch ~/ 1000),
      ];

      when(() => mockVideoService.videoEvents).thenReturn(videoEvents);

      // Trigger stats update
      hashtagService.dispose();
      hashtagService = HashtagService(mockVideoService);

      final stats = hashtagService.getHashtagStats('bitcoin');
      expect(stats, isNotNull);
      expect(stats!.videoCount, 3);
      expect(stats.recentVideoCount, 2); // Only 2 videos in last 24 hours
      expect(stats.authorCount, 3); // 3 unique authors
    });

    test('should sort hashtags by popularity', () {
      final videoEvents = [
        _createTestVideoEvent('1', ['bitcoin'], 'user1'),
        _createTestVideoEvent('2', ['bitcoin'], 'user2'),
        _createTestVideoEvent('3', ['bitcoin'], 'user3'),
        _createTestVideoEvent('4', ['nostr'], 'user1'),
        _createTestVideoEvent('5', ['nostr'], 'user2'),
        _createTestVideoEvent('6', ['crypto'], 'user1'),
      ];

      when(() => mockVideoService.videoEvents).thenReturn(videoEvents);

      // Trigger stats update
      hashtagService.dispose();
      hashtagService = HashtagService(mockVideoService);

      final popular = hashtagService.getPopularHashtags();
      expect(popular.first, 'bitcoin'); // Most videos (3)
      expect(popular[1], 'nostr'); // Second most (2)
      expect(popular[2], 'crypto'); // Least (1)
    });

    test('should filter videos by hashtags', () {
      final videoEvents = [
        _createTestVideoEvent('1', ['bitcoin', 'crypto'], 'user1'),
        _createTestVideoEvent('2', ['nostr', 'protocol'], 'user2'),
        _createTestVideoEvent('3', ['bitcoin', 'nostr'], 'user3'),
      ];

      when(() => mockVideoService.getVideoEventsByHashtags(['bitcoin']))
          .thenReturn(videoEvents.where((v) => v.hashtags.contains('bitcoin')).toList());
      when(() => mockVideoService.getVideoEventsByHashtags(['nostr']))
          .thenReturn(videoEvents.where((v) => v.hashtags.contains('nostr')).toList());

      final bitcoinVideos = hashtagService.getVideosByHashtags(['bitcoin']);
      final nostrVideos = hashtagService.getVideosByHashtags(['nostr']);

      expect(bitcoinVideos.length, 2);
      expect(nostrVideos.length, 2);
      expect(bitcoinVideos.map((v) => v.id), containsAll(['video_1', 'video_3']));
      expect(nostrVideos.map((v) => v.id), containsAll(['video_2', 'video_3']));
    });

    test('should search hashtags by query', () {
      final videoEvents = [
        _createTestVideoEvent('1', ['bitcoin', 'cryptocurrency'], 'user1'),
        _createTestVideoEvent('2', ['ethereum', 'crypto'], 'user2'),
        _createTestVideoEvent('3', ['nostr', 'protocol'], 'user3'),
      ];

      when(() => mockVideoService.videoEvents).thenReturn(videoEvents);

      // Trigger stats update
      hashtagService.dispose();
      hashtagService = HashtagService(mockVideoService);

      final cryptoResults = hashtagService.searchHashtags('crypto');
      expect(cryptoResults, containsAll(['crypto', 'cryptocurrency']));
      expect(cryptoResults, isNot(contains('nostr')));

      final bitcoinResults = hashtagService.searchHashtags('bit');
      expect(bitcoinResults, contains('bitcoin'));
    });

    test('should get editor\'s picks with multiple authors', () {
      final videoEvents = [
        _createTestVideoEvent('1', ['bitcoin'], 'user1'),
        _createTestVideoEvent('2', ['bitcoin'], 'user2'),
        _createTestVideoEvent('3', ['bitcoin'], 'user3'),
        _createTestVideoEvent('4', ['bitcoin'], 'user4'),
        _createTestVideoEvent('5', ['nostr'], 'user1'), // Only 1 author
        _createTestVideoEvent('6', ['ethereum'], 'user1'),
        _createTestVideoEvent('7', ['ethereum'], 'user2'), // Only 2 authors
      ];

      when(() => mockVideoService.videoEvents).thenReturn(videoEvents);

      // Trigger stats update
      hashtagService.dispose();
      hashtagService = HashtagService(mockVideoService);

      final editorsPicks = hashtagService.getEditorsPicks();
      expect(editorsPicks, contains('bitcoin')); // 4 authors >= 3
      expect(editorsPicks, isNot(contains('nostr'))); // Only 1 author < 3
      expect(editorsPicks, isNot(contains('ethereum'))); // Only 2 authors < 3
    });

    test('should subscribe to hashtag videos', () async {
      when(() => mockVideoService.subscribeToHashtagVideos(any(), limit: any(named: 'limit')))
          .thenAnswer((_) async => {});

      await hashtagService.subscribeToHashtagVideos(['bitcoin', 'nostr'], limit: 50);

      verify(() => mockVideoService.subscribeToHashtagVideos(['bitcoin', 'nostr'], limit: 50))
          .called(1);
    });

    test('should calculate trending score correctly', () {
      final now = DateTime.now();
      final recent = now.subtract(Duration(hours: 1));

      final videoEvents = [
        _createTestVideoEvent('1', ['trending'], 'user1', recent.millisecondsSinceEpoch ~/ 1000),
        _createTestVideoEvent('2', ['trending'], 'user2', recent.millisecondsSinceEpoch ~/ 1000),
        _createTestVideoEvent('3', ['trending'], 'user3', recent.millisecondsSinceEpoch ~/ 1000),
        _createTestVideoEvent('4', ['old'], 'user1', now.subtract(Duration(days: 10)).millisecondsSinceEpoch ~/ 1000),
      ];

      when(() => mockVideoService.videoEvents).thenReturn(videoEvents);

      // Trigger stats update
      hashtagService.dispose();
      hashtagService = HashtagService(mockVideoService);

      final trendingStats = hashtagService.getHashtagStats('trending');
      final oldStats = hashtagService.getHashtagStats('old');

      expect(trendingStats!.trendingScore, greaterThan(oldStats!.trendingScore));
    });
  });
}

VideoEvent _createTestVideoEvent(String id, List<String> hashtags, String pubkey, [int? createdAt]) {
  final timestamp = createdAt ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
  return VideoEvent(
    id: 'video_$id',
    pubkey: pubkey,
    createdAt: timestamp,
    content: 'Test video $id content',
    timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp * 1000),
    videoUrl: 'https://example.com/video$id.mp4',
    thumbnailUrl: 'https://example.com/thumb$id.jpg',
    title: 'Test Video $id',
    hashtags: hashtags,
    duration: 30,
  );
}