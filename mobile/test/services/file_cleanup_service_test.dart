// ABOUTME: Tests for FileCleanupService file-existence guard behavior.
// ABOUTME: Keeps cleanup from touching shared database state when no file exists.

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/file_cleanup_service.dart';
import 'package:path/path.dart' as p;

class _MockDraftsDao extends Mock implements DraftsDao {}

class _MockClipsDao extends Mock implements ClipsDao {}

void main() {
  group('FileCleanupService', () {
    late _MockDraftsDao draftsDao;
    late _MockClipsDao clipsDao;

    setUp(() {
      draftsDao = _MockDraftsDao();
      clipsDao = _MockClipsDao();
    });

    test('does not query references when the file is already absent', () async {
      await FileCleanupService.deleteFileIfUnreferenced(
        '/tmp/divine-missing-clip-file.mp4',
        draftsDao: draftsDao,
        clipsDao: clipsDao,
      );

      verifyNever(() => clipsDao.isFileReferenced(any()));
      verifyNever(() => draftsDao.isDraftFileReferenced(any()));
    });

    group('deleteDraftAudioFiles', () {
      late Directory tempDir;

      setUp(() {
        tempDir = Directory.systemTemp.createTempSync('divine_audio_cleanup');
      });

      tearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      File writeAudio(String name) {
        final file = File(p.join(tempDir.path, name))
          ..writeAsBytesSync(const [0, 1, 2, 3]);
        return file;
      }

      test('deletes a local audio file that nothing references', () async {
        when(
          () => clipsDao.isFileReferenced(any()),
        ).thenAnswer((_) async => false);
        when(
          () => draftsDao.isDraftFileReferenced(any()),
        ).thenAnswer((_) async => false);
        final audio = writeAudio('voice_over_1.m4a');

        await FileCleanupService.deleteDraftAudioFiles(
          [audio.path],
          draftsDao: draftsDao,
          clipsDao: clipsDao,
        );

        expect(audio.existsSync(), isFalse);
      });

      test(
        'keeps audio whose basename is referenced by another draft',
        () async {
          final audio = writeAudio('shared.m4a');

          await FileCleanupService.deleteDraftAudioFiles(
            [audio.path],
            draftsDao: draftsDao,
            clipsDao: clipsDao,
            referencedAudioFilenames: {'shared.m4a'},
          );

          expect(
            audio.existsSync(),
            isTrue,
            reason: 'a basename in referencedAudioFilenames must be kept',
          );
          // The cross-draft guard short-circuits before the indexed lookups.
          verifyNever(() => clipsDao.isFileReferenced(any()));
          verifyNever(() => draftsDao.isDraftFileReferenced(any()));
        },
      );

      test(
        'keeps audio still referenced by the indexed clip/draft backstop',
        () async {
          // No referencedAudioFilenames entry, so the cross-draft guard does not
          // short-circuit and the defensive indexed reference check runs.
          when(
            () => clipsDao.isFileReferenced(any()),
          ).thenAnswer((_) async => true);
          when(
            () => draftsDao.isDraftFileReferenced(any()),
          ).thenAnswer((_) async => false);
          final audio = writeAudio('indexed_ref.m4a');

          await FileCleanupService.deleteDraftAudioFiles(
            [audio.path],
            draftsDao: draftsDao,
            clipsDao: clipsDao,
          );

          expect(
            audio.existsSync(),
            isTrue,
            reason:
                'the indexed reference check must still keep referenced audio',
          );
        },
      );

      test('skips empty paths without querying references', () async {
        await FileCleanupService.deleteDraftAudioFiles(
          [''],
          draftsDao: draftsDao,
          clipsDao: clipsDao,
        );

        verifyNever(() => clipsDao.isFileReferenced(any()));
        verifyNever(() => draftsDao.isDraftFileReferenced(any()));
      });
    });

    // Regression for the multi-set stop-motion frame loss: a stop-motion clip
    // keeps its stills in the row's `data` JSON, not in an indexed file column
    // (only the first still is mirrored into thumbnail_path). Deleting the
    // autosave draft that also held the clip must NOT delete the stills the
    // surviving library row still references — otherwise a saved set silently
    // shrinks to its thumbnail and two sets merge to two frames.
    group('stop-motion frames referenced only in data', () {
      late AppDatabase database;
      late ClipLibraryService libraryService;
      late Directory tempDir;

      setUp(() {
        database = AppDatabase.test(NativeDatabase.memory());
        libraryService = ClipLibraryService(
          clipsDao: database.clipsDao,
          draftsDao: database.draftsDao,
        );
        tempDir = Directory.systemTemp.createTempSync('divine_sm_cleanup');
      });

      tearDown(() async {
        await database.close();
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      DivineVideoClip writeStopMotionSet(String id, int frameCount) {
        final frames = [
          for (var i = 0; i < frameCount; i++)
            StopMotionClipFrame(
              path: (File(
                p.join(tempDir.path, '${id}_frame_$i.jpg'),
              )..writeAsBytesSync(const [1, 2, 3])).path,
              duration: const Duration(microseconds: 41667),
            ),
        ];
        return DivineVideoClip(
          id: id,
          stopMotionFrames: frames,
          duration: const Duration(milliseconds: 125),
          recordedAt: DateTime(2024),
          targetAspectRatio: model.AspectRatio.vertical,
          originalAspectRatio: 9 / 16,
          // The recorder uses the first still as the library thumbnail.
          thumbnailPath: frames.first.path,
        );
      }

      test(
        'keeps every still while the library row still references them',
        () async {
          final set = writeStopMotionSet('clip_sm_a', 3);
          await libraryService.saveClip(set);

          // Simulate the autosave-draft delete cleanup running on the same
          // clip while its library row (draftId == null) survives.
          await FileCleanupService.deleteRecordingClipFiles(
            set,
            draftsDao: database.draftsDao,
            clipsDao: database.clipsDao,
          );

          for (final frame in set.stopMotionFrames!) {
            expect(
              File(frame.path).existsSync(),
              isTrue,
              reason: 'still ${frame.path} is referenced by the library row',
            );
          }
        },
      );

      test(
        'deletes stills once no row references them',
        () async {
          final set = writeStopMotionSet('clip_sm_b', 3);
          // No row saved — nothing references the stills.
          await FileCleanupService.deleteRecordingClipFiles(
            set,
            draftsDao: database.draftsDao,
            clipsDao: database.clipsDao,
          );

          for (final frame in set.stopMotionFrames!) {
            expect(File(frame.path).existsSync(), isFalse);
          }
        },
      );
    });
  });
}
