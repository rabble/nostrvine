import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/constants/video_editor_constants.dart';

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

  test('feed playback caps video length via a native clip end', () {
    final feedVideosSource = File(
      'lib/widgets/video_feed_item/feed_videos.dart',
    ).readAsStringSync();

    expect(
      feedVideosSource,
      contains('maxPlaybackDuration: AppConstants.maxFeedPlaybackDuration'),
      reason:
          'Without the cap a 60s file referenced by a foreign client plays in '
          'full in the feed.',
    );
  });

  test('every feed source is opened with the cap applied', () {
    // Cache hit, first load, source failover and processing retry each re-open
    // the player, so a missed site lets a long video escape the cap on that
    // path alone.
    const capArgumentByFile = {
      'packages/infinite_video_feed/lib/src/widgets/infinite_video_feed.dart':
          'end: widget.maxPlaybackDuration',
      'packages/infinite_video_feed/lib/src/utils/source_loader.dart':
          'end: maxPlaybackDuration',
    };

    for (final entry in capArgumentByFile.entries) {
      final source = File(entry.key).readAsStringSync();
      final clipCount = RegExp(
        r'VideoClip\.(network|file)\(',
      ).allMatches(source).length;

      expect(
        clipCount,
        greaterThan(0),
        reason: 'No clips found in ${entry.key}',
      );
      expect(
        entry.value.allMatches(source),
        hasLength(clipCount),
        reason: '${entry.key} opens a clip without applying the cap.',
      );
    }
  });

  test('the cap clears classic Vine assets and is not the recording limit', () {
    // Longest classic Vine measured with ffprobe on media.divine.video (#6421).
    // Capping below this would cut the musical loop point off every one of
    // them.
    const longestClassicVine = Duration(milliseconds: 6533);

    expect(
      AppConstants.maxFeedPlaybackDuration,
      greaterThan(longestClassicVine),
    );
    expect(
      AppConstants.maxFeedPlaybackDuration,
      greaterThan(VideoEditorConstants.maxDuration),
      reason:
          'maxDuration is the 6.3s recording limit, not a playback cap; '
          'reusing it truncates classic Vines.',
    );
  });
}
