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
      final state = VideoFeedState(videos: const [], hasMoreContent: false);

      cache.write('a' * 64, state);
      cache.clear('a' * 64);

      expect(cache.read('a' * 64), isNull);
    });
  });
}
