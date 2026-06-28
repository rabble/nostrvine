import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as editor;

void main() {
  DivineVideoClip validClip() => DivineVideoClip(
    id: 'c1',
    video: editor.EditorVideo.file(File('/docs/clip.mp4')),
    duration: const Duration(seconds: 5),
    recordedAt: DateTime(2024),
    targetAspectRatio: model.AspectRatio.square,
    originalAspectRatio: 1,
  );

  group('DivineVideoClip.fromJson corrupt data', () {
    test('round-trips a valid clip', () {
      final restored = DivineVideoClip.fromJson(
        validClip().toJson(),
        '/docs',
        useOriginalPath: true,
      );
      expect(restored.id, equals('c1'));
    });

    test('throws FormatException when filePath is null', () {
      final json = validClip().toJson()..['filePath'] = null;
      expect(
        () => DivineVideoClip.fromJson(json, '/docs', useOriginalPath: true),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when filePath is absent', () {
      final json = validClip().toJson()..remove('filePath');
      expect(
        () => DivineVideoClip.fromJson(json, '/docs', useOriginalPath: true),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when id is null', () {
      final json = validClip().toJson()..['id'] = null;
      expect(
        () => DivineVideoClip.fromJson(json, '/docs', useOriginalPath: true),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when recordedAt/createdAt is absent', () {
      final json = validClip().toJson()
        ..remove('recordedAt')
        ..remove('createdAt');
      expect(
        () => DivineVideoClip.fromJson(json, '/docs', useOriginalPath: true),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when durationMs is null', () {
      final json = validClip().toJson()..['durationMs'] = null;
      expect(
        () => DivineVideoClip.fromJson(json, '/docs', useOriginalPath: true),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException when durationMs is absent', () {
      final json = validClip().toJson()..remove('durationMs');
      expect(
        () => DivineVideoClip.fromJson(json, '/docs', useOriginalPath: true),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
