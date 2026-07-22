import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as editor;

void main() {
  DivineVideoClip clip(String videoPath) => DivineVideoClip(
    id: 'c1',
    video: editor.EditorVideo.file(File(videoPath)),
    duration: const Duration(seconds: 5),
    recordedAt: DateTime(2024),
    targetAspectRatio: model.AspectRatio.square,
    originalAspectRatio: 1,
  );

  DivineVideoClip stopMotionClip(List<String> framePaths) => DivineVideoClip(
    id: 'sm1',
    stopMotionFrames: [
      for (final path in framePaths)
        StopMotionClipFrame(
          path: path,
          duration: const Duration(milliseconds: 83),
        ),
    ],
    duration: Duration(milliseconds: 83 * framePaths.length),
    recordedAt: DateTime(2024),
    targetAspectRatio: model.AspectRatio.vertical,
    originalAspectRatio: 9 / 16,
  );

  group('DivineVideoClip.hasResolvableVideoFile', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('divine_video_clip_test');
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test('is true when the source video file exists on disk', () async {
      final path = '${tempDir.path}/clip.mp4';
      await File(path).writeAsBytes(const [0]);

      expect(clip(path).hasResolvableVideoFile, isTrue);
    });

    test('is false when the source video file is missing', () {
      expect(
        clip('${tempDir.path}/deleted.mp4').hasResolvableVideoFile,
        isFalse,
      );
    });

    test('is true for a stop-motion clip whose stills all exist', () async {
      final a = '${tempDir.path}/f0.jpg';
      final b = '${tempDir.path}/f1.jpg';
      await File(a).writeAsBytes(const [0]);
      await File(b).writeAsBytes(const [0]);

      expect(stopMotionClip([a, b]).hasResolvableVideoFile, isTrue);
    });

    test('is false for a stop-motion clip with a missing still', () async {
      final a = '${tempDir.path}/f0.jpg';
      await File(a).writeAsBytes(const [0]);

      expect(
        stopMotionClip([a, '${tempDir.path}/gone.jpg']).hasResolvableVideoFile,
        isFalse,
      );
    });

    test(
      'resolves a materialized clip against its mp4, not its cleaned stills',
      () async {
        final path = '${tempDir.path}/rendered.mp4';
        await File(path).writeAsBytes(const [0]);

        // A materialized clip carries a rendered mp4 and may still carry its
        // now-deleted stills. It must resolve against the mp4 that exists, not
        // be dropped as orphaned for the missing stills.
        final materialized = stopMotionClip([
          '${tempDir.path}/gone.jpg',
        ]).copyWith(video: editor.EditorVideo.file(File(path)));

        expect(materialized.hasResolvableVideoFile, isTrue);
      },
    );
  });

  group('DivineVideoClip.isStopMotion (video-first)', () {
    test('is true for a frames-only clip', () {
      expect(stopMotionClip(['/a.jpg']).isStopMotion, isTrue);
    });

    test('is false once a video is present, even if stills remain', () {
      final materialized = stopMotionClip([
        '/a.jpg',
      ]).copyWith(video: editor.EditorVideo.file(File('/rendered.mp4')));

      expect(materialized.isStopMotion, isFalse);
    });

    test('is false for a normal video clip', () {
      expect(clip('/v.mp4').isStopMotion, isFalse);
    });
  });

  group('DivineVideoClip.copyWith clearStopMotionFrames', () {
    test('drops the stills so the result is a plain video clip', () {
      final materialized = stopMotionClip(['/a.jpg', '/b.jpg']).copyWith(
        video: editor.EditorVideo.file(File('/rendered.mp4')),
        clearStopMotionFrames: true,
      );

      expect(materialized.stopMotionFrames, isNull);
      expect(materialized.isStopMotion, isFalse);
    });

    test('keeps the stills when the flag is not set', () {
      final copy = stopMotionClip(['/a.jpg']).copyWith(
        video: editor.EditorVideo.file(File('/rendered.mp4')),
      );

      expect(copy.stopMotionFrames, hasLength(1));
    });
  });

  group('DivineVideoClip.sourceStartOffset', () {
    test('defaults to zero and survives copyWith', () {
      final original = clip('/videos/clip.mp4');
      expect(original.sourceStartOffset, equals(Duration.zero));

      final shifted = original.copyWith(
        sourceStartOffset: const Duration(seconds: 3),
      );
      expect(shifted.sourceStartOffset, equals(const Duration(seconds: 3)));

      // Unrelated copyWith calls (e.g. the render swapping the video file)
      // must not reset the offset — losing it re-anchors the timeline
      // thumbnail raster and visibly shifts the strip.
      final trimmed = shifted.copyWith(trimStart: const Duration(seconds: 1));
      expect(trimmed.sourceStartOffset, equals(const Duration(seconds: 3)));
    });

    test('round-trips through JSON and defaults to zero when absent', () {
      final shifted = clip('/videos/clip.mp4').copyWith(
        sourceStartOffset: const Duration(milliseconds: 3210),
      );

      final restored = DivineVideoClip.fromJson(shifted.toJson(), '/videos');
      expect(
        restored.sourceStartOffset,
        equals(const Duration(milliseconds: 3210)),
      );

      // Old drafts/history entries have no key — must default to zero.
      final legacy = DivineVideoClip.fromJson(
        clip('/videos/clip.mp4').toJson(),
        '/videos',
      );
      expect(legacy.sourceStartOffset, equals(Duration.zero));
    });
  });

  group('DivineVideoClip.minTrimStart', () {
    test('defaults to zero and survives copyWith', () {
      final original = clip('/videos/clip.mp4');
      expect(original.minTrimStart, equals(Duration.zero));

      final floored = original.copyWith(
        minTrimStart: const Duration(seconds: 2),
      );
      expect(floored.minTrimStart, equals(const Duration(seconds: 2)));

      // An unrelated copyWith (e.g. a later trim) must keep the floor.
      final trimmed = floored.copyWith(trimStart: const Duration(seconds: 3));
      expect(trimmed.minTrimStart, equals(const Duration(seconds: 2)));
    });

    test('round-trips through JSON and defaults to zero when absent', () {
      final floored = clip('/videos/clip.mp4').copyWith(
        minTrimStart: const Duration(milliseconds: 2500),
      );

      final restored = DivineVideoClip.fromJson(floored.toJson(), '/videos');
      expect(
        restored.minTrimStart,
        equals(const Duration(milliseconds: 2500)),
      );

      // Old drafts/history entries have no key — must default to zero.
      final legacy = DivineVideoClip.fromJson(
        clip('/videos/clip.mp4').toJson(),
        '/videos',
      );
      expect(legacy.minTrimStart, equals(Duration.zero));
    });
  });

  group('DivineVideoClip.budgetDuration', () {
    test('equals duration for a normal clip', () {
      expect(
        clip('/videos/clip.mp4').budgetDuration,
        equals(const Duration(seconds: 5)),
      );
    });

    test('subtracts minTrimStart so a split end half is not double-counted', () {
      // A 5s clip split at 2s: start half [0,2s], end half [2s,5s] on the same
      // file with minTrimStart 2s. Summing budgetDuration must recover the
      // original 5s, not 2s + 5s = 7s.
      final startHalf = clip('/videos/clip.mp4').copyWith(
        duration: const Duration(seconds: 2),
      );
      final endHalf = clip('/videos/clip.mp4').copyWith(
        trimStart: const Duration(seconds: 2),
        minTrimStart: const Duration(seconds: 2),
      );
      expect(startHalf.budgetDuration, equals(const Duration(seconds: 2)));
      expect(endHalf.budgetDuration, equals(const Duration(seconds: 3)));
      expect(
        startHalf.budgetDuration + endHalf.budgetDuration,
        equals(const Duration(seconds: 5)),
      );
    });
  });
}
