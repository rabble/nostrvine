import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/models/divine_video_clip.dart';
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
}
