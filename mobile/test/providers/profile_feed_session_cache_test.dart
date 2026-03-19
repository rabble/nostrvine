import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/profile_feed_session_cache.dart';
import 'package:openvine/state/video_feed_state.dart';

void main() {
  group('ProfileFeedSessionCache', () {
    test('stores and returns snapshots by pubkey', () {
      final cache = ProfileFeedSessionCache();
      final state = VideoFeedState(
        videos: [
          VideoEvent(
            id: 'video-1',
            pubkey: 'a' * 64,
            createdAt: 1,
            content: '',
            timestamp: DateTime(2026),
            videoUrl: 'https://example.com/video-1.mp4',
          ),
        ],
        hasMoreContent: true,
      );

      cache.write('a' * 64, state);

      expect(cache.read('a' * 64), equals(state));
      expect(cache.read('b' * 64), isNull);
    });

    test('clears snapshots by pubkey', () {
      final cache = ProfileFeedSessionCache();
      const state = VideoFeedState(videos: [], hasMoreContent: false);

      cache.write('a' * 64, state);
      cache.clear('a' * 64);

      expect(cache.read('a' * 64), isNull);
    });

    test('evicts oldest entries when exceeding maxEntries', () {
      final cache = ProfileFeedSessionCache();
      const state = VideoFeedState(videos: [], hasMoreContent: false);

      // Write 30 entries (exceeds maxEntries=25)
      for (var i = 0; i < 30; i++) {
        final key = i.toString().padLeft(64, '0');
        cache.write(key, state);
      }

      // First 5 entries (0-4) should have been evicted
      for (var i = 0; i < 5; i++) {
        final key = i.toString().padLeft(64, '0');
        expect(cache.read(key), isNull, reason: 'Entry $i should be evicted');
      }

      // Entries 5-29 should still be present
      for (var i = 5; i < 30; i++) {
        final key = i.toString().padLeft(64, '0');
        expect(cache.read(key), isNotNull, reason: 'Entry $i should exist');
      }
    });

    test('read promotes entry to most-recently-used preventing eviction', () {
      final cache = ProfileFeedSessionCache();
      const state = VideoFeedState(videos: [], hasMoreContent: false);

      // Fill cache to capacity
      for (var i = 0; i < 25; i++) {
        final key = i.toString().padLeft(64, '0');
        cache.write(key, state);
      }

      // Read entry 0 (oldest) to promote it to most-recently-used
      final key0 = 0.toString().padLeft(64, '0');
      expect(cache.read(key0), isNotNull);

      // Write one more entry to trigger eviction
      final newKey = 'new'.padLeft(64, '0');
      cache.write(newKey, state);

      // Entry 0 should still exist (was promoted by read)
      expect(cache.read(key0), isNotNull);

      // Entry 1 should have been evicted (was oldest after 0 was promoted)
      final key1 = 1.toString().padLeft(64, '0');
      expect(cache.read(key1), isNull);
    });

    test('clearAll removes all cached entries', () {
      final cache = ProfileFeedSessionCache();
      const state = VideoFeedState(videos: [], hasMoreContent: false);

      cache.write('a' * 64, state);
      cache.write('b' * 64, state);
      cache.write('c' * 64, state);

      cache.clearAll();

      expect(cache.read('a' * 64), isNull);
      expect(cache.read('b' * 64), isNull);
      expect(cache.read('c' * 64), isNull);
    });

    test('overwriting existing key updates value', () {
      final cache = ProfileFeedSessionCache();
      const state1 = VideoFeedState(videos: [], hasMoreContent: false);
      const state2 = VideoFeedState(videos: [], hasMoreContent: true);

      cache.write('a' * 64, state1);
      cache.write('a' * 64, state2);

      final result = cache.read('a' * 64);
      expect(result, equals(state2));
      expect(result?.hasMoreContent, isTrue);
    });
  });
}
