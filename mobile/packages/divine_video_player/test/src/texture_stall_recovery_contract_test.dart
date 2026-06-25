import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VideoTextureOutput stalled-texture recovery contract', () {
    test('re-primes the output when the clock advances but frames stall', () {
      final source = _textureOutputSourceFile().readAsStringSync();

      // The display-link poll must actively recover from the
      // "playing but frozen" deadlock instead of waiting for the next
      // loop flush — the symptom users hit on slow connections / cold
      // playback (audio continues, picture frozen for a full loop).
      expect(
        source,
        contains('recoverStalledTextureIfNeeded'),
        reason:
            'A stalled, actively-playing texture must self-recover '
            'mid-clip, not only on the loop-restart flush.',
      );
      expect(
        source,
        contains(
          'requestNotificationOfMediaDataChange(withAdvanceInterval: 0)',
        ),
        reason:
            'Recovery re-arms the output with the same media-data '
            'notification the loop flush uses to unstick the pull.',
      );
    });

    test('guards recovery against paused players and genuine underruns', () {
      final source = _textureOutputSourceFile().readAsStringSync();

      // rate > 0 keeps a paused player (legitimately holding its last
      // frame) from firing; the advance check keeps a buffer underrun
      // (player clock frozen) from firing.
      expect(source, contains('player.rate > 0'));
      expect(source, contains('lastDeliveredItemTime'));
      expect(source, contains('stalledTextureAdvanceSeconds'));
    });

    test('throttles recovery re-arms', () {
      final source = _textureOutputSourceFile().readAsStringSync();

      expect(source, contains('stallRecoveryIntervalSeconds'));
      expect(source, contains('nextStallRecoveryTime'));
    });

    test('resets the last-delivered marker on attach and flush', () {
      final source = _textureOutputSourceFile().readAsStringSync();

      // Both attach (new item) and outputSequenceWasFlushed (loop
      // restart) must clear the marker so a post-reset tick can't
      // compare against a stale time and false-trigger recovery.
      final invalidations = RegExp(
        'lastDeliveredItemTime = .invalid',
      ).allMatches(source).length;
      expect(
        invalidations,
        greaterThanOrEqualTo(2),
        reason: 'lastDeliveredItemTime must reset on both attach and flush.',
      );
    });
  });
}

/// The iOS and macOS players share a single Darwin source tree
/// (`darwin/divine_video_player/Sources/`), so the contract is asserted
/// once against the shared file.
File _textureOutputSourceFile() {
  final packageRelative = File(
    'darwin/divine_video_player/Sources/divine_video_player/'
    'VideoTextureOutput.swift',
  );
  if (packageRelative.existsSync()) {
    return packageRelative;
  }

  return File(
    'packages/divine_video_player/'
    'darwin/divine_video_player/Sources/divine_video_player/'
    'VideoTextureOutput.swift',
  );
}
