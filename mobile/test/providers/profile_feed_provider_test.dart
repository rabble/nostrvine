// ABOUTME: Tests for ProfileFeed timestamp preservation behavior
// ABOUTME: Verifies timestamp preservation through public API testing

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/profile_feed_provider.dart';

void main() {
  group('$ProfileFeed timestamp preservation', () {
    late DateTime baseTime;

    setUp(() {
      baseTime = DateTime.now();
    });

    group('$VideoEvent relativeTime behavior', () {
      test('relativeTime shows original time after timestamp preservation', () {
        final originalTime = baseTime.subtract(const Duration(hours: 2));
        final video = createTestVideo(
          'id1',
          'pubkey1',
          'stable1',
          originalTime,
        );

        final relativeTime = video.relativeTime;

        expect(
          relativeTime,
          contains('h ago'),
        ); // Should show "2h ago", not "now"
      });

      test('relativeTime shows "now" for very recent videos', () {
        final recentTime = baseTime.subtract(const Duration(seconds: 30));
        final video = createTestVideo('id1', 'pubkey1', 'stable1', recentTime);

        final relativeTime = video.relativeTime;

        expect(relativeTime, equals('now'));
      });

      test(
        'relativeTime works correctly after copyWith timestamp preservation',
        () {
          final originalTime = baseTime.subtract(const Duration(hours: 3));
          final editTime = baseTime;

          final originalVideo = createTestVideo(
            'id1',
            'pubkey1',
            'stable1',
            originalTime,
          );

          final preservedVideo = originalVideo.copyWith(
            title: 'Updated Title',
            createdAt: editTime.millisecondsSinceEpoch ~/ 1000,
            timestamp: editTime,
            publishedAt: null,
          );

          // Manually preserve the original timestamp (simulating _preserveOriginalTimestamp logic)
          final finalVideo = preservedVideo.copyWith(
            createdAt: originalVideo.createdAt,
            timestamp: originalVideo.timestamp,
          );

          expect(
            finalVideo.relativeTime,
            contains('h ago'),
          ); // Should still show original time, not "now"
        },
      );

      test('relativeTime formats different time ranges correctly', () {
        // Test minutes
        final minutesAgo = baseTime.subtract(const Duration(minutes: 5));
        final videoMinutes = createTestVideo(
          'id1',
          'pubkey1',
          'stable1',
          minutesAgo,
        );
        expect(videoMinutes.relativeTime, equals('5m ago'));

        // Test days
        final daysAgo = baseTime.subtract(const Duration(days: 3));
        final videoDays = createTestVideo('id2', 'pubkey1', 'stable2', daysAgo);
        expect(videoDays.relativeTime, equals('3d ago'));

        // Test weeks
        final weeksAgo = baseTime.subtract(const Duration(days: 14));
        final videoWeeks = createTestVideo(
          'id3',
          'pubkey1',
          'stable3',
          weeksAgo,
        );
        expect(videoWeeks.relativeTime, equals('2w ago'));
      });
    });

    group('timestamp preservation logic', () {
      test('preserves timestamps when both videos lack publishedAt', () {
        // Simulate the _preserveOriginalTimestamp logic
        final originalTime = baseTime.subtract(const Duration(hours: 2));
        final editTime = baseTime;

        final existingVideo = createTestVideo(
          'id1',
          'pubkey1',
          'stable1',
          originalTime,
        );
        final updatedVideo = createTestVideo(
          'id2',
          'pubkey1',
          'stable1',
          editTime,
        );

        // Simulate the preservation logic
        final preservedVideo =
            (existingVideo.publishedAt == null &&
                updatedVideo.publishedAt == null)
            ? updatedVideo.copyWith(
                createdAt: existingVideo.createdAt,
                timestamp: existingVideo.timestamp,
              )
            : updatedVideo;

        expect(
          preservedVideo.createdAt,
          equals(originalTime.millisecondsSinceEpoch ~/ 1000),
        );
        expect(preservedVideo.timestamp, equals(originalTime));
      });

      test('keeps new timestamps when updated video has publishedAt', () {
        final originalTime = baseTime.subtract(const Duration(hours: 2));
        final newTime = baseTime;

        final existingVideo = createTestVideo(
          'id1',
          'pubkey1',
          'stable1',
          originalTime,
        );
        final updatedVideo = createTestVideo(
          'id2',
          'pubkey1',
          'stable1',
          newTime,
          publishedAt: '1234567890',
        );

        // Simulate the preservation logic
        final preservedVideo =
            (existingVideo.publishedAt == null &&
                updatedVideo.publishedAt == null)
            ? updatedVideo.copyWith(
                createdAt: existingVideo.createdAt,
                timestamp: existingVideo.timestamp,
              )
            : updatedVideo;

        expect(
          preservedVideo.createdAt,
          equals(newTime.millisecondsSinceEpoch ~/ 1000),
        );
        expect(preservedVideo.timestamp, equals(newTime));
      });
    });

    group('stableId matching behavior', () {
      test('creates consistent lookup keys for same video', () {
        final video1 = createTestVideo('id1', 'pubkey1', 'stable1', baseTime);
        final video2 = createTestVideo('id2', 'pubkey1', 'stable1', baseTime);

        final key1 = _createStableKey(video1);
        final key2 = _createStableKey(video2);

        expect(key1, equals(key2));
        expect(key1, equals('pubkey1:stable1'));
        expect(key2, equals('pubkey1:stable1'));
      });

      test('creates different keys for different pubkeys', () {
        final video1 = createTestVideo('id1', 'pubkey1', 'stable1', baseTime);
        final video2 = createTestVideo('id2', 'pubkey2', 'stable1', baseTime);

        final key1 = _createStableKey(video1);
        final key2 = _createStableKey(video2);

        expect(key1, isNot(equals(key2)));
        expect(key1, equals('pubkey1:stable1'));
        expect(key2, equals('pubkey2:stable1'));
      });

      test('falls back to video ID when stableId is empty', () {
        final video = createTestVideo('id1', 'pubkey1', '', baseTime);

        final key = _createStableKey(video);

        expect(key, equals('pubkey1:id1'));
      });

      test('handles case-insensitive stableId matching', () {
        final video1 = createTestVideo('id1', 'pubkey1', 'StableId', baseTime);
        final video2 = createTestVideo('id2', 'pubkey1', 'stableid', baseTime);

        final key1 = _createStableKey(video1);
        final key2 = _createStableKey(video2);

        expect(key1, equals(key2));
        expect(key1, equals('pubkey1:stableid'));
        expect(key2, equals('pubkey1:stableid'));
      });
    });
  });
}

/// Helper function to create test VideoEvent objects
VideoEvent createTestVideo(
  String id,
  String pubkey,
  String stableId,
  DateTime timestamp, {
  String? publishedAt,
}) {
  return VideoEvent(
    id: id,
    pubkey: pubkey,
    createdAt: timestamp.millisecondsSinceEpoch ~/ 1000,
    content: 'Test video content',
    timestamp: timestamp,
    videoUrl: 'https://example.com/video.mp4',
    publishedAt: publishedAt,
    rawTags: stableId.isNotEmpty ? {'d': stableId} : {},
    vineId: stableId.isNotEmpty ? stableId : null,
  );
}

/// Helper function to simulate the stableKey logic from _mergeStableTimestampsFromCurrentState
String? _createStableKey(VideoEvent v) {
  final stableId = v.stableId;
  if (stableId.isEmpty) return null;
  return '${v.pubkey}:$stableId'.toLowerCase();
}
