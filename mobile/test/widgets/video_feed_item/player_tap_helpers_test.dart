// ABOUTME: Tests for resolvePlayerTapAction — the pure decision behind
// ABOUTME: tap-to-toggle-playback on feed videos, including the stopped-but-not
// ABOUTME: -paused states that should request playback instead of pausing.

import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/video_feed_item/player_tap_helpers.dart';

void main() {
  group('resolvePlayerTapAction', () {
    test('maps every playback status to the expected tap action', () {
      const expectedActions = <PlaybackStatus, PlayerTapAction>{
        PlaybackStatus.idle: PlayerTapAction.play,
        PlaybackStatus.ready: PlayerTapAction.play,
        PlaybackStatus.playing: PlayerTapAction.pause,
        PlaybackStatus.paused: PlayerTapAction.play,
        PlaybackStatus.buffering: PlayerTapAction.pause,
        PlaybackStatus.completed: PlayerTapAction.play,
        PlaybackStatus.error: PlayerTapAction.play,
      };

      expect(expectedActions.keys, unorderedEquals(PlaybackStatus.values));

      for (final MapEntry(key: status, value: expectedAction)
          in expectedActions.entries) {
        expect(
          resolvePlayerTapAction(status),
          expectedAction,
          reason: 'Unexpected tap action for $status',
        );
      }
    });
  });
}
