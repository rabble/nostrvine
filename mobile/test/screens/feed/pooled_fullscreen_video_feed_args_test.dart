// ABOUTME: Tests PooledFullscreenVideoFeedArgs requires a ViewSource +
// ABOUTME: FeedRepository pair (#3383).

import 'package:feed_repository/feed_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/services/view_event_publisher.dart';

VideoEvent _video(String id) => VideoEvent(
  id: id,
  pubkey: 'author',
  createdAt: 1000,
  content: '',
  timestamp: DateTime.fromMillisecondsSinceEpoch(1000 * 1000),
);

void main() {
  group('PooledFullscreenVideoFeedArgs', () {
    test('exposes the ViewSource + FeedRepository pair', () {
      final repository = StaticFeedRepository();
      final args = PooledFullscreenVideoFeedArgs(
        source: SingleVideoViewSource(_video('1')),
        feedRepository: repository,
        initialIndex: 0,
      );

      expect(args.source, isA<SingleVideoViewSource>());
      expect(args.feedRepository, same(repository));
      expect(args.initialIndex, 0);
    });

    test('carries optional presentation fields', () {
      final args = PooledFullscreenVideoFeedArgs(
        source: const ForYouViewSource(),
        feedRepository: StaticFeedRepository(),
        initialIndex: 2,
        contextTitle: 'For You',
        trafficSource: ViewTrafficSource.discoveryForYou,
        autoOpenComments: true,
      );

      expect(args.contextTitle, 'For You');
      expect(args.trafficSource, ViewTrafficSource.discoveryForYou);
      expect(args.autoOpenComments, isTrue);
    });
  });
}
