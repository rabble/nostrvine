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
    final tempDir = Directory.systemTemp.createTempSync('drafts_dao_test_');
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

        final result = await dao.isRenderedFileReferenced('rendered_video.mp4');
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

        final result = await dao.isRenderedFileReferenced('nonexistent.mp4');
        expect(result, isFalse);
      });

      test('returns false when no drafts exist', () async {
        final result = await dao.isRenderedFileReferenced('anything.mp4');
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

        final result = await dao.isRenderedFileReferenced('something.mp4');
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

        expect(await dao.isRenderedFileReferenced('video_b.mp4'), isTrue);
        expect(await dao.isRenderedFileReferenced('video_c.mp4'), isFalse);
      });
    });

    group('ownerPubkey isolation', () {
      const pubkeyA =
          'aaaa1111aaaa1111aaaa1111aaaa1111'
          'aaaa1111aaaa1111aaaa1111aaaa1111';
      const pubkeyB =
          'bbbb2222bbbb2222bbbb2222bbbb2222'
          'bbbb2222bbbb2222bbbb2222bbbb2222';

      Future<void> insertDraft({
        required String id,
        String? ownerPubkey,
        String publishStatus = 'draft',
        DateTime? lastModified,
      }) async {
        await dao.upsertDraft(
          id: id,
          title: 'Draft $id',
          description: '',
          publishStatus: publishStatus,
          createdAt: DateTime(2023, 11, 14),
          lastModified: lastModified ?? DateTime(2023, 11, 14),
          renderedFilePath: 'rendered.mp4',
          renderedThumbnailPath: 'thumb.jpeg',
          data: '{}',
          ownerPubkey: ownerPubkey,
        );
      }

      test('upsertDraft stores ownerPubkey', () async {
        await insertDraft(id: 'draft_owned', ownerPubkey: pubkeyA);

        final draft = await dao.getDraftById('draft_owned');
        expect(draft, isNotNull);
        expect(draft!.ownerPubkey, equals(pubkeyA));
      });

      test('upsertDraft without ownerPubkey stores null', () async {
        await insertDraft(id: 'draft_legacy');

        final draft = await dao.getDraftById('draft_legacy');
        expect(draft, isNotNull);
        expect(draft!.ownerPubkey, isNull);
      });

      test('getAllDrafts returns only owned + legacy drafts', () async {
        await insertDraft(id: 'draft_a', ownerPubkey: pubkeyA);
        await insertDraft(id: 'draft_b', ownerPubkey: pubkeyB);
        await insertDraft(id: 'draft_legacy');

        final draftsA = await dao.getAllDrafts(ownerPubkey: pubkeyA);
        expect(draftsA, hasLength(2));
        final idsA = draftsA.map((d) => d.id).toSet();
        expect(idsA, containsAll(['draft_a', 'draft_legacy']));
        expect(idsA, isNot(contains('draft_b')));

        final draftsB = await dao.getAllDrafts(ownerPubkey: pubkeyB);
        expect(draftsB, hasLength(2));
        final idsB = draftsB.map((d) => d.id).toSet();
        expect(idsB, containsAll(['draft_b', 'draft_legacy']));
        expect(idsB, isNot(contains('draft_a')));
      });

      test('getAllDrafts without ownerPubkey returns all drafts', () async {
        await insertDraft(id: 'draft_a', ownerPubkey: pubkeyA);
        await insertDraft(id: 'draft_b', ownerPubkey: pubkeyB);
        await insertDraft(id: 'draft_legacy');

        final all = await dao.getAllDrafts();
        expect(all, hasLength(3));
      });

      test('getDraftsByStatus filters by owner', () async {
        await insertDraft(
          id: 'draft_a',
          ownerPubkey: pubkeyA,
          publishStatus: 'published',
        );
        await insertDraft(
          id: 'draft_b',
          ownerPubkey: pubkeyB,
          publishStatus: 'published',
        );
        await insertDraft(id: 'draft_legacy', publishStatus: 'published');

        final published = await dao.getDraftsByStatus(
          'published',
          ownerPubkey: pubkeyA,
        );
        expect(published, hasLength(2));
        final ids = published.map((d) => d.id).toSet();
        expect(ids, containsAll(['draft_a', 'draft_legacy']));
        expect(ids, isNot(contains('draft_b')));
      });

      test('watchAllDrafts filters by ownerPubkey', () async {
        await insertDraft(id: 'draft_a', ownerPubkey: pubkeyA);
        await insertDraft(id: 'draft_b', ownerPubkey: pubkeyB);
        await insertDraft(id: 'draft_legacy');

        final stream = dao.watchAllDrafts(ownerPubkey: pubkeyA);
        final results = await stream.first;

        expect(results, hasLength(2));
        final ids = results.map((d) => d.id).toSet();
        expect(ids, containsAll(['draft_a', 'draft_legacy']));
        expect(ids, isNot(contains('draft_b')));
      });

      test('watchDraftsByStatus filters by ownerPubkey', () async {
        await insertDraft(id: 'draft_a', ownerPubkey: pubkeyA);
        await insertDraft(id: 'draft_b', ownerPubkey: pubkeyB);
        await insertDraft(id: 'draft_legacy');

        final stream = dao.watchDraftsByStatus('draft', ownerPubkey: pubkeyA);
        final results = await stream.first;

        expect(results, hasLength(2));
        final ids = results.map((d) => d.id).toSet();
        expect(ids, containsAll(['draft_a', 'draft_legacy']));
      });

      test('getCountByStatus filters by owner', () async {
        await insertDraft(id: 'draft_a', ownerPubkey: pubkeyA);
        await insertDraft(id: 'draft_b', ownerPubkey: pubkeyB);
        await insertDraft(id: 'draft_legacy');

        final countA = await dao.getCountByStatus(
          'draft',
          ownerPubkey: pubkeyA,
        );
        expect(countA, equals(2));

        final countB = await dao.getCountByStatus(
          'draft',
          ownerPubkey: pubkeyB,
        );
        expect(countB, equals(2));
      });

      test('getCount filters by owner', () async {
        await insertDraft(id: 'draft_a', ownerPubkey: pubkeyA);
        await insertDraft(id: 'draft_b', ownerPubkey: pubkeyB);
        await insertDraft(id: 'draft_legacy');

        final countA = await dao.getCount(ownerPubkey: pubkeyA);
        expect(countA, equals(2));

        final countB = await dao.getCount(ownerPubkey: pubkeyB);
        expect(countB, equals(2));

        final countAll = await dao.getCount();
        expect(countAll, equals(3));
      });

      test('drafts of user A are invisible to user B', () async {
        await insertDraft(id: 'draft_a_only', ownerPubkey: pubkeyA);

        final draftsB = await dao.getAllDrafts(ownerPubkey: pubkeyB);
        expect(draftsB, isEmpty);
      });

      test('saveDraftWithClips stores ownerPubkey', () async {
        await dao.saveDraftWithClips(
          id: 'draft_txn',
          title: 'Transactional',
          description: '',
          publishStatus: 'draft',
          createdAt: DateTime(2023, 11, 14),
          lastModified: DateTime(2023, 11, 14),
          renderedFilePath: null,
          renderedThumbnailPath: null,
          data: '{}',
          clipDataList: const [],
          ownerPubkey: pubkeyA,
        );

        final draft = await dao.getDraftById('draft_txn');
        expect(draft, isNotNull);
        expect(draft!.ownerPubkey, equals(pubkeyA));
      });
    });

    group('deleteAllForUser', () {
      const pubkeyA =
          'aaaa1111aaaa1111aaaa1111aaaa1111'
          'aaaa1111aaaa1111aaaa1111aaaa1111';
      const pubkeyB =
          'bbbb2222bbbb2222bbbb2222bbbb2222'
          'bbbb2222bbbb2222bbbb2222bbbb2222';

      Future<void> insertDraft({
        required String id,
        String? ownerPubkey,
      }) async {
        await dao.upsertDraft(
          id: id,
          title: 'Draft $id',
          description: '',
          publishStatus: 'draft',
          createdAt: DateTime(2023, 11, 14),
          lastModified: DateTime(2023, 11, 14),
          renderedFilePath: null,
          renderedThumbnailPath: null,
          data: '{}',
          ownerPubkey: ownerPubkey,
        );
      }

      test('deletes all drafts for user', () async {
        await insertDraft(id: 'draft_a1', ownerPubkey: pubkeyA);
        await insertDraft(id: 'draft_a2', ownerPubkey: pubkeyA);

        final deleted = await dao.deleteAllForUser(pubkeyA);

        expect(deleted, equals(2));
        final remaining = await dao.getAllDrafts();
        expect(remaining, isEmpty);
      });

      test('does not delete drafts for other users', () async {
        await insertDraft(id: 'draft_a', ownerPubkey: pubkeyA);
        await insertDraft(id: 'draft_b', ownerPubkey: pubkeyB);

        await dao.deleteAllForUser(pubkeyA);

        final remaining = await dao.getAllDrafts();
        expect(remaining, hasLength(1));
        expect(remaining.first.id, equals('draft_b'));
      });

      test('does not delete legacy drafts with null ownerPubkey', () async {
        await insertDraft(id: 'draft_a', ownerPubkey: pubkeyA);
        await insertDraft(id: 'draft_legacy');

        await dao.deleteAllForUser(pubkeyA);

        final remaining = await dao.getAllDrafts();
        expect(remaining, hasLength(1));
        expect(remaining.first.id, equals('draft_legacy'));
      });

      test('returns 0 when no drafts exist', () async {
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

      Future<void> insertDraft({
        required String id,
        String? ownerPubkey,
      }) async {
        await dao.upsertDraft(
          id: id,
          title: 'Draft $id',
          description: '',
          publishStatus: 'draft',
          createdAt: DateTime(2023, 11, 14),
          lastModified: DateTime(2023, 11, 14),
          renderedFilePath: null,
          renderedThumbnailPath: null,
          data: '{}',
          ownerPubkey: ownerPubkey,
        );
      }

      test('claims NULL-owner rows for the given pubkey', () async {
        await insertDraft(id: 'draft_legacy1');
        await insertDraft(id: 'draft_legacy2');

        final claimed = await dao.claimLegacyRows(pubkeyA);

        expect(claimed, equals(2));
        final all = await dao.getAllDrafts(ownerPubkey: pubkeyA);
        expect(all, hasLength(2));
        for (final draft in all) {
          expect(draft.ownerPubkey, equals(pubkeyA));
        }
      });

      test('does not modify already-owned rows', () async {
        await insertDraft(id: 'draft_b', ownerPubkey: pubkeyB);
        await insertDraft(id: 'draft_legacy');

        await dao.claimLegacyRows(pubkeyA);

        final draftB = await dao.getDraftById('draft_b');
        expect(draftB!.ownerPubkey, equals(pubkeyB));
      });

      test('claimed rows are no longer visible to other users', () async {
        await insertDraft(id: 'draft_legacy');

        await dao.claimLegacyRows(pubkeyA);

        final draftsB = await dao.getAllDrafts(ownerPubkey: pubkeyB);
        expect(draftsB, isEmpty);
      });

      test('returns 0 when no legacy rows exist', () async {
        await insertDraft(id: 'draft_a', ownerPubkey: pubkeyA);

        final claimed = await dao.claimLegacyRows(pubkeyA);

        expect(claimed, equals(0));
      });
    });
  });
}
