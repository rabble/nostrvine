import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Apple native player threading contract', () {
    for (final platform in ['ios', 'macos']) {
      test('$platform sends Flutter event updates on the main thread', () {
        final source = _appleSourceFile(platform).readAsStringSync();

        expect(
          source,
          contains('Thread.isMainThread'),
          reason:
              'FlutterEventSink must not be called from AVFoundation/KVO '
              'callback queues.',
        );
        expect(source, contains('DispatchQueue.main.async'));
        expect(source, contains('sendStateUpdateOnMain'));
      });

      test('$platform uses native queue-based looping', () {
        final source = _appleSourceFile(platform).readAsStringSync();

        expect(
          source,
          contains('AVQueuePlayer'),
          reason:
              'Apple loop playback should use a queue player so the next '
              'iteration can be prepared before the current one ends.',
        );
        expect(
          source,
          contains('AVPlayerLooper'),
          reason:
              'Manual AVPlayerItemDidPlayToEndTime seek-and-replay loops '
              'can create an end-of-item playback gap.',
        );
        expect(
          source,
          isNot(contains('player?.seek(to: .zero)')),
          reason:
              'Looping must not restart by seeking after the item has already '
              'finished.',
        );
      });
    }
  });
}

File _appleSourceFile(String platform) {
  final packageRelative = File(
    '$platform/Classes/DivineVideoPlayerInstance.swift',
  );
  if (packageRelative.existsSync()) {
    return packageRelative;
  }

  return File(
    'packages/divine_video_player/'
    '$platform/Classes/DivineVideoPlayerInstance.swift',
  );
}
