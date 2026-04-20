// ABOUTME: Tests for FeedPlaybackConstants — shared Vine-loop cap.
// ABOUTME: Covers constant values shared across legacy + pooled playback paths.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/feed_playback_constants.dart';

void main() {
  group(FeedPlaybackConstants, () {
    test('maxLoopDuration is 6.3 seconds', () {
      expect(
        FeedPlaybackConstants.maxLoopDuration,
        equals(const Duration(milliseconds: 6300)),
      );
    });
  });
}
