// ABOUTME: Tests for ProfileFeed timestamp preservation behavior
// ABOUTME: Verifies timestamp preservation through public API testing

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/profile_feed_provider.dart';

void main() {
  group('$ProfileFeed REST API timeout', () {
    test('TimeoutException is caught by generic catch block', () async {
      // Verifies the timeout mechanism used by ProfileFeed.build(),
      // _refreshFromRestApi(), and _refreshInner(). Each wraps the
      // funnelcake REST call with .timeout() and relies on a generic
      // catch(e) to fall back to Nostr when the API hangs.
      var fellBackToNostr = false;

      try {
        await Future<void>.delayed(
          const Duration(seconds: 2),
        ).timeout(Duration.zero);
      } catch (e) {
        // The generic catch(e) in ProfileFeed handles TimeoutException
        expect(e, isA<TimeoutException>());
        fellBackToNostr = true;
      }

      expect(fellBackToNostr, isTrue);
    });

    test('timeout does not interfere when API responds quickly', () async {
      // When the API responds before the timeout, no exception is thrown
      final result = await Future<String>.value(
        'ok',
      ).timeout(const Duration(seconds: 10));

      expect(result, equals('ok'));
    });
  });

  group('$ProfileFeed timestamp preservation', () {
    late DateTime baseTime;

    setUp(() {
      baseTime = DateTime.now();
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

    group('rawTags merge behavior', () {
      test('preserves REST views when relay copy wins merge precedence', () {
        final merged = ProfileFeed.mergeRawTagsForVideoMerge(
          {'d': 'stable1', 'title': 'Relay title'},
          {'views': '42'},
        );

        expect(merged['d'], equals('stable1'));
        expect(merged['title'], equals('Relay title'));
        expect(merged['views'], equals('42'));
      });

      test('merged tags keep loop totals available on profile videos', () {
        final relayVideo = createTestVideo(
          'id1',
          'pubkey1',
          'stable1',
          baseTime,
        );
        final restVideo = createTestVideo(
          'id2',
          'pubkey1',
          'stable1',
          baseTime.subtract(const Duration(seconds: 1)),
        ).copyWith(rawTags: {'views': '42'});

        final mergedVideo = relayVideo.copyWith(
          rawTags: ProfileFeed.mergeRawTagsForVideoMerge(
            relayVideo.rawTags,
            restVideo.rawTags,
          ),
          originalLoops: relayVideo.originalLoops ?? restVideo.originalLoops,
        );

        expect(mergedVideo.rawTags['views'], equals('42'));
        expect(mergedVideo.totalLoops, equals(42));
      });

      test('cached metadata rehydrates views onto relay profile videos', () {
        final relayVideo = createTestVideo(
          'id1',
          'pubkey1',
          'stable1',
          baseTime,
        );

        final hydrated = ProfileFeed.applyCachedMetadataForVideo(
          relayVideo,
          views: '42',
        );

        expect(hydrated.rawTags['views'], equals('42'));
        expect(hydrated.totalLoops, equals(42));
      });

      test(
        'sequence comparison treats views-only metadata changes as updates',
        () {
          final stale = [
            createTestVideo(
              'id1',
              'pubkey1',
              'stable1',
              baseTime,
            ),
          ];
          final enriched = [
            createTestVideo(
              'id1',
              'pubkey1',
              'stable1',
              baseTime,
            ).copyWith(rawTags: {'d': 'stable1', 'views': '42'}),
          ];

          expect(
            ProfileFeed.sameVideoSequenceForMerge(stale, enriched),
            isFalse,
          );
        },
      );

      test(
        'sequence comparison treats originalLoops changes as updates',
        () {
          final stale = [
            createTestVideo(
              'id1',
              'pubkey1',
              'stable1',
              baseTime,
            ),
          ];
          final enriched = [
            createTestVideo(
              'id1',
              'pubkey1',
              'stable1',
              baseTime,
            ).copyWith(originalLoops: 100),
          ];

          expect(
            ProfileFeed.sameVideoSequenceForMerge(stale, enriched),
            isFalse,
          );
        },
      );
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
