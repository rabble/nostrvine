// ABOUTME: Tests for RecordingClip model - segment data with thumbnail support
// ABOUTME: Validates serialization, ordering, and duration calculations

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/models/recording_clip.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group('RecordingClip', () {
    test('creates clip with required fields', () async {
      final clip = RecordingClip(
        id: 'clip_001',
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 2),
        recordedAt: DateTime(2025, 12, 13, 10, 0, 0),
        aspectRatio: .vertical,
      );

      expect(clip.id, equals('clip_001'));
      expect(await clip.video.safeFilePath(), equals('/path/to/video.mp4'));
      expect(clip.duration.inSeconds, equals(2));
      expect(clip.thumbnailPath, isNull);
      expect(clip.aspectRatio, equals(model.AspectRatio.vertical));
    });

    test('creates clip with optional fields', () {
      final clip = RecordingClip(
        id: 'clip_001',
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 2),
        recordedAt: DateTime(2025, 12, 13, 10, 0, 0),
        thumbnailPath: '/path/to/thumb.jpg',
        aspectRatio: model.AspectRatio.square,
      );

      expect(clip.thumbnailPath, equals('/path/to/thumb.jpg'));
      expect(clip.aspectRatio, equals(model.AspectRatio.square));
    });

    test('durationInSeconds returns correct value', () {
      final clip = RecordingClip(
        id: 'clip_001',
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(milliseconds: 2500),
        recordedAt: DateTime.now(),
        aspectRatio: .vertical,
      );

      expect(clip.durationInSeconds, equals(2.5));
    });

    test('copyWith creates new instance with updated id', () {
      final clip = RecordingClip(
        id: 'clip_001',
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 2),
        recordedAt: DateTime.now(),
        aspectRatio: .vertical,
      );

      final updated = clip.copyWith(id: 'clip_002');

      expect(updated.id, equals('clip_002'));
      expect(updated.duration, equals(clip.duration));
    });

    test('copyWith creates new instance with updated duration', () async {
      final clip = RecordingClip(
        id: 'clip_001',
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 2),
        recordedAt: DateTime.now(),
        aspectRatio: .vertical,
      );

      final updated = clip.copyWith(duration: const Duration(seconds: 3));

      expect(updated.duration, equals(const Duration(seconds: 3)));
      expect(updated.id, equals(clip.id));
      expect(await updated.video.safeFilePath(), equals('/path/to/video.mp4'));
    });

    test('copyWith creates new instance with updated thumbnailPath', () {
      final clip = RecordingClip(
        id: 'clip_001',
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 2),
        recordedAt: DateTime.now(),
        aspectRatio: .vertical,
      );

      final updated = clip.copyWith(thumbnailPath: '/path/to/thumb.jpg');

      expect(updated.thumbnailPath, equals('/path/to/thumb.jpg'));
      expect(updated.id, equals(clip.id));
    });

    test('copyWith creates new instance with updated aspectRatio', () {
      final clip = RecordingClip(
        id: 'clip_001',
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 2),
        recordedAt: DateTime.now(),
        aspectRatio: .vertical,
      );

      final updated = clip.copyWith(aspectRatio: model.AspectRatio.vertical);

      expect(updated.aspectRatio, equals(model.AspectRatio.vertical));
      expect(updated.id, equals(clip.id));
    });

    test('toJson serializes all fields correctly', () {
      final clip = RecordingClip(
        id: 'clip_001',
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(milliseconds: 2500),
        recordedAt: DateTime(2025, 12, 13, 10, 0, 0),
        thumbnailPath: '/path/to/thumb.jpg',
        aspectRatio: model.AspectRatio.square,
      );

      final json = clip.toJson();

      expect(json['id'], equals('clip_001'));
      expect(json['filePath'], equals('/path/to/video.mp4'));
      expect(json['durationMs'], equals(2500));
      expect(json['recordedAt'], equals('2025-12-13T10:00:00.000'));
      expect(json['thumbnailPath'], equals('/path/to/thumb.jpg'));
      expect(json['aspectRatio'], equals('square'));
    });

    test('toJson handles null optional fields', () {
      final clip = RecordingClip(
        id: 'clip_001',
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(milliseconds: 2500),
        recordedAt: DateTime(2025, 12, 13, 10, 0, 0),
        aspectRatio: .vertical,
      );

      final json = clip.toJson();

      expect(json['thumbnailPath'], isNull);
      expect(json['aspectRatio'], equals(model.AspectRatio.vertical.name));
    });

    test('fromJson deserializes all fields correctly', () async {
      final json = {
        'id': 'clip_001',
        'filePath': '/path/to/video.mp4',
        'durationMs': 2500,
        'recordedAt': '2025-12-13T10:00:00.000',
        'thumbnailPath': '/path/to/thumb.jpg',
        'aspectRatio': 'square',
      };

      final clip = RecordingClip.fromJson(json);

      expect(clip.id, equals('clip_001'));
      expect(await clip.video.safeFilePath(), equals('/path/to/video.mp4'));
      expect(clip.duration, equals(const Duration(milliseconds: 2500)));
      expect(clip.recordedAt, equals(DateTime(2025, 12, 13, 10, 0, 0)));
      expect(clip.thumbnailPath, equals('/path/to/thumb.jpg'));
      expect(clip.aspectRatio, equals(model.AspectRatio.square));
    });

    test('fromJson handles null optional fields', () {
      final json = {
        'id': 'clip_001',
        'filePath': '/path/to/video.mp4',
        'durationMs': 2500,
        'recordedAt': '2025-12-13T10:00:00.000',
      };

      final clip = RecordingClip.fromJson(json);

      expect(clip.thumbnailPath, isNull);
      expect(clip.aspectRatio, model.AspectRatio.square);
    });

    test('toJson and fromJson roundtrip preserves data', () async {
      final clip = RecordingClip(
        id: 'clip_001',
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(milliseconds: 2500),
        recordedAt: DateTime(2025, 12, 13, 10, 0, 0),
        thumbnailPath: '/path/to/thumb.jpg',
        aspectRatio: model.AspectRatio.vertical,
      );

      final json = clip.toJson();
      final restored = RecordingClip.fromJson(json);

      expect(restored.id, equals(clip.id));
      expect(
        await restored.video.safeFilePath(),
        await clip.video.safeFilePath(),
      );
      expect(restored.duration, equals(clip.duration));
      expect(restored.thumbnailPath, equals(clip.thumbnailPath));
      expect(restored.aspectRatio, equals(clip.aspectRatio));
    });

    test('toString returns formatted string', () {
      final clip = RecordingClip(
        id: 'clip_001',
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(milliseconds: 2500),
        recordedAt: DateTime.now(),
        aspectRatio: .vertical,
      );

      expect(
        clip.toString(),
        equals('RecordingClip(id: clip_001, duration: 2.5s)'),
      );
    });

    test('fromJson with unknown aspectRatio defaults to square', () {
      final json = {
        'id': 'clip_001',
        'filePath': '/path/to/video.mp4',
        'durationMs': 2500,
        'recordedAt': '2025-12-13T10:00:00.000',
        'aspectRatio': 'unknown_ratio',
      };

      final clip = RecordingClip.fromJson(json);

      expect(clip.aspectRatio, equals(model.AspectRatio.square));
    });
  });
}
