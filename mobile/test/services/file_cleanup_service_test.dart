// ABOUTME: Tests for FileCleanupService file-existence guard behavior.
// ABOUTME: Keeps cleanup from touching shared database state when no file exists.

@Tags(['skip_very_good_optimization'])
import 'package:db_client/db_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/file_cleanup_service.dart';

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
      verifyNever(() => draftsDao.isRenderedFileReferenced(any()));
    });
  });
}
