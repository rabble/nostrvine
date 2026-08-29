// ABOUTME: Tests aggregate diagnostics for missing local drafts and clips.
// ABOUTME: Proves owner grouping, malformed-row counts, and identifier privacy.

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/local_content_diagnostics_service.dart';

const _ownerA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _ownerB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

void main() {
  group(LocalContentDiagnosticsService, () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase.test(NativeDatabase.memory());
    });

    tearDown(() => database.close());

    Future<void> saveDraft({
      required String id,
      required String? owner,
      String? clipId,
      String? filePath,
    }) {
      return database.draftsDao.saveDraftWithClips(
        id: id,
        title: '',
        description: '',
        publishStatus: 'draft',
        createdAt: DateTime(2026, 8, 29),
        lastModified: DateTime(2026, 8, 29),
        data: '{}',
        renderedFilePath: null,
        renderedThumbnailPath: null,
        customThumbnailPath: null,
        ownerPubkey: owner,
        clipDataList: [
          if (clipId != null)
            DraftClipData(
              id: clipId,
              orderIndex: 0,
              durationMs: 1000,
              recordedAt: DateTime(2026, 8, 29),
              data: jsonEncode({'id': clipId}),
              filePath: filePath,
            ),
        ],
      );
    }

    test('separates visible, anonymous, foreign, and malformed rows', () async {
      await saveDraft(
        id: 'owned-draft',
        owner: _ownerA,
        clipId: 'owned-clip',
        filePath: 'missing.mp4',
      );
      await saveDraft(
        id: 'legacy-draft',
        owner: null,
        clipId: 'legacy-clip',
        filePath: 'present.mp4',
      );
      await saveDraft(
        id: 'anonymous-draft',
        owner: DraftStorageService.anonymousOwnerPubkey,
        clipId: 'anonymous-clip',
      );
      await saveDraft(
        id: 'foreign-draft',
        owner: _ownerB,
        clipId: 'foreign-clip',
      );
      await saveDraft(id: 'zero-clip-draft', owner: _ownerA);

      final diagnostics = await LocalContentDiagnosticsService(
        clipsDao: database.clipsDao,
        draftsDao: database.draftsDao,
        ownerPubkey: _ownerA,
        documentsPath: '/documents',
        fileExists: (path) async => path.endsWith('present.mp4'),
      ).collect();

      expect(diagnostics, {
        'visibleDraftRows': 3,
        'visibleClipRows': 2,
        'anonymousDraftRows': 1,
        'anonymousClipRows': 1,
        'foreignDraftRows': 1,
        'foreignClipRows': 1,
        'zeroClipDraftRows': 1,
        'missingSourceMediaFiles': 1,
      });
    });

    test('returns aggregate counts without identifiers or paths', () async {
      await saveDraft(
        id: 'sensitive-row-id',
        owner: _ownerB,
        clipId: 'sensitive-clip-id',
        filePath: 'sensitive-filename.mp4',
      );

      final diagnostics = await LocalContentDiagnosticsService(
        clipsDao: database.clipsDao,
        draftsDao: database.draftsDao,
        ownerPubkey: _ownerA,
        documentsPath: '/private/documents',
        fileExists: (_) async => false,
      ).collect();
      final encoded = jsonEncode(diagnostics);

      expect(encoded, isNot(contains(_ownerB)));
      expect(encoded, isNot(contains('sensitive-row-id')));
      expect(encoded, isNot(contains('sensitive-clip-id')));
      expect(encoded, isNot(contains('sensitive-filename.mp4')));
      expect(encoded, isNot(contains('/private/documents')));
    });

    test('collecting diagnostics does not change stored rows', () async {
      await saveDraft(id: 'zero-clip-draft', owner: _ownerA);
      final beforeDrafts = await database.draftsDao.getAllDrafts();
      final beforeClips = await database.clipsDao.getAllClips(
        includeTrashed: true,
      );

      await LocalContentDiagnosticsService(
        clipsDao: database.clipsDao,
        draftsDao: database.draftsDao,
        ownerPubkey: _ownerA,
        documentsPath: '/documents',
        fileExists: (_) async => false,
      ).collect();

      expect(await database.draftsDao.getAllDrafts(), beforeDrafts);
      expect(
        await database.clipsDao.getAllClips(includeTrashed: true),
        beforeClips,
      );
    });

    test(
      'counts drafts with only trashed clips as having zero clips',
      () async {
        await saveDraft(
          id: 'draft-with-trashed-clip',
          owner: _ownerA,
          clipId: 'trashed-clip',
        );
        final storedClip = (await database.clipsDao.getClipsByDraftId(
          'draft-with-trashed-clip',
        )).single;
        final deleted = await database.clipsDao.softDeleteClip(
          id: storedClip.id,
          deletedAt: DateTime(2026, 8, 29),
        );
        expect(deleted, isTrue);

        final diagnostics = await LocalContentDiagnosticsService(
          clipsDao: database.clipsDao,
          draftsDao: database.draftsDao,
          ownerPubkey: _ownerA,
          documentsPath: '/documents',
          fileExists: (_) async => true,
        ).collect();

        expect(diagnostics['zeroClipDraftRows'], 1);
      },
    );
  });
}
