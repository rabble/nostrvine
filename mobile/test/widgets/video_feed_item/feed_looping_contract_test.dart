import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('feed playback uses native looping instead of 6.3s seek enforcement', () {
    final feedVideosSource = File(
      'lib/widgets/video_feed_item/feed_videos.dart',
    ).readAsStringSync();
    final pooledPlayerSource = File(
      'packages/infinite_video_feed/lib/src/widgets/infinite_video_feed.dart',
    ).readAsStringSync();

    expect(pooledPlayerSource, contains('setLooping(looping: true)'));
    expect(feedVideosSource, isNot(contains('maxLoopDuration:')));
    expect(
      feedVideosSource,
      isNot(contains('maxLoopDuration: VideoEditorConstants.maxDuration')),
      reason:
          'Feed playback must not restart long videos with a Dart seek at the '
          '6.3s recording limit; seek-based restarts create audible seams.',
    );
  });
}
