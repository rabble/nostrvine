// ABOUTME: Integration test for complete auto-draft flow from recording to publish
// ABOUTME: Validates end-to-end behavior: record → auto-draft → edit → publish → retry
import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import '../mocks/mock_path_provider_platform.dart';

void main() {
  group('Auto-draft complete flow integration', () {
    late AppDatabase database;
    late Directory tempDir;
    late Directory documentsDir;
    late Directory supportDir;
    late PathProviderPlatform originalPathProviderInstance;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      tempDir = Directory.systemTemp.createTempSync(
        'auto_draft_complete_flow_test_',
      );
      documentsDir = Directory('${tempDir.path}/documents')..createSync();
      supportDir = Directory('${tempDir.path}/support')..createSync();

      originalPathProviderInstance = PathProviderPlatform.instance;
      final mockPathProvider = MockPathProviderPlatform()
        ..setTemporaryPath(tempDir.path)
        ..setApplicationDocumentsPath(documentsDir.path)
        ..setApplicationSupportPath(supportDir.path);
      PathProviderPlatform.instance = mockPathProvider;

      database = AppDatabase.test(NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
      PathProviderPlatform.instance = originalPathProviderInstance;
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    String createVideoFile(String basename) {
      final file = File('${documentsDir.path}/$basename');
      file.writeAsBytesSync([0]);
      return file.path;
    }

    test('record → auto-draft → edit → publish flow', () async {
      final draftStorage = DraftStorageService(
        draftsDao: database.draftsDao,
        clipsDao: database.clipsDao,
      );

      // Simulate recording completion with auto-draft
      // (This test documents the expected flow)

      // 1. Recording stops → draft created automatically
      // (Tested in VineRecordingProvider tests)

      // 2. Preview screen loads draft by ID
      final draft = DivineVideoDraft.create(
        clips: [
          DivineVideoClip(
            id: 'id',
            video: EditorVideo.file(createVideoFile('recorded-video.mp4')),
            duration: const Duration(seconds: 4),
            recordedAt: .now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          ),
        ],
        title: 'Do it for the Vine!',
        description: '',
        hashtags: {'openvine', 'vine'},
        selectedApproach: 'native',
      );
      await draftStorage.saveDraft(draft);

      // 3. User edits metadata
      final edited = draft.copyWith(
        title: 'My Awesome Vine',
        description: 'This is cool',
      );
      await draftStorage.saveDraft(edited);

      // 4. Verify no duplicate drafts
      final drafts = await draftStorage.getAllDrafts();
      expect(drafts.length, 1);
      expect(drafts.first.id, draft.id);
      expect(drafts.first.title, 'My Awesome Vine');

      // 5. Publish attempt updates status
      final publishing = edited.copyWith(
        publishStatus: PublishStatus.publishing,
      );
      await draftStorage.saveDraft(publishing);

      final afterPublishing = await draftStorage.getAllDrafts();
      expect(afterPublishing.first.publishStatus, PublishStatus.publishing);

      // 6. Success deletes draft
      await draftStorage.deleteDraft(draft.id);

      final afterDelete = await draftStorage.getAllDrafts();
      expect(afterDelete, isEmpty);
    });

    test('record → auto-draft → failed publish → retry flow', () async {
      final draftStorage = DraftStorageService(
        draftsDao: database.draftsDao,
        clipsDao: database.clipsDao,
      );

      // 1. Auto-draft created
      final draft = DivineVideoDraft.create(
        clips: [
          DivineVideoClip(
            id: 'id',
            video: EditorVideo.file(createVideoFile('retry-video.mp4')),
            duration: const Duration(seconds: 4),
            recordedAt: .now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          ),
        ],
        title: 'Test Video',
        description: '',
        hashtags: {'test'},
        selectedApproach: 'native',
      );
      await draftStorage.saveDraft(draft);

      // 2. Publish fails
      final failed = draft.copyWith(
        publishStatus: PublishStatus.failed,
        publishError: 'Network timeout',
        publishAttempts: 1,
      );
      await draftStorage.saveDraft(failed);

      // 3. Draft still exists with error
      final drafts = await draftStorage.getAllDrafts();
      expect(drafts.length, 1);
      expect(drafts.first.publishStatus, PublishStatus.failed);
      expect(drafts.first.publishError, 'Network timeout');
      expect(drafts.first.canRetry, true);

      // 4. Retry attempt
      final retrying = failed.copyWith(
        publishStatus: PublishStatus.publishing,
        publishAttempts: 2,
      );
      await draftStorage.saveDraft(retrying);

      final afterRetry = await draftStorage.getAllDrafts();
      expect(afterRetry.first.publishAttempts, 2);

      // 5. Success deletes draft
      await draftStorage.deleteDraft(draft.id);

      final afterSuccess = await draftStorage.getAllDrafts();
      expect(afterSuccess, isEmpty);
    });
  });
}
