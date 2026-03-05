// ABOUTME: Unit tests for DraftsDao - focused on isRenderedFileReferenced
// ABOUTME: and basic CRUD operations.

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DraftsDao dao;
  late String tempDbPath;

  setUp(() async {
    final tempDir = Directory.systemTemp.createTempSync(
      'drafts_dao_test_',
    );
    tempDbPath = '${tempDir.path}/test.db';

    database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
    dao = database.draftsDao;
  });

  tearDown(() async {
    await database.close();
    final file = File(tempDbPath);
    if (file.existsSync()) {
      file.deleteSync();
    }
    final dir = Directory(tempDbPath).parent;
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  group(DraftsDao, () {
    group('isRenderedFileReferenced', () {
      test('returns true when filename matches renderedFilePath', () async {
        await dao.upsertDraft(
          id: 'draft_1',
          title: 'Test',
          description: '',
          publishStatus: 'draft',
          createdAt: DateTime(2023, 11, 14),
          lastModified: DateTime(2023, 11, 14),
          renderedFilePath: 'rendered_video.mp4',
          renderedThumbnailPath: 'rendered_thumb.jpeg',
          data: '{}',
        );

        final result = await dao.isRenderedFileReferenced(
          'rendered_video.mp4',
        );
        expect(result, isTrue);
      });

      test(
        'returns true when filename matches renderedThumbnailPath',
        () async {
          await dao.upsertDraft(
            id: 'draft_1',
            title: 'Test',
            description: '',
            publishStatus: 'draft',
            createdAt: DateTime(2023, 11, 14),
            lastModified: DateTime(2023, 11, 14),
            renderedFilePath: 'rendered_video.mp4',
            renderedThumbnailPath: 'rendered_thumb.jpeg',
            data: '{}',
          );

          final result = await dao.isRenderedFileReferenced(
            'rendered_thumb.jpeg',
          );
          expect(result, isTrue);
        },
      );

      test('returns false when filename is not referenced', () async {
        await dao.upsertDraft(
          id: 'draft_1',
          title: 'Test',
          description: '',
          publishStatus: 'draft',
          createdAt: DateTime(2023, 11, 14),
          lastModified: DateTime(2023, 11, 14),
          renderedFilePath: 'rendered_video.mp4',
          renderedThumbnailPath: 'rendered_thumb.jpeg',
          data: '{}',
        );

        final result = await dao.isRenderedFileReferenced(
          'nonexistent.mp4',
        );
        expect(result, isFalse);
      });

      test('returns false when no drafts exist', () async {
        final result = await dao.isRenderedFileReferenced(
          'anything.mp4',
        );
        expect(result, isFalse);
      });

      test('returns false when renderedFilePath and '
          'renderedThumbnailPath are null', () async {
        await dao.upsertDraft(
          id: 'draft_null',
          title: 'Test',
          description: '',
          publishStatus: 'draft',
          createdAt: DateTime(2023, 11, 14),
          lastModified: DateTime(2023, 11, 14),
          renderedFilePath: null,
          renderedThumbnailPath: null,
          data: '{}',
        );

        final result = await dao.isRenderedFileReferenced(
          'something.mp4',
        );
        expect(result, isFalse);
      });

      test('returns true when multiple drafts exist and '
          'one matches', () async {
        await dao.upsertDraft(
          id: 'draft_1',
          title: 'First',
          description: '',
          publishStatus: 'draft',
          createdAt: DateTime(2023, 11, 14),
          lastModified: DateTime(2023, 11, 14),
          renderedFilePath: 'video_a.mp4',
          renderedThumbnailPath: 'thumb_a.jpeg',
          data: '{}',
        );
        await dao.upsertDraft(
          id: 'draft_2',
          title: 'Second',
          description: '',
          publishStatus: 'draft',
          createdAt: DateTime(2023, 11, 15),
          lastModified: DateTime(2023, 11, 15),
          renderedFilePath: 'video_b.mp4',
          renderedThumbnailPath: 'thumb_b.jpeg',
          data: '{}',
        );

        expect(
          await dao.isRenderedFileReferenced('video_b.mp4'),
          isTrue,
        );
        expect(
          await dao.isRenderedFileReferenced('video_c.mp4'),
          isFalse,
        );
      });
    });
  });
}
