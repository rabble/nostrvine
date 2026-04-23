// ABOUTME: TDD tests for DraftStorageService - persistent storage for vine drafts
// ABOUTME: Tests save, load, delete, clear, and migration operations using Drift

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show AspectRatio;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mocks/mock_path_provider_platform.dart';

void main() {
  group('DraftStorageService', () {
    late AppDatabase database;
    late DraftStorageService service;

    setUp(() async {
      // Start with clean in-memory database for each test
      database = AppDatabase.test(NativeDatabase.memory());
      service = DraftStorageService(
        draftsDao: database.draftsDao,
        clipsDao: database.clipsDao,
      );
    });

    tearDown(() async {
      await database.close();
    });

    group('saveDraft', () {
      test('should save a draft to storage', () async {
        final draft = DivineVideoDraft.create(
          clips: [
            DivineVideoClip(
              id: 'test_clip',
              video: EditorVideo.file('/path/to/video.mp4'),
              duration: const Duration(seconds: 6),
              recordedAt: DateTime.now(),
              targetAspectRatio: AspectRatio.square,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: 'Test Vine',
          description: 'A test description',
          hashtags: {'test', 'vine'},
          selectedApproach: 'hybrid',
        );

        await service.saveDraft(draft);

        final drafts = await service.getAllDrafts();
        expect(drafts.length, 1);
        expect(drafts.first.id, draft.id);
        expect(drafts.first.title, 'Test Vine');
        expect(drafts.first.description, 'A test description');
        expect(drafts.first.hashtags, ['test', 'vine']);
        expect(drafts.first.selectedApproach, 'hybrid');
      });

      test('should save multiple drafts', () async {
        final now = DateTime.now();
        final draft1 = DivineVideoDraft(
          id: 'draft_1',
          clips: [
            DivineVideoClip(
              id: 'clip_1',
              video: EditorVideo.file('/path/to/video1.mp4'),
              duration: const Duration(seconds: 6),
              recordedAt: now,
              targetAspectRatio: AspectRatio.square,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: 'First Vine',
          description: 'First',
          hashtags: {'first'},
          selectedApproach: 'hybrid',
          createdAt: now,
          lastModified: now,
          publishStatus: PublishStatus.draft,
          publishAttempts: 0,
        );

        final draft2 = DivineVideoDraft(
          id: 'draft_2',
          clips: [
            DivineVideoClip(
              id: 'clip_2',
              video: EditorVideo.file('/path/to/video2.mp4'),
              duration: const Duration(seconds: 6),
              recordedAt: now,
              targetAspectRatio: AspectRatio.square,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: 'Second Vine',
          description: 'Second',
          hashtags: {'second'},
          selectedApproach: 'imageSequence',
          createdAt: now,
          lastModified: now,
          publishStatus: PublishStatus.draft,
          publishAttempts: 0,
        );

        await service.saveDraft(draft1);
        await service.saveDraft(draft2);

        final drafts = await service.getAllDrafts();
        expect(drafts.length, 2);
        expect(drafts[0].title, 'First Vine');
        expect(drafts[1].title, 'Second Vine');
      });

      test('should update existing draft if ID matches', () async {
        final draft = DivineVideoDraft.create(
          clips: [
            DivineVideoClip(
              id: 'test_clip',
              video: EditorVideo.file('/path/to/video.mp4'),
              duration: const Duration(seconds: 6),
              recordedAt: DateTime.now(),
              targetAspectRatio: AspectRatio.square,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: 'Original Title',
          description: 'Original',
          hashtags: {'original'},
          selectedApproach: 'hybrid',
        );

        await service.saveDraft(draft);

        final updated = draft.copyWith(
          title: 'Updated Title',
          description: 'Updated description',
        );

        await service.saveDraft(updated);

        final drafts = await service.getAllDrafts();
        expect(drafts.length, 1);
        expect(drafts.first.title, 'Updated Title');
        expect(drafts.first.description, 'Updated description');
      });
    });

    group('getAllDrafts', () {
      test('should return empty list when no drafts exist', () async {
        final drafts = await service.getAllDrafts();
        expect(drafts, isEmpty);
      });

      test('should return all saved drafts', () async {
        final now = DateTime.now();
        final draft1 = DivineVideoDraft(
          id: 'draft_1',
          clips: [
            DivineVideoClip(
              id: 'clip_1',
              video: EditorVideo.file('/path/to/video1.mp4'),
              duration: const Duration(seconds: 6),
              recordedAt: now,
              targetAspectRatio: AspectRatio.square,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: 'First',
          description: '',
          hashtags: {},
          selectedApproach: 'hybrid',
          createdAt: now,
          lastModified: now,
          publishStatus: PublishStatus.draft,
          publishAttempts: 0,
        );

        final draft2 = DivineVideoDraft(
          id: 'draft_2',
          clips: [
            DivineVideoClip(
              id: 'clip_2',
              video: EditorVideo.file('/path/to/video2.mp4'),
              duration: const Duration(seconds: 6),
              recordedAt: now,
              targetAspectRatio: AspectRatio.square,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: 'Second',
          description: '',
          hashtags: {},
          selectedApproach: 'imageSequence',
          createdAt: now,
          lastModified: now,
          publishStatus: PublishStatus.draft,
          publishAttempts: 0,
        );

        await service.saveDraft(draft1);
        await service.saveDraft(draft2);

        final drafts = await service.getAllDrafts();
        expect(drafts.length, 2);
      });

      test('should return empty when database is empty', () async {
        final drafts = await service.getAllDrafts();
        expect(drafts, isEmpty);
      });

      test('should remove corrupted drafts with 0 clips', () async {
        // Insert a draft row directly via DAO (no clips)
        await database.draftsDao.upsertDraft(
          id: 'corrupted_draft',
          title: 'Corrupted',
          description: '',
          publishStatus: 'draft',
          createdAt: DateTime(2025),
          lastModified: DateTime(2025),
          renderedFilePath: null,
          renderedThumbnailPath: null,
          data: '{"title":"Corrupted","description":""}',
        );

        // Verify draft row exists
        final row = await database.draftsDao.getDraftById(
          'corrupted_draft',
        );
        expect(row, isNotNull);

        // getAllDrafts should skip it and delete it
        final drafts = await service.getAllDrafts();
        expect(drafts, isEmpty);

        // Draft row should be deleted from DB
        final rowAfter = await database.draftsDao.getDraftById(
          'corrupted_draft',
        );
        expect(rowAfter, isNull);
      });
    });

    group('deleteDraft', () {
      test('should delete draft by ID', () async {
        final now = DateTime.now();
        final draft1 = DivineVideoDraft(
          id: 'draft_1',
          clips: [
            DivineVideoClip(
              id: 'clip_1',
              video: EditorVideo.file('/path/to/video1.mp4'),
              duration: const Duration(seconds: 6),
              recordedAt: now,
              targetAspectRatio: AspectRatio.square,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: 'First',
          description: '',
          hashtags: {},
          selectedApproach: 'hybrid',
          createdAt: now,
          lastModified: now,
          publishStatus: PublishStatus.draft,
          publishAttempts: 0,
        );

        final draft2 = DivineVideoDraft(
          id: 'draft_2',
          clips: [
            DivineVideoClip(
              id: 'clip_2',
              video: EditorVideo.file('/path/to/video2.mp4'),
              duration: const Duration(seconds: 6),
              recordedAt: now,
              targetAspectRatio: AspectRatio.square,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: 'Second',
          description: '',
          hashtags: {},
          selectedApproach: 'imageSequence',
          createdAt: now,
          lastModified: now,
          publishStatus: PublishStatus.draft,
          publishAttempts: 0,
        );

        await service.saveDraft(draft1);
        await service.saveDraft(draft2);

        await service.deleteDraft(draft1.id);

        final drafts = await service.getAllDrafts();
        expect(drafts.length, 1);
        expect(drafts.first.id, draft2.id);
        expect(drafts.first.title, 'Second');
      });

      test('should do nothing if draft ID does not exist', () async {
        final draft = DivineVideoDraft.create(
          clips: [
            DivineVideoClip(
              id: 'test_clip',
              video: EditorVideo.file('/path/to/video.mp4'),
              duration: const Duration(seconds: 6),
              recordedAt: DateTime.now(),
              targetAspectRatio: AspectRatio.square,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: 'Test',
          description: '',
          hashtags: {},
          selectedApproach: 'hybrid',
        );

        await service.saveDraft(draft);
        await service.deleteDraft('nonexistent-id');

        final drafts = await service.getAllDrafts();
        expect(drafts.length, 1);
      });
    });

    group('clearAllDrafts', () {
      test('should remove all drafts from storage', () async {
        final now = DateTime.now();
        final draft1 = DivineVideoDraft(
          id: 'draft_1',
          clips: [
            DivineVideoClip(
              id: 'clip_1',
              video: EditorVideo.file('/path/to/video1.mp4'),
              duration: const Duration(seconds: 6),
              recordedAt: now,
              targetAspectRatio: AspectRatio.square,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: 'First',
          description: '',
          hashtags: {},
          selectedApproach: 'hybrid',
          createdAt: now,
          lastModified: now,
          publishStatus: PublishStatus.draft,
          publishAttempts: 0,
        );

        final draft2 = DivineVideoDraft(
          id: 'draft_2',
          clips: [
            DivineVideoClip(
              id: 'clip_2',
              video: EditorVideo.file('/path/to/video2.mp4'),
              duration: const Duration(seconds: 6),
              recordedAt: now,
              targetAspectRatio: AspectRatio.square,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: 'Second',
          description: '',
          hashtags: {},
          selectedApproach: 'imageSequence',
          createdAt: now,
          lastModified: now,
          publishStatus: PublishStatus.draft,
          publishAttempts: 0,
        );

        await service.saveDraft(draft1);
        await service.saveDraft(draft2);

        await service.clearAllDrafts();

        final drafts = await service.getAllDrafts();
        expect(drafts, isEmpty);
      });

      test('should handle clearing when no drafts exist', () async {
        await service.clearAllDrafts();

        final drafts = await service.getAllDrafts();
        expect(drafts, isEmpty);
      });
    });

    group('updatePublishStatus', () {
      test('should update publish status of an existing draft', () async {
        final draft = DivineVideoDraft.create(
          clips: [
            DivineVideoClip(
              id: 'test_clip',
              video: EditorVideo.file('/path/to/video.mp4'),
              duration: const Duration(seconds: 6),
              recordedAt: DateTime.now(),
              targetAspectRatio: AspectRatio.square,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: 'Test Vine',
          description: '',
          hashtags: {},
          selectedApproach: 'hybrid',
        );

        await service.saveDraft(draft);

        await service.updatePublishStatus(
          draftId: draft.id,
          status: PublishStatus.publishing,
        );

        // updatePublishStatus updates the column used for filtering
        final publishing = await service.getDraftsByPublishStatuses(
          {PublishStatus.publishing},
        );
        expect(publishing, hasLength(1));
        expect(publishing.first.id, equals(draft.id));

        final drafts = await service.getDraftsByPublishStatuses(
          {PublishStatus.draft},
        );
        expect(drafts, isEmpty);
      });

      test('should update publish status with error message', () async {
        final draft = DivineVideoDraft.create(
          clips: [
            DivineVideoClip(
              id: 'test_clip',
              video: EditorVideo.file('/path/to/video.mp4'),
              duration: const Duration(seconds: 6),
              recordedAt: DateTime.now(),
              targetAspectRatio: AspectRatio.square,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: 'Test Vine',
          description: '',
          hashtags: {},
          selectedApproach: 'hybrid',
        );

        await service.saveDraft(draft);

        await service.updatePublishStatus(
          draftId: draft.id,
          status: PublishStatus.failed,
          publishError: 'Network error',
        );

        final failed = await service.getDraftsByPublishStatuses(
          {PublishStatus.failed},
        );
        expect(failed, hasLength(1));

        // Verify error stored at DB row level
        final row = await database.draftsDao.getDraftById(draft.id);
        expect(row, isNotNull);
        expect(row!.publishError, equals('Network error'));
      });

      test('should transition through multiple statuses', () async {
        final draft = DivineVideoDraft.create(
          clips: [
            DivineVideoClip(
              id: 'test_clip',
              video: EditorVideo.file('/path/to/video.mp4'),
              duration: const Duration(seconds: 6),
              recordedAt: DateTime.now(),
              targetAspectRatio: AspectRatio.square,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: 'Test Vine',
          description: '',
          hashtags: {},
          selectedApproach: 'hybrid',
        );

        await service.saveDraft(draft);

        await service.updatePublishStatus(
          draftId: draft.id,
          status: PublishStatus.publishing,
        );
        var matches = await service.getDraftsByPublishStatuses(
          {PublishStatus.publishing},
        );
        expect(matches, hasLength(1));

        await service.updatePublishStatus(
          draftId: draft.id,
          status: PublishStatus.failed,
          publishError: 'Timeout',
        );
        matches = await service.getDraftsByPublishStatuses(
          {PublishStatus.failed},
        );
        expect(matches, hasLength(1));

        await service.updatePublishStatus(
          draftId: draft.id,
          status: PublishStatus.draft,
        );
        matches = await service.getDraftsByPublishStatuses(
          {PublishStatus.draft},
        );
        expect(matches, hasLength(1));
      });
    });

    group('getDraftsByPublishStatuses', () {
      DivineVideoDraft createDraftWithStatus(
        String id,
        PublishStatus status,
      ) {
        final now = DateTime.now();
        return DivineVideoDraft(
          id: id,
          clips: [
            DivineVideoClip(
              id: 'clip_$id',
              video: EditorVideo.file('/path/to/$id.mp4'),
              duration: const Duration(seconds: 6),
              recordedAt: now,
              targetAspectRatio: AspectRatio.square,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: 'Draft $id',
          description: '',
          hashtags: {},
          selectedApproach: 'hybrid',
          createdAt: now,
          lastModified: now,
          publishStatus: status,
          publishAttempts: 0,
        );
      }

      test(
        'should return only drafts matching the requested statuses',
        () async {
          await service.saveDraft(
            createDraftWithStatus('d1', PublishStatus.draft),
          );
          await service.saveDraft(
            createDraftWithStatus('d2', PublishStatus.publishing),
          );
          await service.saveDraft(
            createDraftWithStatus('d3', PublishStatus.failed),
          );

          final results = await service.getDraftsByPublishStatuses(
            {PublishStatus.publishing, PublishStatus.failed},
          );

          expect(results, hasLength(2));
          final ids = results.map((d) => d.id).toSet();
          expect(ids, containsAll(['d2', 'd3']));
        },
      );

      test('should return empty list when no drafts match', () async {
        await service.saveDraft(
          createDraftWithStatus('d1', PublishStatus.draft),
        );

        final results = await service.getDraftsByPublishStatuses(
          {PublishStatus.failed},
        );

        expect(results, isEmpty);
      });

      test('should remove corrupted drafts with 0 clips', () async {
        // Insert a draft row directly via DAO (no clips)
        await database.draftsDao.upsertDraft(
          id: 'corrupted',
          title: 'Corrupted',
          description: '',
          publishStatus: 'failed',
          createdAt: DateTime(2025),
          lastModified: DateTime(2025),
          renderedFilePath: null,
          renderedThumbnailPath: null,
          data: '{"title":"Corrupted","description":""}',
        );

        final results = await service.getDraftsByPublishStatuses(
          {PublishStatus.failed},
        );

        expect(results, isEmpty);

        // Corrupted row should be deleted
        final row = await database.draftsDao.getDraftById('corrupted');
        expect(row, isNull);
      });

      test('should return drafts for a single status', () async {
        await service.saveDraft(
          createDraftWithStatus('d1', PublishStatus.failed),
        );
        await service.saveDraft(
          createDraftWithStatus('d2', PublishStatus.failed),
        );
        await service.saveDraft(
          createDraftWithStatus('d3', PublishStatus.draft),
        );

        final results = await service.getDraftsByPublishStatuses(
          {PublishStatus.failed},
        );

        expect(results, hasLength(2));
        expect(
          results.every((d) => d.publishStatus == PublishStatus.failed),
          isTrue,
        );
      });
    });

    group('migrateOldDrafts', () {
      const documentsPath = '/tmp/documents';
      late PathProviderPlatform originalPathProviderInstance;

      setUp(() {
        TestWidgetsFlutterBinding.ensureInitialized();

        // Save the current PathProviderPlatform.instance so tearDown can
        // restore it. Without this, the `MockPathProviderPlatform` installed
        // below leaks into subsequent test files in the VGV shared isolate;
        // any test that transitively calls `getApplicationDocumentsDirectory`
        // (e.g. `VideoThumbnailService.extractThumbnail`) gets the mock's
        // `/tmp/documents` path and fails with I/O errors.
        originalPathProviderInstance = PathProviderPlatform.instance;
        final mockPlatform = MockPathProviderPlatform()
          ..setApplicationDocumentsPath(documentsPath);
        PathProviderPlatform.instance = mockPlatform;
        SharedPreferences.setMockInitialValues({});
      });

      tearDown(() {
        PathProviderPlatform.instance = originalPathProviderInstance;
        SharedPreferences.resetStatic();
      });

      Map<String, dynamic> buildClipJson({
        required String id,
        String filePath = 'video.mp4',
        int durationMs = 6000,
        DateTime? recordedAt,
      }) {
        return {
          'id': id,
          'filePath': filePath,
          'durationMs': durationMs,
          'recordedAt': (recordedAt ?? DateTime(2025)).toIso8601String(),
          'targetAspectRatio': 'square',
        };
      }

      Map<String, dynamic> buildDraftJson({
        required String id,
        required List<Map<String, dynamic>> clips,
        String title = 'Test Draft',
        String description = '',
        String publishStatus = 'draft',
        DateTime? createdAt,
        DateTime? lastModified,
      }) {
        final now = createdAt ?? DateTime(2025);
        return {
          'id': id,
          'clips': clips,
          'title': title,
          'description': description,
          'hashtags': <String>[],
          'selectedApproach': 'hybrid',
          'createdAt': now.toIso8601String(),
          'lastModified': (lastModified ?? now).toIso8601String(),
          'publishStatus': publishStatus,
          'publishAttempts': 0,
        };
      }

      test('does nothing when no legacy data exists', () async {
        SharedPreferences.setMockInitialValues({});

        await service.migrateOldDrafts();

        final drafts = await service.getAllDrafts();
        expect(drafts, isEmpty);
      });

      test('does nothing when legacy key is empty string', () async {
        SharedPreferences.setMockInitialValues({'vine_drafts': ''});

        await service.migrateOldDrafts();

        final drafts = await service.getAllDrafts();
        expect(drafts, isEmpty);
      });

      test(
        'migrates a single draft with one clip',
        () async {
          final draftJson = buildDraftJson(
            id: 'draft_1',
            clips: [buildClipJson(id: 'clip_1')],
            title: 'My First Vine',
            description: 'A test description',
          );
          SharedPreferences.setMockInitialValues({
            'vine_drafts': json.encode([draftJson]),
          });

          await service.migrateOldDrafts();

          final drafts = await service.getAllDrafts();
          expect(drafts, hasLength(1));
          expect(drafts.first.id, equals('draft_1'));
          expect(drafts.first.title, equals('My First Vine'));
          expect(drafts.first.description, equals('A test description'));
          expect(drafts.first.clips, hasLength(1));
          expect(drafts.first.clips.first.id, equals('clip_1'));

          // Legacy key should be removed
          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getString('vine_drafts'), isNull);
        },
      );

      test(
        'migrates multiple drafts with multiple clips',
        () async {
          final draft1 = buildDraftJson(
            id: 'draft_a',
            clips: [
              buildClipJson(id: 'clip_a1', filePath: 'a1.mp4'),
              buildClipJson(id: 'clip_a2', filePath: 'a2.mp4'),
            ],
            title: 'Draft A',
          );
          final draft2 = buildDraftJson(
            id: 'draft_b',
            clips: [
              buildClipJson(id: 'clip_b1', filePath: 'b1.mp4'),
            ],
            title: 'Draft B',
          );
          SharedPreferences.setMockInitialValues({
            'vine_drafts': json.encode([draft1, draft2]),
          });

          await service.migrateOldDrafts();

          final drafts = await service.getAllDrafts();
          expect(drafts, hasLength(2));

          final draftA = drafts.firstWhere((d) => d.id == 'draft_a');
          expect(draftA.clips, hasLength(2));

          final draftB = drafts.firstWhere((d) => d.id == 'draft_b');
          expect(draftB.clips, hasLength(1));

          // Legacy key removed after full success
          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getString('vine_drafts'), isNull);
        },
      );

      test(
        'preserves clip order after migration',
        () async {
          final draftJson = buildDraftJson(
            id: 'draft_order',
            clips: [
              buildClipJson(id: 'first', filePath: 'first.mp4'),
              buildClipJson(id: 'second', filePath: 'second.mp4'),
              buildClipJson(id: 'third', filePath: 'third.mp4'),
            ],
          );
          SharedPreferences.setMockInitialValues({
            'vine_drafts': json.encode([draftJson]),
          });

          await service.migrateOldDrafts();

          final drafts = await service.getAllDrafts();
          expect(drafts.first.clips.map((c) => c.id), [
            'first',
            'second',
            'third',
          ]);
        },
      );

      test(
        'preserves publish status through migration',
        () async {
          final draftJson = buildDraftJson(
            id: 'draft_pub',
            clips: [buildClipJson(id: 'clip_pub')],
            publishStatus: 'failed',
          );
          SharedPreferences.setMockInitialValues({
            'vine_drafts': json.encode([draftJson]),
          });

          await service.migrateOldDrafts();

          final drafts = await service.getAllDrafts();
          expect(drafts.first.publishStatus, equals(PublishStatus.failed));
        },
      );

      test(
        'keeps failed drafts in SharedPreferences for retry',
        () async {
          final goodDraft = buildDraftJson(
            id: 'draft_good',
            clips: [buildClipJson(id: 'clip_good')],
            title: 'Good Draft',
          );
          // Malformed draft (missing required fields) — will fail fromJson
          final badDraft = <String, dynamic>{
            'id': 'draft_bad',
            'title': 'Bad Draft',
            // Missing 'clips', 'description', 'hashtags', etc.
          };

          SharedPreferences.setMockInitialValues({
            'vine_drafts': json.encode([goodDraft, badDraft]),
          });

          await service.migrateOldDrafts();

          // Good draft should be in database
          final drafts = await service.getAllDrafts();
          expect(drafts, hasLength(1));
          expect(drafts.first.id, equals('draft_good'));

          // Failed draft stays in SharedPreferences for retry
          final prefs = await SharedPreferences.getInstance();
          final remaining = prefs.getString('vine_drafts');
          expect(remaining, isNotNull);

          final remainingList = json.decode(remaining!) as List<dynamic>;
          expect(remainingList, hasLength(1));
          expect(
            (remainingList.first as Map<String, dynamic>)['id'],
            equals('draft_bad'),
          );
        },
      );

      test(
        'is idempotent — re-running migrates without duplicates',
        () async {
          final draftJson = buildDraftJson(
            id: 'draft_idem',
            clips: [buildClipJson(id: 'clip_idem')],
          );
          SharedPreferences.setMockInitialValues({
            'vine_drafts': json.encode([draftJson]),
          });

          await service.migrateOldDrafts();

          // Re-populate SharedPreferences to simulate a partial retry
          SharedPreferences.setMockInitialValues({
            'vine_drafts': json.encode([draftJson]),
          });
          await service.migrateOldDrafts();

          final drafts = await service.getAllDrafts();
          // Upsert should not duplicate
          expect(drafts, hasLength(1));
          expect(drafts.first.id, equals('draft_idem'));
        },
      );

      test(
        'migrates old single-clip format with videoFilePath',
        () async {
          // Legacy format before multi-clip support
          final legacyDraft = {
            'id': 'draft_legacy',
            'videoFilePath': 'old_video.mp4',
            'title': 'Legacy Vine',
            'description': 'Old format',
            'hashtags': <String>[],
            'selectedApproach': 'hybrid',
            'createdAt': DateTime(2024).toIso8601String(),
            'lastModified': DateTime(2024).toIso8601String(),
            'aspectRatio': 'square',
            'publishStatus': 'draft',
            'publishAttempts': 0,
          };

          SharedPreferences.setMockInitialValues({
            'vine_drafts': json.encode([legacyDraft]),
          });

          await service.migrateOldDrafts();

          final drafts = await service.getAllDrafts();
          expect(drafts, hasLength(1));
          expect(drafts.first.id, equals('draft_legacy'));
          expect(drafts.first.title, equals('Legacy Vine'));
          // Old format creates a single clip
          expect(drafts.first.clips, hasLength(1));
        },
      );
    });
  });
}
