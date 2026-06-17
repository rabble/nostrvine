// ABOUTME: Tests the fullscreen video feed route redirect — falls back to the
// ABOUTME: home feed when its in-memory `extra` args are missing (web reload).

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/router/pooled_fullscreen_feed_route.dart'
    show fullscreenFeedRedirect;
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';

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

    test('does not redirect when valid profile feed args are present', () {
      const args = ProfilePooledFullscreenVideoFeedArgs(
        userIdHex: 'abc',
        initialIndex: 0,
      );

      expect(fullscreenFeedRedirect(args), isNull);
    });
  });
}
