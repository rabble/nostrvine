import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/video_editor/clip_media_duration.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

VideoMetadata _metadata({
  required Duration duration,
  Duration? audioDuration,
}) => VideoMetadata(
  duration: duration,
  audioDuration: audioDuration,
  extension: 'mp4',
  fileSize: 1024,
  resolution: const Size(720, 1280),
  rotation: 0,
  bitrate: 2000000,
);

void main() {
  group('commonTrackEnd', () {
    test('returns the audio end when the audio writer stopped first', () {
      final result = _metadata(
        duration: const Duration(milliseconds: 3000),
        audioDuration: const Duration(milliseconds: 2931),
      );

      expect(
        commonTrackEnd(result),
        equals(const Duration(milliseconds: 2931)),
      );
    });

    test('returns null when both tracks already end together', () {
      final result = _metadata(
        duration: const Duration(milliseconds: 3000),
        audioDuration: const Duration(milliseconds: 3000),
      );

      expect(commonTrackEnd(result), isNull);
    });

    test('returns null for a clip with no audio track', () {
      final result = _metadata(duration: const Duration(milliseconds: 3000));

      expect(commonTrackEnd(result), isNull);
    });

    test('trims a shortfall exactly at the tolerance', () {
      final result = _metadata(
        duration: const Duration(milliseconds: 3000),
        audioDuration: const Duration(milliseconds: 2500),
      );

      expect(
        commonTrackEnd(result),
        equals(const Duration(milliseconds: 2500)),
      );
    });

    test('leaves a clip that outlasts its audio beyond the tolerance', () {
      final result = _metadata(
        duration: const Duration(milliseconds: 3000),
        audioDuration: const Duration(milliseconds: 2499),
      );

      expect(commonTrackEnd(result), isNull);
    });

    test('leaves a stop-motion still held past a short sound', () {
      final result = _metadata(
        duration: const Duration(seconds: 6),
        audioDuration: const Duration(milliseconds: 800),
      );

      expect(commonTrackEnd(result), isNull);
    });
  });
}
