// ABOUTME: Tests for migrating VineDrafts to SavedClips
// ABOUTME: Verifies one-time migration preserves video files

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show AspectRatio;
import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/draft_migration_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('DraftMigrationService', () {
    late DraftMigrationService migrationService;
    late DraftStorageService draftService;
    late ClipLibraryService clipService;
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      draftService = DraftStorageService(prefs);
      clipService = ClipLibraryService(prefs);
      migrationService = DraftMigrationService(
        draftService: draftService,
        clipService: clipService,
        prefs: prefs,
      );

      tempDir = await Directory.systemTemp.createTemp('migration_test_');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    File createTempVideo(String name) {
      final file = File('${tempDir.path}/$name.mp4');
      file.writeAsStringSync('fake video content');
      return file;
    }

    test('should migrate draft to clip', () async {
      final videoFile = createTempVideo('draft_video');
      final draft = VineDraft(
        id: 'draft_123',
        videoFile: videoFile,
        title: 'Test Draft',
        description: 'Description',
        hashtags: ['test'],
        frameCount: 30,
        selectedApproach: 'native',
        createdAt: DateTime(2025, 12, 18, 10, 0),
        lastModified: DateTime(2025, 12, 18, 10, 0),
        publishStatus: PublishStatus.draft,
        publishError: null,
        publishAttempts: 0,
        aspectRatio: AspectRatio.square,
      );

      await draftService.saveDraft(draft);

      final result = await migrationService.migrate();

      expect(result.migratedCount, 1);
      expect(result.skippedCount, 0);

      final clips = await clipService.getAllClips();
      expect(clips.length, 1);
      expect(clips.first.filePath, videoFile.path);
      expect(clips.first.sessionId, 'migrated_draft_123');
    });

    test('should skip drafts with missing video files', () async {
      final draft = VineDraft(
        id: 'draft_orphan',
        videoFile: File('/nonexistent/video.mp4'),
        title: 'Orphan Draft',
        description: '',
        hashtags: [],
        frameCount: 0,
        selectedApproach: 'native',
        createdAt: DateTime.now(),
        lastModified: DateTime.now(),
        publishStatus: PublishStatus.draft,
        publishError: null,
        publishAttempts: 0,
        aspectRatio: AspectRatio.square,
      );

      await draftService.saveDraft(draft);

      final result = await migrationService.migrate();

      expect(result.migratedCount, 0);
      expect(result.skippedCount, 1);
    });

    test('should only migrate once', () async {
      final videoFile = createTempVideo('draft_video');
      final draft = VineDraft(
        id: 'draft_456',
        videoFile: videoFile,
        title: 'Test',
        description: '',
        hashtags: [],
        frameCount: 0,
        selectedApproach: 'native',
        createdAt: DateTime.now(),
        lastModified: DateTime.now(),
        publishStatus: PublishStatus.draft,
        publishError: null,
        publishAttempts: 0,
        aspectRatio: AspectRatio.square,
      );

      await draftService.saveDraft(draft);

      // First migration
      await migrationService.migrate();

      // Second migration should be no-op
      final result = await migrationService.migrate();

      expect(result.migratedCount, 0);
      expect(result.alreadyMigrated, true);
    });

    test('should clear drafts after successful migration', () async {
      final videoFile = createTempVideo('draft_video');
      final draft = VineDraft(
        id: 'draft_789',
        videoFile: videoFile,
        title: 'Test',
        description: '',
        hashtags: [],
        frameCount: 0,
        selectedApproach: 'native',
        createdAt: DateTime.now(),
        lastModified: DateTime.now(),
        publishStatus: PublishStatus.draft,
        publishError: null,
        publishAttempts: 0,
        aspectRatio: AspectRatio.square,
      );

      await draftService.saveDraft(draft);
      await migrationService.migrate();

      final remainingDrafts = await draftService.getAllDrafts();
      expect(remainingDrafts, isEmpty);
    });
  });
}
