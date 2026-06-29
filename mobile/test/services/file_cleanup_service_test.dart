// ABOUTME: Tests for FileCleanupService file-existence guard behavior.
// ABOUTME: Keeps cleanup from touching shared database state when no file exists.

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
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
  });
}
