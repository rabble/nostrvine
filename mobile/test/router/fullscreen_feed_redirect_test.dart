// ABOUTME: Tests the fullscreen video feed route redirect — falls back to the
// ABOUTME: home feed when its in-memory `extra` args are missing (web reload).

import 'package:feed_repository/feed_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/router/pooled_fullscreen_feed_route.dart'
    show fullscreenFeedRedirect;
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';

VideoEvent _video(String id) => VideoEvent(
  id: id,
  pubkey: 'author',
  createdAt: 1000,
  content: '',
  timestamp: DateTime.fromMillisecondsSinceEpoch(1000 * 1000),
);

void main() {
  group('fullscreenFeedRedirect', () {
    test('redirects to the home feed when extra is null (web reload)', () {
      expect(
        fullscreenFeedRedirect(null),
        equals(VideoFeedPage.pathForIndex(0)),
      );
    });

    test('redirects to the home feed when extra is the wrong type', () {
      expect(
        fullscreenFeedRedirect('not-args'),
        equals(VideoFeedPage.pathForIndex(0)),
      );
    });

    test('does not redirect when valid pooled feed args are present', () {
      final args = PooledFullscreenVideoFeedArgs(
        source: SingleVideoViewSource(_video('1')),
        feedRepository: StaticFeedRepository(),
        initialIndex: 0,
      );

      expect(fullscreenFeedRedirect(args), isNull);
    });

    test('does not redirect when valid profile feed args are present', () {
      const args = ProfilePooledFullscreenVideoFeedArgs(
        userIdHex: 'abc',
        initialIndex: 0,
      );

      expect(fullscreenFeedRedirect(args), isNull);
    });
  });
}
