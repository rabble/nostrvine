// ABOUTME: Tests for resolvePlayerTapAction — the pure decision behind
// ABOUTME: tap-to-toggle-playback on feed videos, including the stopped-but-not
// ABOUTME: -paused states whose dead first tap was the #6239 symptom.

import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/video_feed_item/player_tap_helpers.dart';

void main() {
  group('resolvePlayerTapAction', () {
    test('pauses a playing video', () {
      expect(
        resolvePlayerTapAction(PlaybackStatus.playing),
        PlayerTapAction.pause,
      );
    });

    test('plays a paused video', () {
      expect(
        resolvePlayerTapAction(PlaybackStatus.paused),
        PlayerTapAction.play,
      );
    });

    test('plays a ready video that was initialized but never started', () {
      // The #6239 case, observed on an iPhone: the feed had been gated off, so
      // the controller sat in `ready` rather than `paused`. Keying the toggle on
      // isPaused sent this to pause() — the viewer's first tap did nothing and
      // they had to tap the frame twice to start it.
      expect(
        resolvePlayerTapAction(PlaybackStatus.ready),
        PlayerTapAction.play,
      );
    });

    test('restarts a completed clip', () {
      // A non-looping clip that ran to its end is stopped without being
      // `paused`, so a tap has to restart it rather than pause it again.
      expect(
        resolvePlayerTapAction(PlaybackStatus.completed),
        PlayerTapAction.play,
      );
    });

    test('pauses while buffering', () {
      // Buffering means playback is underway, so the tap must stop it —
      // otherwise tapping a slow-loading video issues a redundant play.
      expect(
        resolvePlayerTapAction(PlaybackStatus.buffering),
        PlayerTapAction.pause,
      );
    });

    test('plays an idle player', () {
      expect(resolvePlayerTapAction(PlaybackStatus.idle), PlayerTapAction.play);
    });

    test('every status resolves without falling through', () {
      // The tap target is gated on a rendered first frame, so `error` is not
      // reachable in practice; assert the resolver still answers for it rather
      // than leaving a status unhandled.
      for (final status in PlaybackStatus.values) {
        expect(resolvePlayerTapAction(status), isA<PlayerTapAction>());
      }
    });
  });
}
