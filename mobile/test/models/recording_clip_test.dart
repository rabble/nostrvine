// ABOUTME: Tests for RecordingClip model - segment data with thumbnail support
// ABOUTME: Validates serialization, ordering, and duration calculations

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:path/path.dart' as p;
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group('RecordingClip', () {
    test('creates clip with required fields', () async {
      final clip = DivineVideoClip(
        id: 'clip_001',
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 2),
        recordedAt: DateTime(2025, 12, 13, 10),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      expect(clip.id, equals('clip_001'));
      expect(await clip.video.safeFilePath(), equals('/path/to/video.mp4'));
      expect(clip.duration.inSeconds, equals(2));
      expect(clip.thumbnailPath, isNull);
      expect(clip.targetAspectRatio, equals(model.AspectRatio.vertical));
    });

    test('creates clip with optional fields', () {
      final clip = DivineVideoClip(
        id: 'clip_001',
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 2),
        recordedAt: DateTime(2025, 12, 13, 10),
        thumbnailPath: '/path/to/thumb.jpg',
        targetAspectRatio: model.AspectRatio.square,
        originalAspectRatio: 9 / 16,
      );

      expect(clip.thumbnailPath, equals('/path/to/thumb.jpg'));
      expect(clip.targetAspectRatio, equals(model.AspectRatio.square));
    });

    test('durationInSeconds returns correct value', () {
      final clip = DivineVideoClip(
        id: 'clip_001',
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(milliseconds: 2500),
        recordedAt: DateTime.now(),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      expect(clip.durationInSeconds, equals(2.5));
    });

    test('copyWith creates new instance with updated id', () {
      final clip = DivineVideoClip(
        id: 'clip_001',
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 2),
        recordedAt: DateTime.now(),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      final updated = clip.copyWith(id: 'clip_002');

      expect(updated.id, equals('clip_002'));
      expect(updated.duration, equals(clip.duration));
    });

    test('copyWith creates new instance with updated duration', () async {
      final clip = DivineVideoClip(
        id: 'clip_001',
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 2),
        recordedAt: DateTime.now(),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      final updated = clip.copyWith(duration: const Duration(seconds: 3));

      expect(updated.duration, equals(const Duration(seconds: 3)));
      expect(updated.id, equals(clip.id));
      expect(await updated.video.safeFilePath(), equals('/path/to/video.mp4'));
    });

    test('copyWith creates new instance with updated thumbnailPath', () {
      final clip = DivineVideoClip(
        id: 'clip_001',
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 2),
        recordedAt: DateTime.now(),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      final updated = clip.copyWith(thumbnailPath: '/path/to/thumb.jpg');

      expect(updated.thumbnailPath, equals('/path/to/thumb.jpg'));
      expect(updated.id, equals(clip.id));
    });

    test('copyWith creates new instance with updated aspectRatio', () {
      final clip = DivineVideoClip(
        id: 'clip_001',
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 2),
        recordedAt: DateTime.now(),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      final updated = clip.copyWith(
        targetAspectRatio: model.AspectRatio.vertical,
      );

      expect(updated.targetAspectRatio, equals(model.AspectRatio.vertical));
      expect(updated.id, equals(clip.id));
    });

    test('toJson serializes all fields correctly', () {
      final clip = DivineVideoClip(
        id: 'clip_001',
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(milliseconds: 2500),
        recordedAt: DateTime(2025, 12, 13, 10),
        thumbnailPath: '/path/to/thumb.jpg',
        targetAspectRatio: model.AspectRatio.square,
        originalAspectRatio: 9 / 16,
      );

      final json = clip.toJson();

      expect(json['id'], equals('clip_001'));
      // toJson stores only filenames for iOS compatibility
      expect(json['filePath'], equals('video.mp4'));
      expect(json['durationMs'], equals(2500));
      expect(json['recordedAt'], equals('2025-12-13T10:00:00.000'));
      expect(json['thumbnailPath'], equals('thumb.jpg'));
      expect(json['targetAspectRatio'], equals('square'));
      expect(json['originalAspectRatio'], equals(9 / 16));
    });

    test('toJson handles null optional fields', () {
      final clip = DivineVideoClip(
        id: 'clip_001',
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(milliseconds: 2500),
        recordedAt: DateTime(2025, 12, 13, 10),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      final json = clip.toJson();

      expect(json['thumbnailPath'], isNull);
      expect(
        json['targetAspectRatio'],
        equals(model.AspectRatio.vertical.name),
      );
    });

    test('fromJson deserializes all fields correctly', () async {
      final json = {
        'id': 'clip_001',
        'filePath': 'video.mp4',
        'durationMs': 2500,
        'recordedAt': '2025-12-13T10:00:00.000',
        'thumbnailPath': 'thumb.jpg',
        'aspectRatio': 'square',
      };

      final clip = DivineVideoClip.fromJson(json, '/path/to');

      expect(clip.id, equals('clip_001'));
      // Path resolution uses platform separator, so check it ends with the filename
      final filePath = await clip.video.safeFilePath();
      expect(filePath, endsWith('video.mp4'));
      expect(filePath, contains('path'));
      expect(clip.duration, equals(const Duration(milliseconds: 2500)));
      expect(clip.recordedAt, equals(DateTime(2025, 12, 13, 10)));
      expect(clip.thumbnailPath, endsWith('thumb.jpg'));
      expect(clip.targetAspectRatio, equals(model.AspectRatio.square));
    });

    test('fromJson handles null optional fields', () {
      final json = {
        'id': 'clip_001',
        'filePath': 'video.mp4',
        'durationMs': 2500,
        'recordedAt': '2025-12-13T10:00:00.000',
      };

      final clip = DivineVideoClip.fromJson(json, '/path/to');

      expect(clip.thumbnailPath, isNull);
      expect(clip.targetAspectRatio, model.AspectRatio.square);
    });

    test('toJson and fromJson roundtrip preserves data', () async {
      final clip = DivineVideoClip(
        id: 'clip_001',
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(milliseconds: 2500),
        recordedAt: DateTime(2025, 12, 13, 10),
        thumbnailPath: '/path/to/thumb.jpg',
        targetAspectRatio: model.AspectRatio.vertical,
        originalAspectRatio: 9 / 16,
      );

      final json = clip.toJson();
      // Roundtrip: use same base path as original file
      final restored = DivineVideoClip.fromJson(json, '/path/to');

      expect(restored.id, equals(clip.id));
      // Both should end with same filename
      final originalPath = await clip.video.safeFilePath();
      final restoredPath = await restored.video.safeFilePath();
      expect(restoredPath, endsWith('video.mp4'));
      expect(originalPath, endsWith('video.mp4'));
      expect(restored.duration, equals(clip.duration));
      // Thumbnail paths both end with same filename
      expect(restored.thumbnailPath, endsWith('thumb.jpg'));
      expect(restored.targetAspectRatio, equals(clip.targetAspectRatio));
    });

    test('toString returns formatted string', () {
      final clip = DivineVideoClip(
        id: 'clip_001',
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(milliseconds: 2500),
        recordedAt: DateTime.now(),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      expect(
        clip.toString(),
        equals('RecordingClip(id: clip_001, duration: 2.5s)'),
      );
    });

    test('fromJson with unknown aspectRatio defaults to square', () {
      final json = {
        'id': 'clip_001',
        'filePath': 'video.mp4',
        'durationMs': 2500,
        'recordedAt': '2025-12-13T10:00:00.000',
        'aspectRatio': 'unknown_ratio',
      };

      final clip = DivineVideoClip.fromJson(json, '/path/to');

      expect(clip.targetAspectRatio, equals(model.AspectRatio.square));
    });

    group('proofManifestJson', () {
      test('defaults to null', () {
        final clip = DivineVideoClip(
          id: 'clip_001',
          video: EditorVideo.file('/path/to/video.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime(2025, 12, 13, 10),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );

        expect(clip.proofManifestJson, isNull);
      });

      test('can be set via constructor', () {
        final clip = DivineVideoClip(
          id: 'clip_001',
          video: EditorVideo.file('/path/to/video.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime(2025, 12, 13, 10),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
          proofManifestJson: '{"hash":"abc123"}',
        );

        expect(clip.proofManifestJson, equals('{"hash":"abc123"}'));
      });

      test('copyWith updates proofManifestJson', () {
        final clip = DivineVideoClip(
          id: 'clip_001',
          video: EditorVideo.file('/path/to/video.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime(2025, 12, 13, 10),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );

        final updated = clip.copyWith(
          proofManifestJson: '{"hash":"abc123"}',
        );

        expect(updated.proofManifestJson, equals('{"hash":"abc123"}'));
        expect(updated.id, equals(clip.id));
      });

      test('copyWith preserves proofManifestJson when not specified', () {
        final clip = DivineVideoClip(
          id: 'clip_001',
          video: EditorVideo.file('/path/to/video.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime(2025, 12, 13, 10),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
          proofManifestJson: '{"hash":"abc123"}',
        );

        final updated = clip.copyWith(
          thumbnailPath: '/path/to/thumb.jpg',
        );

        expect(updated.proofManifestJson, equals('{"hash":"abc123"}'));
      });

      test('copyWith clears proofManifestJson with clearProofManifestJson', () {
        final clip = DivineVideoClip(
          id: 'clip_001',
          video: EditorVideo.file('/path/to/video.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime(2025, 12, 13, 10),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
          proofManifestJson: '{"hash":"abc123"}',
        );

        final updated = clip.copyWith(clearProofManifestJson: true);

        expect(updated.proofManifestJson, isNull);
      });

      test('clearProofManifestJson takes precedence over new value', () {
        final clip = DivineVideoClip(
          id: 'clip_001',
          video: EditorVideo.file('/path/to/video.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime(2025, 12, 13, 10),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
          proofManifestJson: '{"hash":"abc123"}',
        );

        final updated = clip.copyWith(
          proofManifestJson: '{"hash":"new"}',
          clearProofManifestJson: true,
        );

        expect(updated.proofManifestJson, isNull);
      });

      test('toJson includes proofManifestJson when present', () {
        final clip = DivineVideoClip(
          id: 'clip_001',
          video: EditorVideo.file('/path/to/video.mp4'),
          duration: const Duration(milliseconds: 2500),
          recordedAt: DateTime(2025, 12, 13, 10),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
          proofManifestJson: '{"hash":"abc123"}',
        );

        final json = clip.toJson();

        expect(json['proofManifestJson'], equals('{"hash":"abc123"}'));
      });

      test('toJson omits proofManifestJson when null', () {
        final clip = DivineVideoClip(
          id: 'clip_001',
          video: EditorVideo.file('/path/to/video.mp4'),
          duration: const Duration(milliseconds: 2500),
          recordedAt: DateTime(2025, 12, 13, 10),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );

        final json = clip.toJson();

        expect(json.containsKey('proofManifestJson'), isFalse);
      });

      test('fromJson deserializes proofManifestJson', () {
        final json = {
          'id': 'clip_001',
          'filePath': 'video.mp4',
          'durationMs': 2500,
          'recordedAt': '2025-12-13T10:00:00.000',
          'targetAspectRatio': 'vertical',
          'proofManifestJson': '{"hash":"abc123"}',
        };

        final clip = DivineVideoClip.fromJson(json, '/path/to');

        expect(clip.proofManifestJson, equals('{"hash":"abc123"}'));
      });

      test('fromJson handles missing proofManifestJson', () {
        final json = {
          'id': 'clip_001',
          'filePath': 'video.mp4',
          'durationMs': 2500,
          'recordedAt': '2025-12-13T10:00:00.000',
          'targetAspectRatio': 'vertical',
        };

        final clip = DivineVideoClip.fromJson(json, '/path/to');

        expect(clip.proofManifestJson, isNull);
      });

      test('toJson and fromJson roundtrip preserves proofManifestJson', () {
        final clip = DivineVideoClip(
          id: 'clip_001',
          video: EditorVideo.file('/path/to/video.mp4'),
          duration: const Duration(milliseconds: 2500),
          recordedAt: DateTime(2025, 12, 13, 10),
          targetAspectRatio: model.AspectRatio.vertical,
          originalAspectRatio: 9 / 16,
          proofManifestJson: '{"hash":"abc123","level":"verified"}',
        );

        final json = clip.toJson();
        final restored = DivineVideoClip.fromJson(json, '/path/to');

        expect(
          restored.proofManifestJson,
          equals(clip.proofManifestJson),
        );
      });

      test('roundtrip with complex JSON structure', () {
        const complexJson =
            '{"manifest":{"alg":"sha256","hash":"abc123"},'
            '"assertions":[{"label":"c2pa.actions","data":{"actions":'
            '[{"action":"c2pa.created"}]}}],'
            '"claim_generator":"divine/1.0"}';

        final clip = DivineVideoClip(
          id: 'clip_001',
          video: EditorVideo.file('/path/to/video.mp4'),
          duration: const Duration(milliseconds: 2500),
          recordedAt: DateTime(2025, 12, 13, 10),
          targetAspectRatio: model.AspectRatio.vertical,
          originalAspectRatio: 9 / 16,
          proofManifestJson: complexJson,
        );

        final json = clip.toJson();
        final restored = DivineVideoClip.fromJson(json, '/path/to');

        expect(restored.proofManifestJson, equals(complexJson));
      });

      test(
        'copyWith updates proofManifestJson independently of other fields',
        () {
          final clip = DivineVideoClip(
            id: 'clip_001',
            video: EditorVideo.file('/path/to/video.mp4'),
            duration: const Duration(seconds: 2),
            recordedAt: DateTime(2025, 12, 13, 10),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
            thumbnailPath: '/path/to/thumb.jpg',
          );

          final updated = clip.copyWith(
            proofManifestJson: '{"hash":"abc123"}',
            thumbnailPath: '/path/to/new_thumb.jpg',
            duration: const Duration(seconds: 5),
          );

          expect(updated.proofManifestJson, equals('{"hash":"abc123"}'));
          expect(updated.thumbnailPath, equals('/path/to/new_thumb.jpg'));
          expect(updated.duration, equals(const Duration(seconds: 5)));
          expect(updated.id, equals(clip.id));
        },
      );

      test('copyWith replaces existing proofManifestJson with new value', () {
        final clip = DivineVideoClip(
          id: 'clip_001',
          video: EditorVideo.file('/path/to/video.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime(2025, 12, 13, 10),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
          proofManifestJson: '{"hash":"old"}',
        );

        final updated = clip.copyWith(
          proofManifestJson: '{"hash":"new"}',
        );

        expect(updated.proofManifestJson, equals('{"hash":"new"}'));
      });

      test(
        'clearProofManifestJson does nothing when proof is already null',
        () {
          final clip = DivineVideoClip(
            id: 'clip_001',
            video: EditorVideo.file('/path/to/video.mp4'),
            duration: const Duration(seconds: 2),
            recordedAt: DateTime(2025, 12, 13, 10),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          );

          final updated = clip.copyWith(clearProofManifestJson: true);

          expect(updated.proofManifestJson, isNull);
        },
      );

      test('toJson conditional inclusion: only adds key when non-null', () {
        final clipWithProof = DivineVideoClip(
          id: 'clip_001',
          video: EditorVideo.file('/path/to/video.mp4'),
          duration: const Duration(milliseconds: 2500),
          recordedAt: DateTime(2025, 12, 13, 10),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
          proofManifestJson: '{"hash":"abc123"}',
        );

        final clipWithoutProof = DivineVideoClip(
          id: 'clip_002',
          video: EditorVideo.file('/path/to/video2.mp4'),
          duration: const Duration(milliseconds: 2500),
          recordedAt: DateTime(2025, 12, 13, 10),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );

        final jsonWith = clipWithProof.toJson();
        final jsonWithout = clipWithoutProof.toJson();

        expect(jsonWith.containsKey('proofManifestJson'), isTrue);
        expect(jsonWithout.containsKey('proofManifestJson'), isFalse);
        expect(jsonWith.length, greaterThan(jsonWithout.length));
      });
    });

    group('path round-trip for rendered videos', () {
      test('round-trip resolves to documents directory '
          'when video is in documents directory', () async {
        final documentsPath = p.join('var', 'mobile', 'Documents');
        final videoPath = p.join(documentsPath, 'divine_123456.mp4');
        final thumbPath = p.join(documentsPath, 'thumb.jpg');
        final clip = DivineVideoClip(
          id: 'rendered-clip',
          video: EditorVideo.file(videoPath),
          duration: const Duration(seconds: 3),
          recordedAt: DateTime(2025, 12, 13),
          thumbnailPath: thumbPath,
          targetAspectRatio: model.AspectRatio.vertical,
          originalAspectRatio: 9 / 16,
        );

        final json = clip.toJson();
        final restored = DivineVideoClip.fromJson(json, documentsPath);

        final originalPath = await clip.video.safeFilePath();
        final restoredPath = await restored.video.safeFilePath();
        expect(restoredPath, equals(originalPath));
        expect(restored.thumbnailPath, equals(clip.thumbnailPath));
      });

      test('round-trip does NOT resolve to original path '
          'when video is in temp directory', () async {
        // This test documents the pre-fix behavior:
        // A rendered video in /tmp would serialize to just the basename,
        // but deserialize with the documents path, causing a mismatch.
        final tempPath = p.join('tmp');
        final documentsPath = p.join('var', 'mobile', 'Documents');
        final clip = DivineVideoClip(
          id: 'rendered-clip',
          video: EditorVideo.file(p.join(tempPath, 'divine_123456.mp4')),
          duration: const Duration(seconds: 3),
          recordedAt: DateTime(2025, 12, 13),
          targetAspectRatio: model.AspectRatio.vertical,
          originalAspectRatio: 9 / 16,
        );

        final json = clip.toJson();
        // fromJson resolves against documentsPath, not tempPath
        final restored = DivineVideoClip.fromJson(json, documentsPath);

        final originalPath = await clip.video.safeFilePath();
        final restoredPath = await restored.video.safeFilePath();
        // The paths will differ because the file was in /tmp
        // but fromJson resolves to /var/mobile/Documents
        expect(restoredPath, isNot(equals(originalPath)));
        expect(
          restoredPath,
          equals(p.join(documentsPath, 'divine_123456.mp4')),
        );
      });
    });
  });
}
