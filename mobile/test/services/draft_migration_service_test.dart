// ABOUTME: Tests for migrating VineDrafts to SavedClips
// ABOUTME: Verifies one-time migration preserves video files

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show AspectRatio;
import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
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
      TestWidgetsFlutterBinding.ensureInitialized();

      // Create temp directory first so we can use its path in mock
      tempDir = await Directory.systemTemp.createTemp('migration_test_');

      // Mock path provider to return our temp directory
      const MethodChannel pathProviderChannel = MethodChannel(
        'plugins.flutter.io/path_provider',
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProviderChannel, (
            MethodCall methodCall,
          ) async {
            switch (methodCall.method) {
              case 'getTemporaryDirectory':
                return tempDir.path;
              case 'getApplicationDocumentsDirectory':
                return tempDir.path;
              case 'getApplicationSupportDirectory':
                return tempDir.path;
              default:
                return null;
            }
          });

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      draftService = DraftStorageService();
      clipService = ClipLibraryService();
      migrationService = DraftMigrationService(
        draftService: draftService,
        clipService: clipService,
        prefs: prefs,
      );
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
        clips: [
          RecordingClip(
            id: 'clip_123',
            video: EditorVideo.file(videoFile.path),
            duration: Duration(seconds: 6),
            recordedAt: DateTime(2025, 12, 18, 10, 0),
            targetAspectRatio: AspectRatio.square,
            originalAspectRatio: 9 / 16,
          ),
        ],
        title: 'Test Draft',
        description: 'Description',
        hashtags: {'test'},
        selectedApproach: 'native',
        createdAt: DateTime(2025, 12, 18, 10, 0),
        lastModified: DateTime(2025, 12, 18, 10, 0),
        publishStatus: PublishStatus.draft,
        publishError: null,
        publishAttempts: 0,
      );

      await draftService.saveDraft(draft);

      final result = await migrationService.migrate();

      expect(result.migratedCount, 1);
      expect(result.skippedCount, 0);

      final clips = await clipService.getAllClips();
      expect(clips.length, 1);
      // Use endsWith to handle path separator differences between platforms
      expect(clips.first.filePath, endsWith('draft_video.mp4'));
      expect(clips.first.sessionId, 'migrated_draft_123');
    });

    test('should skip drafts with missing video files', () async {
      final draft = VineDraft(
        id: 'draft_orphan',
        clips: [
          RecordingClip(
            id: 'clip_orphan',
            video: EditorVideo.file('/nonexistent/video.mp4'),
            duration: Duration.zero,
            recordedAt: DateTime.now(),
            targetAspectRatio: AspectRatio.square,
            originalAspectRatio: 9 / 16,
          ),
        ],
        title: 'Orphan Draft',
        description: '',
        hashtags: {},
        selectedApproach: 'native',
        createdAt: DateTime.now(),
        lastModified: DateTime.now(),
        publishStatus: PublishStatus.draft,
        publishError: null,
        publishAttempts: 0,
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
        clips: [
          RecordingClip(
            id: 'clip_456',
            video: EditorVideo.file(videoFile.path),
            duration: Duration.zero,
            recordedAt: DateTime.now(),
            targetAspectRatio: AspectRatio.square,
            originalAspectRatio: 9 / 16,
          ),
        ],
        title: 'Test',
        description: '',
        hashtags: {},
        selectedApproach: 'native',
        createdAt: DateTime.now(),
        lastModified: DateTime.now(),
        publishStatus: PublishStatus.draft,
        publishError: null,
        publishAttempts: 0,
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
        clips: [
          RecordingClip(
            id: 'clip_789',
            video: EditorVideo.file(videoFile.path),
            duration: Duration.zero,
            recordedAt: DateTime.now(),
            targetAspectRatio: AspectRatio.square,
            originalAspectRatio: 9 / 16,
          ),
        ],
        title: 'Test',
        description: '',
        hashtags: {},
        selectedApproach: 'native',
        createdAt: DateTime.now(),
        lastModified: DateTime.now(),
        publishStatus: PublishStatus.draft,
        publishError: null,
        publishAttempts: 0,
      );

      await draftService.saveDraft(draft);
      await migrationService.migrate();

      final remainingDrafts = await draftService.getAllDrafts();
      expect(remainingDrafts, isEmpty);
    });
  });
}
