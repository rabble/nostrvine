// ABOUTME: Test for new startUploadFromDraft() unified upload flow
// ABOUTME: Verifies ProofMode data flows correctly from draft to upload

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:models/models.dart' show AspectRatio;
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/blossom_upload_service.dart';
import '../helpers/test_helpers.dart';

@GenerateMocks([BlossomUploadService])
import 'upload_manager_from_draft_test.mocks.dart';

void main() {
  group('UploadManager.startUploadFromDraft', () {
    late UploadManager uploadManager;
    late MockBlossomUploadService mockBlossomService;

    setUpAll(() async {
      await setupTestEnvironment();
    });

    setUp(() async {
      mockBlossomService = MockBlossomUploadService();
      uploadManager = UploadManager(blossomService: mockBlossomService);
      await uploadManager.initialize();
    });

    test('should create upload from draft with ProofMode data', () async {
      // Create draft with ProofMode JSON
      final testFile = File('test_video.mp4');
      final proofJson = '{"segments":[],"deviceAttestation":null}';

      final draft = VineDraft.create(
        clips: [
          RecordingClip(
            id: 'test_clip',
            video: EditorVideo.file(testFile.path),
            duration: Duration(seconds: 6),
            recordedAt: DateTime.now(),
            aspectRatio: AspectRatio.square,
          ),
        ],
        title: 'Test Video',
        description: 'Test Description',
        hashtags: {'test'},
        selectedApproach: 'native',
        proofManifestJson: proofJson,
      );

      expect(draft.hasProofMode, isTrue);
      expect(draft.proofManifestJson, equals(proofJson));

      final upload = await uploadManager.startUploadFromDraft(
        draft: draft,
        nostrPubkey: 'test-pubkey',
        videoDuration: Duration(seconds: 5),
      );

      expect(upload.title, equals('Test Video'));
      expect(upload.description, equals('Test Description'));
      expect(upload.hashtags, containsAll(['test']));
      expect(upload.proofManifestJson, equals(proofJson));
      expect(upload.hasProofMode, isTrue);
    });

    test('should preserve ProofMode data through draft copyWith', () async {
      final testFile = File('test_video.mp4');
      final proofJson = '{"segments":[],"deviceAttestation":null}';

      final originalDraft = VineDraft.create(
        clips: [
          RecordingClip(
            id: 'test_clip',
            video: EditorVideo.file(testFile.path),
            duration: Duration(seconds: 6),
            recordedAt: DateTime.now(),
            aspectRatio: AspectRatio.square,
          ),
        ],
        title: 'Original Title',
        description: 'Original Description',
        hashtags: {'original'},
        selectedApproach: 'native',
        proofManifestJson: proofJson,
      );

      // Update metadata while preserving ProofMode
      final updatedDraft = originalDraft.copyWith(
        title: 'Updated Title',
        description: 'Updated Description',
        hashtags: {'updated'},
      );

      expect(updatedDraft.title, equals('Updated Title'));
      expect(updatedDraft.description, equals('Updated Description'));
      expect(updatedDraft.hashtags, containsAll(['updated']));
      expect(updatedDraft.proofManifestJson, equals(proofJson));
      expect(updatedDraft.hasProofMode, isTrue);

      final upload = await uploadManager.startUploadFromDraft(
        draft: updatedDraft,
        nostrPubkey: 'test-pubkey',
        videoDuration: Duration(seconds: 5),
      );

      expect(upload.title, equals('Updated Title'));
      expect(upload.proofManifestJson, equals(proofJson));
    });

    test('should handle draft without ProofMode data', () async {
      final testFile = File('test_video.mp4');

      final draft = VineDraft.create(
        clips: [
          RecordingClip(
            id: 'test_clip',
            video: EditorVideo.file(testFile.path),
            duration: Duration(seconds: 6),
            recordedAt: DateTime.now(),
            aspectRatio: AspectRatio.square,
          ),
        ],
        title: 'Test Video',
        description: 'Test Description',
        hashtags: {'test'},
        selectedApproach: 'native',
      );

      expect(draft.hasProofMode, isFalse);
      expect(draft.proofManifestJson, isNull);

      final upload = await uploadManager.startUploadFromDraft(
        draft: draft,
        nostrPubkey: 'test-pubkey',
        videoDuration: Duration(seconds: 5),
      );

      expect(upload.title, equals('Test Video'));
      expect(upload.hasProofMode, isFalse);
      expect(upload.proofManifestJson, isNull);
    });
  });
}
