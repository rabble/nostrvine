// ABOUTME: Test for new startUploadFromDraft() unified upload flow
// ABOUTME: Verifies ProofMode data flows correctly from draft to upload

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show AspectRatio;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/services/blossom_upload_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import '../helpers/test_helpers.dart';

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

void main() {
  setUpAll(() async {
    await setupTestEnvironment();
    registerFallbackValue(File(''));
  });

  group('UploadManager.startUploadFromDraft', () {
    late UploadManager uploadManager;
    late _MockBlossomUploadService mockBlossomService;

    setUp(() async {
      mockBlossomService = _MockBlossomUploadService();
      uploadManager = UploadManager(blossomService: mockBlossomService);
      await uploadManager.initialize();
    });

    test('should create upload from draft with ProofMode data', () async {
      // Create draft with ProofMode JSON
      final testFile = File('test_video.mp4');
      const proofJson = '{"segments":[],"deviceAttestation":null}';

      final draft = DivineVideoDraft.create(
        clips: [
          DivineVideoClip(
            id: 'test_clip',
            video: EditorVideo.file(testFile.path),
            duration: const Duration(seconds: 6),
            recordedAt: DateTime.now(),
            targetAspectRatio: AspectRatio.square,
            originalAspectRatio: 9 / 16,
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
        videoDuration: const Duration(seconds: 5),
      );

      expect(upload.title, equals('Test Video'));
      expect(upload.description, equals('Test Description'));
      expect(upload.hashtags, containsAll(['test']));
      expect(upload.proofManifestJson, equals(proofJson));
      expect(upload.hasProofMode, isTrue);
    });

    test('should preserve ProofMode data through draft copyWith', () async {
      final testFile = File('test_video.mp4');
      const proofJson = '{"segments":[],"deviceAttestation":null}';

      final originalDraft = DivineVideoDraft.create(
        clips: [
          DivineVideoClip(
            id: 'test_clip',
            video: EditorVideo.file(testFile.path),
            duration: const Duration(seconds: 6),
            recordedAt: DateTime.now(),
            targetAspectRatio: AspectRatio.square,
            originalAspectRatio: 9 / 16,
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
        videoDuration: const Duration(seconds: 5),
      );

      expect(upload.title, equals('Updated Title'));
      expect(upload.proofManifestJson, equals(proofJson));
    });

    test('prefers final rendered clip when draft already has one', () async {
      final tempDir = await Directory.systemTemp.createTemp('upload_draft_');
      final renderedFile = File('${tempDir.path}/final_rendered.mp4')
        ..writeAsBytesSync([0, 1, 2, 3]);

      when(() => mockBlossomService.isBlossomEnabled()).thenAnswer(
        (_) async => false,
      );
      when(
        () => mockBlossomService.uploadVideo(
          videoFile: any(named: 'videoFile'),
          nostrPubkey: any(named: 'nostrPubkey'),
          title: any(named: 'title'),
          description: any(named: 'description'),
          hashtags: any(named: 'hashtags'),
          proofManifestJson: any(named: 'proofManifestJson'),
          resumableSession: any(named: 'resumableSession'),
          onResumableSessionUpdated: any(named: 'onResumableSessionUpdated'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer(
        (_) async => const BlossomUploadResult(
          success: true,
          videoId: 'rendered-video',
        ),
      );

      final draft = DivineVideoDraft.create(
        clips: [
          DivineVideoClip(
            id: 'source_clip_1',
            video: EditorVideo.file('source_clip_1.mp4'),
            duration: const Duration(seconds: 3),
            recordedAt: DateTime.now(),
            targetAspectRatio: AspectRatio.square,
            originalAspectRatio: 9 / 16,
          ),
          DivineVideoClip(
            id: 'source_clip_2',
            video: EditorVideo.file('source_clip_2.mp4'),
            duration: const Duration(seconds: 3),
            recordedAt: DateTime.now(),
            targetAspectRatio: AspectRatio.square,
            originalAspectRatio: 9 / 16,
          ),
        ],
        title: 'Rendered Video',
        description: 'Uses final render',
        hashtags: {'rendered'},
        selectedApproach: 'native',
        finalRenderedClip: DivineVideoClip(
          id: 'rendered_clip',
          video: EditorVideo.file(renderedFile.path),
          duration: const Duration(seconds: 6),
          recordedAt: DateTime.now(),
          targetAspectRatio: AspectRatio.square,
          originalAspectRatio: 9 / 16,
        ),
      );

      final upload = await uploadManager.startUploadFromDraft(
        draft: draft,
        nostrPubkey: 'test-pubkey',
        videoDuration: const Duration(seconds: 6),
      );

      expect(upload.localVideoPath, equals(renderedFile.path));

      await tempDir.delete(recursive: true);
    });

    test('should handle draft without ProofMode data', () async {
      final testFile = File('test_video.mp4');

      final draft = DivineVideoDraft.create(
        clips: [
          DivineVideoClip(
            id: 'test_clip',
            video: EditorVideo.file(testFile.path),
            duration: const Duration(seconds: 6),
            recordedAt: DateTime.now(),
            targetAspectRatio: AspectRatio.square,
            originalAspectRatio: 9 / 16,
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
        videoDuration: const Duration(seconds: 5),
      );

      expect(upload.title, equals('Test Video'));
      expect(upload.hasProofMode, isFalse);
      expect(upload.proofManifestJson, isNull);
    });
  });
}
