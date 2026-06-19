// ABOUTME: Tests for ClipLibraryService - persistent storage for video clips
// ABOUTME: Covers save, load, delete, and thumbnail generation for clips

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as models show AspectRatio;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group('ClipLibraryService', () {
    late AppDatabase database;
    late ClipLibraryService service;

    setUp(() async {
      database = AppDatabase.test(NativeDatabase.memory());
      service = ClipLibraryService(
        clipsDao: database.clipsDao,
        draftsDao: database.draftsDao,
      );
    });

    tearDown(() async {
      await database.close();
    });

    group('saveClip', () {
      test('saves a clip and retrieves it', () async {
        final clip = DivineVideoClip(
          id: 'clip_123',
          video: EditorVideo.file('/tmp/test_video.mp4'),
          thumbnailPath: '/tmp/test_thumb.jpg',
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          targetAspectRatio: .square,
          originalAspectRatio: 9 / 16,
        );

        await service.saveClip(clip);
        final clips = await service.getAllClips();

        expect(clips.length, 1);
        expect(clips.first.id, 'clip_123');
        // Path uses platform separator, so check filename
        expect(
          await clips.first.video.safeFilePath(),
          endsWith('test_video.mp4'),
        );
      });

      test('updates existing clip with same ID', () async {
        final clip1 = DivineVideoClip(
          id: 'clip_123',
          video: EditorVideo.file('/tmp/test_video.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          targetAspectRatio: .square,
          originalAspectRatio: 9 / 16,
        );

        final clip2 = DivineVideoClip(
          id: 'clip_123',
          video: EditorVideo.file('/tmp/test_video.mp4'),
          thumbnailPath: '/tmp/updated_thumb.jpg',
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          targetAspectRatio: .square,
          originalAspectRatio: 9 / 16,
        );

        await service.saveClip(clip1);
        await service.saveClip(clip2);
        final clips = await service.getAllClips();

        expect(clips.length, 1);
        // Path uses platform separator, so check filename
        expect(clips.first.thumbnailPath, endsWith('updated_thumb.jpg'));
      });
    });

    group('softDelete', () {
      test('hides clip from active queries but keeps row', () async {
        final clip = DivineVideoClip(
          id: 'clip_to_trash',
          video: EditorVideo.file('/tmp/test_video.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          targetAspectRatio: .square,
          originalAspectRatio: 9 / 16,
        );

        await service.saveClip(clip);
        expect((await service.getAllClips()).length, 1);

        final trashed = await service.softDelete('clip_to_trash');
        expect(trashed, isTrue);
        expect(await service.getAllClips(), isEmpty);
        expect(
          (await service.getTrashedClips()).map((c) => c.id),
          contains('clip_to_trash'),
        );
      });

      test('returns false when clip ID not found', () async {
        final result = await service.softDelete('nonexistent_clip');
        expect(result, isFalse);
      });
    });

    group('restore', () {
      test('moves clip back from trash to active', () async {
        final clip = DivineVideoClip(
          id: 'roundtrip_clip',
          video: EditorVideo.file('/tmp/test_video.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          targetAspectRatio: .square,
          originalAspectRatio: 9 / 16,
        );

        await service.saveClip(clip);
        await service.softDelete('roundtrip_clip');
        expect(await service.getAllClips(), isEmpty);

        final restored = await service.restore('roundtrip_clip');
        expect(restored, isTrue);
        expect(
          (await service.getAllClips()).map((c) => c.id),
          contains('roundtrip_clip'),
        );
        expect(await service.getTrashedClips(), isEmpty);
      });
    });

    group('hardDelete', () {
      test('removes clip permanently', () async {
        final clip = DivineVideoClip(
          id: 'clip_to_delete',
          video: EditorVideo.file('/tmp/test_video.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          targetAspectRatio: .square,
          originalAspectRatio: 9 / 16,
        );

        await service.saveClip(clip);
        expect((await service.getAllClips()).length, 1);

        await service.hardDelete('clip_to_delete');
        expect((await service.getAllClips()).length, 0);
        expect((await service.getTrashedClips()).length, 0);
      });

      test('does nothing when clip ID not found', () async {
        final clip = DivineVideoClip(
          id: 'existing_clip',
          video: EditorVideo.file('/tmp/test_video.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          targetAspectRatio: .square,
          originalAspectRatio: 9 / 16,
        );

        await service.saveClip(clip);
        await service.hardDelete('nonexistent_clip');

        expect((await service.getAllClips()).length, 1);
      });
    });

    group('purgeExpiredTrash', () {
      test('hard-deletes trashed clips older than retention', () async {
        final clip = DivineVideoClip(
          id: 'old_trashed',
          video: EditorVideo.file('/tmp/test_video.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          targetAspectRatio: .square,
          originalAspectRatio: 9 / 16,
        );

        await service.saveClip(clip);
        await service.softDelete('old_trashed');

        // Backdate the deleted_at to 31 days ago so it's beyond a 30-day
        // retention window.
        await database.customStatement(
          'UPDATE clips SET deleted_at = ? WHERE id = ?',
          [
            DateTime.now()
                    .subtract(const Duration(days: 31))
                    .millisecondsSinceEpoch ~/
                1000,
            'old_trashed',
          ],
        );

        final purged = await service.purgeExpiredTrash();
        expect(purged, 1);
        expect(await service.getTrashedClips(), isEmpty);
      });

      test('keeps trashed clips within retention window', () async {
        final clip = DivineVideoClip(
          id: 'recent_trashed',
          video: EditorVideo.file('/tmp/test_video.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          targetAspectRatio: .square,
          originalAspectRatio: 9 / 16,
        );

        await service.saveClip(clip);
        await service.softDelete('recent_trashed');

        final purged = await service.purgeExpiredTrash();
        expect(purged, 0);
        expect((await service.getTrashedClips()).length, 1);
      });
    });

    group('getAllClips', () {
      test('returns empty list when no clips saved', () async {
        final clips = await service.getAllClips();
        expect(clips, isEmpty);
      });

      test('returns clips sorted by creation date (newest first)', () async {
        final oldClip = DivineVideoClip(
          id: 'old_clip',
          video: EditorVideo.file('/tmp/old.mp4'),
          duration: const Duration(seconds: 1),
          recordedAt: DateTime.now().subtract(const Duration(days: 1)),
          targetAspectRatio: .square,
          originalAspectRatio: 9 / 16,
        );

        final newClip = DivineVideoClip(
          id: 'new_clip',
          video: EditorVideo.file('/tmp/new.mp4'),
          duration: const Duration(seconds: 1),
          recordedAt: DateTime.now(),
          targetAspectRatio: .square,
          originalAspectRatio: 9 / 16,
        );

        await service.saveClip(oldClip);
        await service.saveClip(newClip);

        final clips = await service.getAllClips();
        expect(clips.first.id, 'new_clip');
        expect(clips.last.id, 'old_clip');
      });
    });

    group('getClipById', () {
      test('returns clip when found', () async {
        final clip = DivineVideoClip(
          id: 'find_me',
          video: EditorVideo.file('/tmp/test.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );

        await service.saveClip(clip);
        final found = await service.getClipById('find_me');

        expect(found, isNotNull);
        expect(found!.id, 'find_me');
        expect(found.targetAspectRatio, models.AspectRatio.vertical);
      });

      test('returns null when clip not found', () async {
        final found = await service.getClipById('nonexistent');
        expect(found, isNull);
      });
    });

    group('clearAllClips', () {
      test('removes all clips', () async {
        for (var i = 0; i < 5; i++) {
          await service.saveClip(
            DivineVideoClip(
              id: 'clip_$i',
              video: EditorVideo.file('/tmp/video_$i.mp4'),
              duration: const Duration(seconds: 1),
              recordedAt: DateTime.now(),
              targetAspectRatio: .vertical,
              originalAspectRatio: 9 / 16,
            ),
          );
        }

        expect((await service.getAllClips()).length, 5);

        await service.clearAllClips();
        expect((await service.getAllClips()).length, 0);
      });

      test('removes trashed clips too', () async {
        final clip = DivineVideoClip(
          id: 'trashed_clip',
          video: EditorVideo.file('/tmp/trashed_clip.mp4'),
          duration: const Duration(seconds: 1),
          recordedAt: DateTime.now(),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );

        await service.saveClip(clip);
        await service.softDelete('trashed_clip');

        expect((await service.getTrashedClips()).length, 1);

        await service.clearAllClips();

        expect((await service.getAllClips()).length, 0);
        expect((await service.getTrashedClips()).length, 0);
      });
    });
  });

  group('DivineVideoClip', () {
    test('serializes to and from JSON correctly', () async {
      final original = DivineVideoClip(
        id: 'test_clip',
        video: EditorVideo.file('/path/to/video.mp4'),
        libraryTitle: 'Saved rooftop loop',
        thumbnailPath: '/path/to/thumb.jpg',
        duration: const Duration(milliseconds: 2500),
        recordedAt: DateTime.now(),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      final json = original.toJson();
      // toJson stores only filenames for iOS compatibility
      expect(json['filePath'], 'video.mp4');
      expect(json['thumbnailPath'], 'thumb.jpg');
      expect(json['libraryTitle'], 'Saved rooftop loop');

      // Roundtrip with same base path restores paths
      final restored = DivineVideoClip.fromJson(json, '/path/to');

      expect(restored.id, original.id);
      expect(restored.libraryTitle, original.libraryTitle);
      // Path uses platform separator, check it ends with filename
      expect(await restored.video.safeFilePath(), endsWith('video.mp4'));
      expect(restored.thumbnailPath, endsWith('thumb.jpg'));
      expect(restored.duration, original.duration);
      expect(restored.recordedAt, original.recordedAt);
      expect(restored.targetAspectRatio, original.targetAspectRatio);
      expect(restored.originalAspectRatio, original.originalAspectRatio);
      expect(restored.lensMetadata, original.lensMetadata);
    });

    test('handles null thumbnailPath in JSON', () {
      final clip = DivineVideoClip(
        id: 'no_thumb',
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 3),
        recordedAt: DateTime.now(),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      final json = clip.toJson();
      final restored = DivineVideoClip.fromJson(json, '/path/to');

      expect(restored.thumbnailPath, isNull);
    });

    test('handles missing libraryTitle in legacy JSON', () {
      final clip = DivineVideoClip(
        id: 'legacy_title',
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 3),
        recordedAt: DateTime.now(),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      final json = clip.toJson()..remove('libraryTitle');
      final restored = DivineVideoClip.fromJson(json, '/path/to');

      expect(restored.libraryTitle, isNull);
    });

    test('durationInSeconds returns correct value', () {
      final clip = DivineVideoClip(
        id: 'test',
        video: EditorVideo.file('/test.mp4'),
        duration: const Duration(milliseconds: 2500),
        recordedAt: DateTime.now(),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      expect(clip.durationInSeconds, 2.5);
    });
  });
}
