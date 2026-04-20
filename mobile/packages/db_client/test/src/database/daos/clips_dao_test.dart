// ABOUTME: Unit tests for ClipsDao with draft-scoped queries and ordering
// ABOUTME: operations. Tests upsertClip, getClipsByDraftId, deleteClip,
// ABOUTME: deleteClipsByDraftId, watchClipsByDraftId.

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late ClipsDao dao;
  late DraftsDao draftsDao;
  late String tempDbPath;

  const testDraftId = 'draft_1700000000000';
  const testDraftId2 = 'draft_1700000001000';

  setUp(() async {
    final tempDir = Directory.systemTemp.createTempSync('clips_dao_test_');
    tempDbPath = '${tempDir.path}/test.db';

    database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
    dao = database.clipsDao;
    draftsDao = database.draftsDao;

    // Insert parent drafts so foreign key constraints are satisfied
    await draftsDao.upsertDraft(
      id: testDraftId,
      title: 'Test Draft',
      description: 'A test draft',
      publishStatus: 'draft',
      createdAt: DateTime(2023, 11, 14),
      lastModified: DateTime(2023, 11, 14),
      renderedFilePath: 'test.mp4',
      renderedThumbnailPath: 'thumbnail.jpeg',
      data: '{}',
    );
    await draftsDao.upsertDraft(
      id: testDraftId2,
      title: 'Test Draft 2',
      description: 'Another test draft',
      publishStatus: 'draft',
      createdAt: DateTime(2023, 11, 15),
      lastModified: DateTime(2023, 11, 15),
      renderedFilePath: 'test.mp4',
      renderedThumbnailPath: 'thumbnail.jpeg',
      data: '{}',
    );
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

  group(ClipsDao, () {
    group('upsertClip', () {
      test('inserts new clip', () async {
        await dao.upsertClip(
          id: 'clip_1',
          draftId: testDraftId,
          orderIndex: 0,
          durationMs: 3000,
          recordedAt: DateTime(2023, 11, 14, 10),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{"filePath":"video_1.mp4"}',
        );

        final results = await dao.getClipsByDraftId(testDraftId);
        expect(results, hasLength(1));
        expect(results.first.id, equals('clip_1'));
        expect(results.first.draftId, equals(testDraftId));
        expect(results.first.orderIndex, equals(0));
        expect(results.first.durationMs, equals(3000));
        expect(results.first.data, equals('{"filePath":"video_1.mp4"}'));
      });

      test('updates existing clip with same ID', () async {
        await dao.upsertClip(
          id: 'clip_1',
          draftId: testDraftId,
          orderIndex: 0,
          durationMs: 3000,
          recordedAt: DateTime(2023, 11, 14, 10),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{"filePath":"video_1.mp4"}',
        );

        await dao.upsertClip(
          id: 'clip_1',
          draftId: testDraftId,
          orderIndex: 1,
          durationMs: 5000,
          recordedAt: DateTime(2023, 11, 14, 11),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{"filePath":"video_1_updated.mp4"}',
        );

        final results = await dao.getClipsByDraftId(testDraftId);
        expect(results, hasLength(1));
        expect(results.first.durationMs, equals(5000));
        expect(results.first.orderIndex, equals(1));
        expect(
          results.first.data,
          equals('{"filePath":"video_1_updated.mp4"}'),
        );
      });

      test('inserts multiple clips for different drafts', () async {
        await dao.upsertClip(
          id: 'clip_1',
          draftId: testDraftId,
          orderIndex: 0,
          durationMs: 3000,
          recordedAt: DateTime(2023, 11, 14, 10),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{}',
        );
        await dao.upsertClip(
          id: 'clip_2',
          draftId: testDraftId2,
          orderIndex: 0,
          durationMs: 4000,
          recordedAt: DateTime(2023, 11, 14, 11),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{}',
        );

        final draft1Clips = await dao.getClipsByDraftId(testDraftId);
        final draft2Clips = await dao.getClipsByDraftId(testDraftId2);
        expect(draft1Clips, hasLength(1));
        expect(draft2Clips, hasLength(1));
      });
    });

    group('getClipsByDraftId', () {
      test('returns clips sorted by orderIndex ascending', () async {
        await dao.upsertClip(
          id: 'clip_c',
          draftId: testDraftId,
          orderIndex: 2,
          durationMs: 1000,
          recordedAt: DateTime(2023, 11, 14, 10),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{}',
        );
        await dao.upsertClip(
          id: 'clip_a',
          draftId: testDraftId,
          orderIndex: 0,
          durationMs: 2000,
          recordedAt: DateTime(2023, 11, 14, 11),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{}',
        );
        await dao.upsertClip(
          id: 'clip_b',
          draftId: testDraftId,
          orderIndex: 1,
          durationMs: 3000,
          recordedAt: DateTime(2023, 11, 14, 12),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{}',
        );

        final results = await dao.getClipsByDraftId(testDraftId);
        expect(results[0].id, equals('clip_a'));
        expect(results[1].id, equals('clip_b'));
        expect(results[2].id, equals('clip_c'));
      });

      test('returns empty list for non-existent draft', () async {
        final results = await dao.getClipsByDraftId('nonexistent');
        expect(results, isEmpty);
      });

      test('does not return clips from other drafts', () async {
        await dao.upsertClip(
          id: 'clip_1',
          draftId: testDraftId,
          orderIndex: 0,
          durationMs: 3000,
          recordedAt: DateTime(2023, 11, 14, 10),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{}',
        );
        await dao.upsertClip(
          id: 'clip_2',
          draftId: testDraftId2,
          orderIndex: 0,
          durationMs: 4000,
          recordedAt: DateTime(2023, 11, 14, 11),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{}',
        );

        final results = await dao.getClipsByDraftId(testDraftId);
        expect(results, hasLength(1));
        expect(results.first.id, equals('clip_1'));
      });
    });

    group('getClipById', () {
      test('returns clip when found', () async {
        await dao.upsertClip(
          id: 'clip_1',
          draftId: testDraftId,
          orderIndex: 0,
          durationMs: 3000,
          recordedAt: DateTime(2023, 11, 14, 10),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{"filePath":"video.mp4"}',
        );

        final result = await dao.getClipById('clip_1');
        expect(result, isNotNull);
        expect(result!.id, equals('clip_1'));
        expect(result.data, equals('{"filePath":"video.mp4"}'));
      });

      test('returns null for non-existent clip', () async {
        final result = await dao.getClipById('nonexistent');
        expect(result, isNull);
      });
    });

    group('getAllClips', () {
      test('returns all clips sorted by recordedAt descending', () async {
        await dao.upsertClip(
          id: 'clip_old',
          draftId: testDraftId,
          orderIndex: 0,
          durationMs: 3000,
          recordedAt: DateTime(2023, 11, 14, 10),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{}',
        );
        await dao.upsertClip(
          id: 'clip_new',
          draftId: testDraftId,
          orderIndex: 1,
          durationMs: 4000,
          recordedAt: DateTime(2023, 11, 14, 12),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{}',
        );
        await dao.upsertClip(
          id: 'clip_mid',
          draftId: testDraftId2,
          orderIndex: 0,
          durationMs: 5000,
          recordedAt: DateTime(2023, 11, 14, 11),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{}',
        );

        final results = await dao.getAllClips();
        expect(results, hasLength(3));
        expect(results[0].id, equals('clip_new'));
        expect(results[1].id, equals('clip_mid'));
        expect(results[2].id, equals('clip_old'));
      });

      test('respects limit parameter', () async {
        await dao.upsertClip(
          id: 'clip_1',
          draftId: testDraftId,
          orderIndex: 0,
          durationMs: 3000,
          recordedAt: DateTime(2023, 11, 14, 10),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{}',
        );
        await dao.upsertClip(
          id: 'clip_2',
          draftId: testDraftId,
          orderIndex: 1,
          durationMs: 4000,
          recordedAt: DateTime(2023, 11, 14, 11),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{}',
        );
        await dao.upsertClip(
          id: 'clip_3',
          draftId: testDraftId,
          orderIndex: 2,
          durationMs: 5000,
          recordedAt: DateTime(2023, 11, 14, 12),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{}',
        );

        final results = await dao.getAllClips(limit: 2);
        expect(results, hasLength(2));
      });

      test('returns empty list when no clips exist', () async {
        final results = await dao.getAllClips();
        expect(results, isEmpty);
      });
    });

    group('updateOrderIndex', () {
      test('updates order index of clip', () async {
        await dao.upsertClip(
          id: 'clip_1',
          draftId: testDraftId,
          orderIndex: 0,
          durationMs: 3000,
          recordedAt: DateTime(2023, 11, 14, 10),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{}',
        );

        final result = await dao.updateOrderIndex(id: 'clip_1', orderIndex: 5);

        expect(result, isTrue);
        final clip = await dao.getClipById('clip_1');
        expect(clip!.orderIndex, equals(5));
      });

      test('returns false for non-existent clip', () async {
        final result = await dao.updateOrderIndex(
          id: 'nonexistent',
          orderIndex: 0,
        );
        expect(result, isFalse);
      });

      test('does not affect other clips', () async {
        await dao.upsertClip(
          id: 'clip_1',
          draftId: testDraftId,
          orderIndex: 0,
          durationMs: 3000,
          recordedAt: DateTime(2023, 11, 14, 10),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{}',
        );
        await dao.upsertClip(
          id: 'clip_2',
          draftId: testDraftId,
          orderIndex: 1,
          durationMs: 4000,
          recordedAt: DateTime(2023, 11, 14, 11),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{}',
        );

        await dao.updateOrderIndex(id: 'clip_1', orderIndex: 5);

        final clip2 = await dao.getClipById('clip_2');
        expect(clip2!.orderIndex, equals(1));
      });
    });

    group('deleteClip', () {
      test('deletes clip by ID', () async {
        await dao.upsertClip(
          id: 'clip_1',
          draftId: testDraftId,
          orderIndex: 0,
          durationMs: 3000,
          recordedAt: DateTime(2023, 11, 14, 10),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{}',
        );
        await dao.upsertClip(
          id: 'clip_2',
          draftId: testDraftId,
          orderIndex: 1,
          durationMs: 4000,
          recordedAt: DateTime(2023, 11, 14, 11),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{}',
        );

        final deleted = await dao.deleteClip('clip_1');

        expect(deleted, equals(1));
        final results = await dao.getClipsByDraftId(testDraftId);
        expect(results, hasLength(1));
        expect(results.first.id, equals('clip_2'));
      });

      test('returns 0 for non-existent clip', () async {
        final deleted = await dao.deleteClip('nonexistent');
        expect(deleted, equals(0));
      });
    });

    group('deleteClipsByDraftId', () {
      test('deletes all clips for a draft', () async {
        await dao.upsertClip(
          id: 'clip_1',
          draftId: testDraftId,
          orderIndex: 0,
          durationMs: 3000,
          recordedAt: DateTime(2023, 11, 14, 10),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{}',
        );
        await dao.upsertClip(
          id: 'clip_2',
          draftId: testDraftId,
          orderIndex: 1,
          durationMs: 4000,
          recordedAt: DateTime(2023, 11, 14, 11),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{}',
        );
        await dao.upsertClip(
          id: 'clip_3',
          draftId: testDraftId2,
          orderIndex: 0,
          durationMs: 5000,
          recordedAt: DateTime(2023, 11, 14, 12),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{}',
        );

        final deleted = await dao.deleteClipsByDraftId(testDraftId);

        expect(deleted, equals(2));
        final draft1Clips = await dao.getClipsByDraftId(testDraftId);
        expect(draft1Clips, isEmpty);
        final draft2Clips = await dao.getClipsByDraftId(testDraftId2);
        expect(draft2Clips, hasLength(1));
      });

      test('returns 0 when draft has no clips', () async {
        final deleted = await dao.deleteClipsByDraftId(testDraftId);
        expect(deleted, equals(0));
      });
    });

    group('watchClipsByDraftId', () {
      test('emits initial list ordered by orderIndex', () async {
        await dao.upsertClip(
          id: 'clip_b',
          draftId: testDraftId,
          orderIndex: 1,
          durationMs: 4000,
          recordedAt: DateTime(2023, 11, 14, 11),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{}',
        );
        await dao.upsertClip(
          id: 'clip_a',
          draftId: testDraftId,
          orderIndex: 0,
          durationMs: 3000,
          recordedAt: DateTime(2023, 11, 14, 10),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{}',
        );

        final stream = dao.watchClipsByDraftId(testDraftId);
        final results = await stream.first;

        expect(results, hasLength(2));
        expect(results[0].id, equals('clip_a'));
        expect(results[1].id, equals('clip_b'));
      });

      test('emits empty list for non-existent draft', () async {
        final stream = dao.watchClipsByDraftId('nonexistent');
        final results = await stream.first;
        expect(results, isEmpty);
      });
    });

    group('watchClipById', () {
      test('emits clip when found', () async {
        await dao.upsertClip(
          id: 'clip_1',
          draftId: testDraftId,
          orderIndex: 0,
          durationMs: 3000,
          recordedAt: DateTime(2023, 11, 14, 10),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{"test": true}',
        );

        final stream = dao.watchClipById('clip_1');
        final result = await stream.first;

        expect(result, isNotNull);
        expect(result!.id, equals('clip_1'));
      });

      test('emits null for non-existent clip', () async {
        final stream = dao.watchClipById('nonexistent');
        final result = await stream.first;
        expect(result, isNull);
      });
    });

    group('getCountByDraftId', () {
      test('returns count of clips for a draft', () async {
        await dao.upsertClip(
          id: 'clip_1',
          draftId: testDraftId,
          orderIndex: 0,
          durationMs: 3000,
          recordedAt: DateTime(2023, 11, 14, 10),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{}',
        );
        await dao.upsertClip(
          id: 'clip_2',
          draftId: testDraftId,
          orderIndex: 1,
          durationMs: 4000,
          recordedAt: DateTime(2023, 11, 14, 11),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{}',
        );
        await dao.upsertClip(
          id: 'clip_3',
          draftId: testDraftId2,
          orderIndex: 0,
          durationMs: 5000,
          recordedAt: DateTime(2023, 11, 14, 12),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{}',
        );

        final count = await dao.getCountByDraftId(testDraftId);
        expect(count, equals(2));
      });

      test('returns 0 for draft with no clips', () async {
        final count = await dao.getCountByDraftId(testDraftId);
        expect(count, equals(0));
      });

      test('returns 0 for non-existent draft', () async {
        final count = await dao.getCountByDraftId('nonexistent');
        expect(count, equals(0));
      });
    });

    group('clearAll', () {
      test('deletes all clips', () async {
        await dao.upsertClip(
          id: 'clip_1',
          draftId: testDraftId,
          orderIndex: 0,
          durationMs: 3000,
          recordedAt: DateTime(2023, 11, 14, 10),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{}',
        );
        await dao.upsertClip(
          id: 'clip_2',
          draftId: testDraftId2,
          orderIndex: 0,
          durationMs: 4000,
          recordedAt: DateTime(2023, 11, 14, 11),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{}',
        );

        final deleted = await dao.clearAll();

        expect(deleted, equals(2));
        final results = await dao.getAllClips();
        expect(results, isEmpty);
      });

      test('returns 0 when table is empty', () async {
        final deleted = await dao.clearAll();
        expect(deleted, equals(0));
      });
    });

    group('library clips (no draft)', () {
      test('inserts clip without draftId', () async {
        await dao.upsertClip(
          id: 'lib_clip_1',
          orderIndex: 0,
          durationMs: 3000,
          recordedAt: DateTime(2023, 11, 14, 10),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{"filePath":"library_video.mp4"}',
        );

        final result = await dao.getClipById('lib_clip_1');
        expect(result, isNotNull);
        expect(result!.draftId, isNull);
        expect(result.data, equals('{"filePath":"library_video.mp4"}'));
      });

      test('getLibraryClips returns only clips without draftId', () async {
        await dao.upsertClip(
          id: 'lib_clip_1',
          orderIndex: 0,
          durationMs: 3000,
          recordedAt: DateTime(2023, 11, 14, 10),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{}',
        );
        await dao.upsertClip(
          id: 'lib_clip_2',
          orderIndex: 0,
          durationMs: 4000,
          recordedAt: DateTime(2023, 11, 14, 12),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{}',
        );
        await dao.upsertClip(
          id: 'draft_clip',
          draftId: testDraftId,
          orderIndex: 0,
          durationMs: 5000,
          recordedAt: DateTime(2023, 11, 14, 11),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{}',
        );

        final libraryClips = await dao.getLibraryClips();
        expect(libraryClips, hasLength(2));
        // Newest first
        expect(libraryClips[0].id, equals('lib_clip_2'));
        expect(libraryClips[1].id, equals('lib_clip_1'));
      });

      test('getLibraryClips respects limit', () async {
        await dao.upsertClip(
          id: 'lib_1',
          orderIndex: 0,
          durationMs: 3000,
          recordedAt: DateTime(2023, 11, 14, 10),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{}',
        );
        await dao.upsertClip(
          id: 'lib_2',
          orderIndex: 0,
          durationMs: 4000,
          recordedAt: DateTime(2023, 11, 14, 11),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{}',
        );
        await dao.upsertClip(
          id: 'lib_3',
          orderIndex: 0,
          durationMs: 5000,
          recordedAt: DateTime(2023, 11, 14, 12),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{}',
        );

        final results = await dao.getLibraryClips(limit: 2);
        expect(results, hasLength(2));
      });

      test('getLibraryClips returns empty when none exist', () async {
        await dao.upsertClip(
          id: 'draft_clip',
          draftId: testDraftId,
          orderIndex: 0,
          durationMs: 3000,
          recordedAt: DateTime(2023, 11, 14, 10),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{}',
        );

        final results = await dao.getLibraryClips();
        expect(results, isEmpty);
      });

      test('watchLibraryClips emits only library clips', () async {
        await dao.upsertClip(
          id: 'lib_clip_1',
          orderIndex: 0,
          durationMs: 3000,
          recordedAt: DateTime(2023, 11, 14, 10),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{}',
        );
        await dao.upsertClip(
          id: 'draft_clip',
          draftId: testDraftId,
          orderIndex: 0,
          durationMs: 5000,
          recordedAt: DateTime(2023, 11, 14, 12),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{}',
        );

        final stream = dao.watchLibraryClips();
        final results = await stream.first;

        expect(results, hasLength(1));
        expect(results.first.id, equals('lib_clip_1'));
      });

      test('clearLibraryClips removes only library clips', () async {
        await dao.upsertClip(
          id: 'lib_clip_1',
          orderIndex: 0,
          durationMs: 3000,
          recordedAt: DateTime(2023, 11, 14, 10),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{}',
        );
        await dao.upsertClip(
          id: 'lib_clip_2',
          orderIndex: 0,
          durationMs: 4000,
          recordedAt: DateTime(2023, 11, 14, 11),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{}',
        );
        await dao.upsertClip(
          id: 'draft_clip',
          draftId: testDraftId,
          orderIndex: 0,
          durationMs: 5000,
          recordedAt: DateTime(2023, 11, 14, 12),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{}',
        );

        final deleted = await dao.clearLibraryClips();

        expect(deleted, equals(2));
        final libraryClips = await dao.getLibraryClips();
        expect(libraryClips, isEmpty);
        // Draft clips should remain
        final draftClips = await dao.getClipsByDraftId(testDraftId);
        expect(draftClips, hasLength(1));
      });

      test('clearLibraryClips returns 0 when no library clips', () async {
        await dao.upsertClip(
          id: 'draft_clip',
          draftId: testDraftId,
          orderIndex: 0,
          durationMs: 3000,
          recordedAt: DateTime(2023, 11, 14, 10),
          filePath: 'test.mp4',
          thumbnailPath: 'thumbnail.jpeg',
          data: '{}',
        );

        final deleted = await dao.clearLibraryClips();
        expect(deleted, equals(0));
      });
    });

    group('isFileReferenced', () {
      test('returns true when filename matches filePath', () async {
        await dao.upsertClip(
          id: 'clip_1',
          draftId: testDraftId,
          orderIndex: 0,
          durationMs: 3000,
          recordedAt: DateTime(2023, 11, 14, 10),
          filePath: 'video_abc.mp4',
          thumbnailPath: 'thumb_abc.jpeg',
          data: '{}',
        );

        final result = await dao.isFileReferenced('video_abc.mp4');
        expect(result, isTrue);
      });

      test('returns true when filename matches thumbnailPath', () async {
        await dao.upsertClip(
          id: 'clip_1',
          draftId: testDraftId,
          orderIndex: 0,
          durationMs: 3000,
          recordedAt: DateTime(2023, 11, 14, 10),
          filePath: 'video_abc.mp4',
          thumbnailPath: 'thumb_abc.jpeg',
          data: '{}',
        );

        final result = await dao.isFileReferenced('thumb_abc.jpeg');
        expect(result, isTrue);
      });

      test('returns false when filename is not referenced', () async {
        await dao.upsertClip(
          id: 'clip_1',
          draftId: testDraftId,
          orderIndex: 0,
          durationMs: 3000,
          recordedAt: DateTime(2023, 11, 14, 10),
          filePath: 'video_abc.mp4',
          thumbnailPath: 'thumb_abc.jpeg',
          data: '{}',
        );

        final result = await dao.isFileReferenced('nonexistent.mp4');
        expect(result, isFalse);
      });

      test('returns false when no clips exist', () async {
        final result = await dao.isFileReferenced('anything.mp4');
        expect(result, isFalse);
      });

      test('returns true when filename matches library clip', () async {
        await dao.upsertClip(
          id: 'lib_clip_1',
          orderIndex: 0,
          durationMs: 3000,
          recordedAt: DateTime(2023, 11, 14, 10),
          filePath: 'lib_video.mp4',
          thumbnailPath: 'lib_thumb.jpeg',
          data: '{}',
        );

        final result = await dao.isFileReferenced('lib_video.mp4');
        expect(result, isTrue);
      });

      test('returns false when filePath and thumbnailPath are null', () async {
        await dao.upsertClip(
          id: 'clip_null',
          draftId: testDraftId,
          orderIndex: 0,
          durationMs: 3000,
          recordedAt: DateTime(2023, 11, 14, 10),
          filePath: null,
          thumbnailPath: null,
          data: '{}',
        );

        final result = await dao.isFileReferenced('something.mp4');
        expect(result, isFalse);
      });
    });

    group('ownerPubkey isolation', () {
      const pubkeyA =
          'aaaa1111aaaa1111aaaa1111aaaa1111'
          'aaaa1111aaaa1111aaaa1111aaaa1111';
      const pubkeyB =
          'bbbb2222bbbb2222bbbb2222bbbb2222'
          'bbbb2222bbbb2222bbbb2222bbbb2222';

      test('upsertClip stores ownerPubkey', () async {
        await dao.upsertClip(
          id: 'clip_owned',
          orderIndex: 0,
          durationMs: 3000,
          recordedAt: DateTime(2023, 11, 14, 10),
          filePath: 'test.mp4',
          thumbnailPath: 'thumb.jpeg',
          data: '{}',
          ownerPubkey: pubkeyA,
        );

        final clip = await dao.getClipById('clip_owned');
        expect(clip, isNotNull);
        expect(clip!.ownerPubkey, equals(pubkeyA));
      });

      test('upsertClip without ownerPubkey stores null', () async {
        await dao.upsertClip(
          id: 'clip_legacy',
          orderIndex: 0,
          durationMs: 3000,
          recordedAt: DateTime(2023, 11, 14, 10),
          filePath: 'test.mp4',
          thumbnailPath: 'thumb.jpeg',
          data: '{}',
        );

        final clip = await dao.getClipById('clip_legacy');
        expect(clip, isNotNull);
        expect(clip!.ownerPubkey, isNull);
      });

      test('getLibraryClips returns only owned + legacy clips', () async {
        // Clip owned by A
        await dao.upsertClip(
          id: 'clip_a',
          orderIndex: 0,
          durationMs: 1000,
          recordedAt: DateTime(2023, 11, 14, 10),
          filePath: 'a.mp4',
          thumbnailPath: 'a.jpeg',
          data: '{}',
          ownerPubkey: pubkeyA,
        );
        // Clip owned by B
        await dao.upsertClip(
          id: 'clip_b',
          orderIndex: 0,
          durationMs: 2000,
          recordedAt: DateTime(2023, 11, 14, 11),
          filePath: 'b.mp4',
          thumbnailPath: 'b.jpeg',
          data: '{}',
          ownerPubkey: pubkeyB,
        );
        // Legacy clip (no owner)
        await dao.upsertClip(
          id: 'clip_legacy',
          orderIndex: 0,
          durationMs: 3000,
          recordedAt: DateTime(2023, 11, 14, 12),
          filePath: 'legacy.mp4',
          thumbnailPath: 'legacy.jpeg',
          data: '{}',
        );

        final clipsA = await dao.getLibraryClips(ownerPubkey: pubkeyA);
        expect(clipsA, hasLength(2));
        final idsA = clipsA.map((c) => c.id).toSet();
        expect(idsA, containsAll(['clip_a', 'clip_legacy']));
        expect(idsA, isNot(contains('clip_b')));

        final clipsB = await dao.getLibraryClips(ownerPubkey: pubkeyB);
        expect(clipsB, hasLength(2));
        final idsB = clipsB.map((c) => c.id).toSet();
        expect(idsB, containsAll(['clip_b', 'clip_legacy']));
        expect(idsB, isNot(contains('clip_a')));
      });

      test('getLibraryClips without ownerPubkey returns all clips', () async {
        await dao.upsertClip(
          id: 'clip_a',
          orderIndex: 0,
          durationMs: 1000,
          recordedAt: DateTime(2023, 11, 14, 10),
          filePath: 'a.mp4',
          thumbnailPath: 'a.jpeg',
          data: '{}',
          ownerPubkey: pubkeyA,
        );
        await dao.upsertClip(
          id: 'clip_b',
          orderIndex: 0,
          durationMs: 2000,
          recordedAt: DateTime(2023, 11, 14, 11),
          filePath: 'b.mp4',
          thumbnailPath: 'b.jpeg',
          data: '{}',
          ownerPubkey: pubkeyB,
        );
        await dao.upsertClip(
          id: 'clip_legacy',
          orderIndex: 0,
          durationMs: 3000,
          recordedAt: DateTime(2023, 11, 14, 12),
          filePath: 'legacy.mp4',
          thumbnailPath: 'legacy.jpeg',
          data: '{}',
        );

        final allClips = await dao.getLibraryClips();
        expect(allClips, hasLength(3));
      });

      test('watchLibraryClips filters by ownerPubkey', () async {
        await dao.upsertClip(
          id: 'clip_a',
          orderIndex: 0,
          durationMs: 1000,
          recordedAt: DateTime(2023, 11, 14, 10),
          filePath: 'a.mp4',
          thumbnailPath: 'a.jpeg',
          data: '{}',
          ownerPubkey: pubkeyA,
        );
        await dao.upsertClip(
          id: 'clip_b',
          orderIndex: 0,
          durationMs: 2000,
          recordedAt: DateTime(2023, 11, 14, 11),
          filePath: 'b.mp4',
          thumbnailPath: 'b.jpeg',
          data: '{}',
          ownerPubkey: pubkeyB,
        );
        await dao.upsertClip(
          id: 'clip_legacy',
          orderIndex: 0,
          durationMs: 3000,
          recordedAt: DateTime(2023, 11, 14, 12),
          filePath: 'legacy.mp4',
          thumbnailPath: 'legacy.jpeg',
          data: '{}',
        );

        final stream = dao.watchLibraryClips(ownerPubkey: pubkeyA);
        final results = await stream.first;

        expect(results, hasLength(2));
        final ids = results.map((c) => c.id).toSet();
        expect(ids, containsAll(['clip_a', 'clip_legacy']));
        expect(ids, isNot(contains('clip_b')));
      });

      test('clips of user A are invisible to user B', () async {
        await dao.upsertClip(
          id: 'clip_a_only',
          orderIndex: 0,
          durationMs: 1000,
          recordedAt: DateTime(2023, 11, 14, 10),
          filePath: 'a.mp4',
          thumbnailPath: 'a.jpeg',
          data: '{}',
          ownerPubkey: pubkeyA,
        );

        final clipsB = await dao.getLibraryClips(ownerPubkey: pubkeyB);
        expect(clipsB, isEmpty);
      });
    });

    group('deleteAllForUser', () {
      const pubkeyA =
          'aaaa1111aaaa1111aaaa1111aaaa1111'
          'aaaa1111aaaa1111aaaa1111aaaa1111';
      const pubkeyB =
          'bbbb2222bbbb2222bbbb2222bbbb2222'
          'bbbb2222bbbb2222bbbb2222bbbb2222';

      test('deletes all clips for user', () async {
        await dao.upsertClip(
          id: 'clip_a1',
          orderIndex: 0,
          durationMs: 1000,
          recordedAt: DateTime(2023, 11, 14, 10),
          filePath: 'a1.mp4',
          thumbnailPath: 'a1.jpeg',
          data: '{}',
          ownerPubkey: pubkeyA,
        );
        await dao.upsertClip(
          id: 'clip_a2',
          orderIndex: 1,
          durationMs: 2000,
          recordedAt: DateTime(2023, 11, 14, 11),
          filePath: 'a2.mp4',
          thumbnailPath: 'a2.jpeg',
          data: '{}',
          ownerPubkey: pubkeyA,
        );

        final deleted = await dao.deleteAllForUser(pubkeyA);

        expect(deleted, equals(2));
        final remaining = await dao.getAllClips();
        expect(remaining, isEmpty);
      });

      test('does not delete clips for other users', () async {
        await dao.upsertClip(
          id: 'clip_a',
          orderIndex: 0,
          durationMs: 1000,
          recordedAt: DateTime(2023, 11, 14, 10),
          filePath: 'a.mp4',
          thumbnailPath: 'a.jpeg',
          data: '{}',
          ownerPubkey: pubkeyA,
        );
        await dao.upsertClip(
          id: 'clip_b',
          orderIndex: 0,
          durationMs: 2000,
          recordedAt: DateTime(2023, 11, 14, 11),
          filePath: 'b.mp4',
          thumbnailPath: 'b.jpeg',
          data: '{}',
          ownerPubkey: pubkeyB,
        );

        await dao.deleteAllForUser(pubkeyA);

        final remaining = await dao.getAllClips();
        expect(remaining, hasLength(1));
        expect(remaining.first.id, equals('clip_b'));
      });

      test('does not delete legacy clips with null ownerPubkey', () async {
        await dao.upsertClip(
          id: 'clip_a',
          orderIndex: 0,
          durationMs: 1000,
          recordedAt: DateTime(2023, 11, 14, 10),
          filePath: 'a.mp4',
          thumbnailPath: 'a.jpeg',
          data: '{}',
          ownerPubkey: pubkeyA,
        );
        await dao.upsertClip(
          id: 'clip_legacy',
          orderIndex: 0,
          durationMs: 2000,
          recordedAt: DateTime(2023, 11, 14, 11),
          filePath: 'legacy.mp4',
          thumbnailPath: 'legacy.jpeg',
          data: '{}',
        );

        await dao.deleteAllForUser(pubkeyA);

        final remaining = await dao.getAllClips();
        expect(remaining, hasLength(1));
        expect(remaining.first.id, equals('clip_legacy'));
      });

      test('returns 0 when no clips exist', () async {
        final deleted = await dao.deleteAllForUser(pubkeyA);

        expect(deleted, equals(0));
      });
    });

    group('claimLegacyRows', () {
      const pubkeyA =
          'aaaa1111aaaa1111aaaa1111aaaa1111'
          'aaaa1111aaaa1111aaaa1111aaaa1111';
      const pubkeyB =
          'bbbb2222bbbb2222bbbb2222bbbb2222'
          'bbbb2222bbbb2222bbbb2222bbbb2222';

      test('claims NULL-owner rows for the given pubkey', () async {
        await dao.upsertClip(
          id: 'clip_legacy1',
          orderIndex: 0,
          durationMs: 1000,
          recordedAt: DateTime(2023, 11, 14, 10),
          filePath: 'l1.mp4',
          thumbnailPath: 'l1.jpeg',
          data: '{}',
        );
        await dao.upsertClip(
          id: 'clip_legacy2',
          orderIndex: 1,
          durationMs: 2000,
          recordedAt: DateTime(2023, 11, 14, 11),
          filePath: 'l2.mp4',
          thumbnailPath: 'l2.jpeg',
          data: '{}',
        );

        final claimed = await dao.claimLegacyRows(pubkeyA);

        expect(claimed, equals(2));
        final all = await dao.getAllClips(ownerPubkey: pubkeyA);
        expect(all, hasLength(2));
        for (final clip in all) {
          expect(clip.ownerPubkey, equals(pubkeyA));
        }
      });

      test('does not modify already-owned rows', () async {
        await dao.upsertClip(
          id: 'clip_b',
          orderIndex: 0,
          durationMs: 1000,
          recordedAt: DateTime(2023, 11, 14, 10),
          filePath: 'b.mp4',
          thumbnailPath: 'b.jpeg',
          data: '{}',
          ownerPubkey: pubkeyB,
        );
        await dao.upsertClip(
          id: 'clip_legacy',
          orderIndex: 0,
          durationMs: 2000,
          recordedAt: DateTime(2023, 11, 14, 11),
          filePath: 'legacy.mp4',
          thumbnailPath: 'legacy.jpeg',
          data: '{}',
        );

        await dao.claimLegacyRows(pubkeyA);

        final clipB = await dao.getClipById('clip_b');
        expect(clipB!.ownerPubkey, equals(pubkeyB));
      });

      test('claimed rows are no longer visible to other users', () async {
        await dao.upsertClip(
          id: 'clip_legacy',
          orderIndex: 0,
          durationMs: 1000,
          recordedAt: DateTime(2023, 11, 14, 10),
          filePath: 'legacy.mp4',
          thumbnailPath: 'legacy.jpeg',
          data: '{}',
        );

        await dao.claimLegacyRows(pubkeyA);

        final clipsB = await dao.getAllClips(ownerPubkey: pubkeyB);
        expect(clipsB, isEmpty);
      });

      test('returns 0 when no legacy rows exist', () async {
        await dao.upsertClip(
          id: 'clip_a',
          orderIndex: 0,
          durationMs: 1000,
          recordedAt: DateTime(2023, 11, 14, 10),
          filePath: 'a.mp4',
          thumbnailPath: 'a.jpeg',
          data: '{}',
          ownerPubkey: pubkeyA,
        );

        final claimed = await dao.claimLegacyRows(pubkeyA);

        expect(claimed, equals(0));
      });
    });
  });
}
