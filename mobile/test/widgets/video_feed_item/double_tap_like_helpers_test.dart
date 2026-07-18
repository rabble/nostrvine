// ABOUTME: Tests for resolveDoubleTapLikeAction — the pure decision behind the
// ABOUTME: double-tap-to-like gesture, including the "can't like your own
// ABOUTME: video" guard that the like button already enforces.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/video_feed_item/double_tap_like_helpers.dart';

void main() {
  group('resolveDoubleTapLikeAction', () {
    test(
      'likes and animates when a not-yet-liked other video is double-tapped',
      () {
        final action = resolveDoubleTapLikeAction(
          isOwnVideo: false,
          contentWarningBlocking: false,
          alreadyLiked: false,
        );

        expect(action, DoubleTapLikeAction.likeAndAnimate);
      },
    );

    test('only animates when an already-liked video is double-tapped', () {
      // Double-tap must never unlike, so an already-liked video just replays
      // the heart animation.
      final action = resolveDoubleTapLikeAction(
        isOwnVideo: false,
        contentWarningBlocking: false,
        alreadyLiked: true,
      );

      expect(action, DoubleTapLikeAction.animateOnly);
    });

    test("ignores the gesture on the viewer's own video", () {
      // Regression guard: double-tapping your own video (e.g. from your
      // profile) must not like it — mirrors LikeActionButton.
      final action = resolveDoubleTapLikeAction(
        isOwnVideo: true,
        contentWarningBlocking: false,
        alreadyLiked: false,
      );

      expect(action, DoubleTapLikeAction.ignore);
    });

    test('ignores own video that already carries a self-like', () {
      // Real data, not hypothetical: the pre-fix bug published self-likes, and
      // other Nostr clients can too. Pins that the own-video guard is checked
      // before alreadyLiked — animateOnly here would replay the heart on the
      // owner's own video.
      final action = resolveDoubleTapLikeAction(
        isOwnVideo: true,
        contentWarningBlocking: false,
        alreadyLiked: true,
      );

      expect(action, DoubleTapLikeAction.ignore);
    });

    test('ignores the gesture while a content warning is blocking', () {
      final action = resolveDoubleTapLikeAction(
        isOwnVideo: false,
        contentWarningBlocking: true,
        alreadyLiked: false,
      );

      expect(action, DoubleTapLikeAction.ignore);
    });
  });
}
