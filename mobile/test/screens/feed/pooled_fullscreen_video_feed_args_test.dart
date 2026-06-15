// ABOUTME: Tests PooledFullscreenVideoFeedArgs sourcing-mode invariants (#3383).
// ABOUTME: Either a ViewSource+FeedRepository pair or a legacy videosStream.

import 'package:feed_repository/feed_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';

VideoEvent _video(String id) => VideoEvent(
  id: id,
  pubkey: 'author',
  createdAt: 1000,
  content: '',
  timestamp: DateTime.fromMillisecondsSinceEpoch(1000 * 1000),
);

void main() {
  group('PooledFullscreenVideoFeedArgs', () {
    test('accepts a ViewSource + FeedRepository pair', () {
      final args = PooledFullscreenVideoFeedArgs(
        source: SingleVideoViewSource(_video('1')),
        feedRepository: StaticFeedRepository(),
        initialIndex: 0,
      );

      expect(args.source, isA<SingleVideoViewSource>());
      expect(args.feedRepository, isNotNull);
      expect(args.videosStream, isNull);
    });

    test('accepts a legacy videosStream', () {
      final args = PooledFullscreenVideoFeedArgs(
        videosStream: Stream<List<VideoEvent>>.value([_video('1')]),
        initialIndex: 0,
      );

      expect(args.videosStream, isNotNull);
      expect(args.source, isNull);
      expect(args.feedRepository, isNull);
    });

    test('rejects a source without a repository', () {
      expect(
        () => PooledFullscreenVideoFeedArgs(
          source: const ForYouViewSource(),
          initialIndex: 0,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects neither sourcing mode', () {
      expect(
        () => PooledFullscreenVideoFeedArgs(initialIndex: 0),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
