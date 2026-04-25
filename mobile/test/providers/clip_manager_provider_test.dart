// ABOUTME: Tests for ClipManagerProvider - Riverpod state management
// ABOUTME: Validates state updates and provider lifecycle

@Tags(['skip_very_good_optimization'])
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockDraftStorageService extends Mock implements DraftStorageService {}

class _MockClipLibraryService extends Mock implements ClipLibraryService {}

void main() {
  group('ClipManagerProvider', () {
    late ProviderContainer container;
    late _MockDraftStorageService mockDraftStorageService;
    late _MockClipLibraryService mockClipLibraryService;

    setUp(() {
      mockDraftStorageService = _MockDraftStorageService();
      mockClipLibraryService = _MockClipLibraryService();
      when(
        () => mockDraftStorageService.deleteDraft(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockClipLibraryService.deleteClip(any()),
      ).thenAnswer((_) async {});
      container = ProviderContainer(
        overrides: [
          draftStorageServiceProvider.overrideWithValue(
            mockDraftStorageService,
          ),
          clipLibraryServiceProvider.overrideWithValue(mockClipLibraryService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state has no clips', () {
      final state = container.read(clipManagerProvider);

      expect(state.clips, isEmpty);
      expect(state.hasClips, isFalse);
    });

    test('addClip updates state with new clip', () {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.addClip(
        limitClipDuration: false,
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 2),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      final state = container.read(clipManagerProvider);
      expect(state.clips.length, equals(1));
      expect(state.totalDuration, equals(const Duration(seconds: 2)));
    });

    test('deleteClip removes clip from state', () async {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.addClip(
        limitClipDuration: false,
        video: EditorVideo.file('/path/to/video1.mp4'),
        duration: const Duration(seconds: 2),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );
      notifier.addClip(
        limitClipDuration: false,
        video: EditorVideo.file('/path/to/video2.mp4'),
        duration: const Duration(seconds: 1),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      final clipId = container.read(clipManagerProvider).clips[0].id;
      await notifier.removeClipById(clipId);

      final state = container.read(clipManagerProvider);
      expect(state.clips.length, equals(1));
    });

    test('selectClip updates selected clip state', () {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.addClip(
        limitClipDuration: false,
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 2),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );
      final clipId = container.read(clipManagerProvider).clips[0].id;
      notifier.selectClip(clipId);

      final state = container.read(clipManagerProvider);
      expect(state.selectedClipId, equals(clipId));
    });

    test('updateThumbnail updates clip thumbnail', () {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.addClip(
        limitClipDuration: false,
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 2),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );
      final clipId = container.read(clipManagerProvider).clips[0].id;
      notifier.updateThumbnail(
        clipId: clipId,
        thumbnailPath: '/path/to/thumb.jpg',
        thumbnailTimestamp: const Duration(milliseconds: 210),
      );

      final state = container.read(clipManagerProvider);
      expect(state.clips[0].thumbnailPath, equals('/path/to/thumb.jpg'));
      expect(
        state.clips[0].thumbnailTimestamp,
        equals(const Duration(milliseconds: 210)),
      );
    });

    test('updateClipDuration updates clip duration', () {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.addClip(
        limitClipDuration: false,
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 2),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );
      final clipId = container.read(clipManagerProvider).clips[0].id;
      notifier.updateClipDuration(clipId, const Duration(seconds: 3));

      final state = container.read(clipManagerProvider);
      expect(state.clips[0].duration, equals(const Duration(seconds: 3)));
      expect(state.totalDuration, equals(const Duration(seconds: 3)));
    });

    test('deleteLastClip deletes last clip', () async {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.addClip(
        limitClipDuration: false,
        video: EditorVideo.file('/path/to/video1.mp4'),
        duration: const Duration(seconds: 1),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );
      notifier.addClip(
        limitClipDuration: false,
        video: EditorVideo.file('/path/to/video2.mp4'),
        duration: const Duration(seconds: 2),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      expect(container.read(clipManagerProvider).clips.length, equals(2));

      await notifier.deleteLastRecordedClip();

      final state = container.read(clipManagerProvider);
      expect(state.clips.length, equals(1));
    });

    test('clearAll removes all clips and resets state', () async {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.addClip(
        limitClipDuration: false,
        video: EditorVideo.file('/path/to/video1.mp4'),
        duration: const Duration(seconds: 1),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );
      notifier.addClip(
        limitClipDuration: false,
        video: EditorVideo.file('/path/to/video2.mp4'),
        duration: const Duration(seconds: 2),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      await notifier.clearAll();

      final state = container.read(clipManagerProvider);
      expect(state.clips, isEmpty);
      expect(state.hasClips, isFalse);
      expect(state.totalDuration, equals(Duration.zero));
      expect(state.errorMessage, isNull);
      expect(state.isProcessing, isFalse);
    });

    test('canRecordMore is true when under limit', () {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.addClip(
        limitClipDuration: false,
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 2),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      final state = container.read(clipManagerProvider);
      expect(state.canRecordMore, isTrue);
    });

    test('canRecordMore is false when at limit', () {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.addClip(
        limitClipDuration: false,
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: VideoEditorConstants.maxDuration,
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      final state = container.read(clipManagerProvider);
      expect(state.canRecordMore, isFalse);
    });

    test('addClip allows adding duplicate clips with same id', () {
      final notifier = container.read(clipManagerProvider.notifier);

      // Simulate adding the same clip multiple times (like from library selection)
      const sharedFilePath = '/path/to/library/clip.mp4';
      const clipDuration = Duration(seconds: 2);

      final clip1 = notifier.addClip(
        limitClipDuration: false,
        video: EditorVideo.file(sharedFilePath),
        duration: clipDuration,
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
        thumbnailPath: '/path/to/thumb.jpg',
      );

      final clip2 = notifier.addClip(
        limitClipDuration: false,
        video: EditorVideo.file(sharedFilePath),
        duration: clipDuration,
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
        thumbnailPath: '/path/to/thumb.jpg',
      );

      final clip3 = notifier.addClip(
        limitClipDuration: false,
        video: EditorVideo.file(sharedFilePath),
        duration: clipDuration,
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
        thumbnailPath: '/path/to/thumb.jpg',
      );

      final state = container.read(clipManagerProvider);

      // All three clips should be added
      expect(state.clips.length, equals(3));

      // Each clip should have a unique ID
      expect(clip1.id, isNot(equals(clip2.id)));
      expect(clip2.id, isNot(equals(clip3.id)));
      expect(clip1.id, isNot(equals(clip3.id)));

      // Total duration should account for all clips
      expect(state.totalDuration, equals(const Duration(seconds: 6)));
    });

    group('clearClips', () {
      test('should remove all clips without affecting files', () {
        final notifier = container.read(clipManagerProvider.notifier);

        notifier.addClip(
          limitClipDuration: false,
          video: EditorVideo.file('/path/to/video1.mp4'),
          duration: const Duration(seconds: 2),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );
        notifier.addClip(
          limitClipDuration: false,
          video: EditorVideo.file('/path/to/video2.mp4'),
          duration: const Duration(seconds: 3),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );

        expect(container.read(clipManagerProvider).clips.length, equals(2));

        notifier.clearClips();

        final state = container.read(clipManagerProvider);
        expect(state.clips, isEmpty);
        expect(state.hasClips, isFalse);
      });

      test(
        'clearClips before addMultipleClips prevents clip duplication (draft restore)',
        () {
          final notifier = container.read(clipManagerProvider.notifier);

          // Simulate initial clips already in manager
          notifier.addClip(
            limitClipDuration: false,
            video: EditorVideo.file('/path/to/existing1.mp4'),
            duration: const Duration(seconds: 2),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          );
          notifier.addClip(
            limitClipDuration: false,
            video: EditorVideo.file('/path/to/existing2.mp4'),
            duration: const Duration(seconds: 3),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          );

          expect(container.read(clipManagerProvider).clips.length, equals(2));

          // Simulate draft restoration pattern:
          // 1. Clear existing clips first
          notifier.clearClips();

          // 2. Add clips from draft
          final draftClip1 = notifier.addClip(
            limitClipDuration: false,
            video: EditorVideo.file('/path/to/draft1.mp4'),
            duration: const Duration(seconds: 1),
            targetAspectRatio: .square,
            originalAspectRatio: 1,
          );
          final draftClip2 = notifier.addClip(
            limitClipDuration: false,
            video: EditorVideo.file('/path/to/draft2.mp4'),
            duration: const Duration(seconds: 2),
            targetAspectRatio: .square,
            originalAspectRatio: 1,
          );

          final state = container.read(clipManagerProvider);

          // Should only have the 2 draft clips, not 4 (2 existing + 2 draft)
          expect(
            state.clips.length,
            equals(2),
            reason: 'Draft restore should replace clips, not append to them',
          );

          // Verify they are the correct clips
          expect(state.clips[0].id, equals(draftClip1.id));
          expect(state.clips[1].id, equals(draftClip2.id));
          expect(state.totalDuration, equals(const Duration(seconds: 3)));
        },
      );

      test('addMultipleClips without clearClips causes duplication', () {
        final notifier = container.read(clipManagerProvider.notifier);

        // Add initial clips
        notifier.addClip(
          limitClipDuration: false,
          video: EditorVideo.file('/path/to/existing.mp4'),
          duration: const Duration(seconds: 2),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );

        expect(container.read(clipManagerProvider).clips.length, equals(1));

        // Create clips to add (simulating draft clips)
        notifier.addClip(
          limitClipDuration: false,
          video: EditorVideo.file('/path/to/draft.mp4'),
          duration: const Duration(seconds: 1),
          targetAspectRatio: .square,
          originalAspectRatio: 1,
        );

        // Without clearClips, we now have 2 clips
        final state = container.read(clipManagerProvider);
        expect(
          state.clips.length,
          equals(2),
          reason: 'Without clearClips, clips are appended',
        );
      });

      test(
        'replaceClips swaps clips atomically without empty intermediate state',
        () {
          final notifier = container.read(clipManagerProvider.notifier);

          notifier.addClip(
            video: EditorVideo.file('/path/to/existing.mp4'),
            duration: const Duration(seconds: 2),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
            limitClipDuration: false,
          );

          final replacementClip = DivineVideoClip(
            id: 'replacement-clip',
            video: EditorVideo.file('/path/to/replacement.mp4'),
            duration: const Duration(seconds: 3),
            recordedAt: DateTime.now(),
            targetAspectRatio: .square,
            originalAspectRatio: 1,
          );

          notifier.replaceClips([replacementClip]);

          final state = container.read(clipManagerProvider);
          expect(state.clips, hasLength(1));
          expect(state.clips.single.id, equals('replacement-clip'));
          expect(state.firstClipOrNull, equals(replacementClip));
        },
      );
    });

    group('addClip proof generation', () {
      test('newly added clip has no proofManifestJson initially', () {
        final notifier = container.read(clipManagerProvider.notifier);

        final clip = notifier.addClip(
          limitClipDuration: false,
          video: EditorVideo.file('/path/to/video.mp4'),
          duration: const Duration(seconds: 2),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );

        expect(clip.proofManifestJson, isNull);
      });

      test('clip without trimming has no processingCompleter', () {
        final notifier = container.read(clipManagerProvider.notifier);

        final clip = notifier.addClip(
          limitClipDuration: false,
          video: EditorVideo.file('/path/to/video.mp4'),
          duration: const Duration(seconds: 2),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );

        expect(clip.processingCompleter, isNull);
        expect(clip.isProcessing, isFalse);
      });

      test('multiple clips each have independent proof state', () {
        final notifier = container.read(clipManagerProvider.notifier);

        final clip1 = notifier.addClip(
          limitClipDuration: false,
          video: EditorVideo.file('/path/to/video1.mp4'),
          duration: const Duration(seconds: 2),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );
        final clip2 = notifier.addClip(
          limitClipDuration: false,
          video: EditorVideo.file('/path/to/video2.mp4'),
          duration: const Duration(seconds: 3),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );

        // Both start without proof
        expect(clip1.proofManifestJson, isNull);
        expect(clip2.proofManifestJson, isNull);

        // Each clip has a unique ID
        expect(clip1.id, isNot(equals(clip2.id)));
      });

      test('refreshClip updates proofManifestJson on existing clip', () {
        final notifier = container.read(clipManagerProvider.notifier);

        final clip = notifier.addClip(
          limitClipDuration: false,
          video: EditorVideo.file('/path/to/video.mp4'),
          duration: const Duration(seconds: 2),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );

        expect(clip.proofManifestJson, isNull);

        // Simulate what _generateClipProof does after proof generation
        notifier.refreshClip(
          clip.copyWith(proofManifestJson: '{"hash":"abc123"}'),
        );

        final state = container.read(clipManagerProvider);
        final updatedClip = state.clips.first;
        expect(updatedClip.proofManifestJson, equals('{"hash":"abc123"}'));
      });

      test('refreshClip preserves thumbnail when updating proof', () {
        final notifier = container.read(clipManagerProvider.notifier);

        final clip = notifier.addClip(
          limitClipDuration: false,
          video: EditorVideo.file('/path/to/video.mp4'),
          duration: const Duration(seconds: 2),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
          thumbnailPath: '/path/to/thumb.jpg',
        );

        // Update thumbnail first
        notifier.updateThumbnail(
          clipId: clip.id,
          thumbnailPath: '/path/to/updated_thumb.jpg',
          thumbnailTimestamp: const Duration(milliseconds: 500),
        );

        // Then update proof (simulating _generateClipProof)
        final currentClip = notifier.getClipById(clip.id)!;
        notifier.refreshClip(
          currentClip.copyWith(proofManifestJson: '{"hash":"abc123"}'),
        );

        final state = container.read(clipManagerProvider);
        final updatedClip = state.clips.first;
        expect(updatedClip.proofManifestJson, equals('{"hash":"abc123"}'));
        expect(updatedClip.thumbnailPath, equals('/path/to/updated_thumb.jpg'));
      });

      test('proof state survives clip reordering', () {
        final notifier = container.read(clipManagerProvider.notifier);

        final clip1 = notifier.addClip(
          limitClipDuration: false,
          video: EditorVideo.file('/path/to/video1.mp4'),
          duration: const Duration(seconds: 1),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );
        notifier.addClip(
          limitClipDuration: false,
          video: EditorVideo.file('/path/to/video2.mp4'),
          duration: const Duration(seconds: 2),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );

        // Add proof to first clip
        notifier.refreshClip(
          clip1.copyWith(proofManifestJson: '{"hash":"proof1"}'),
        );

        // Verify proof is on first clip
        final state = container.read(clipManagerProvider);
        final proofClip = state.clips.firstWhere(
          (c) => c.proofManifestJson != null,
        );
        expect(proofClip.proofManifestJson, equals('{"hash":"proof1"}'));
      });

      test('clearAll removes clips including their proof data', () async {
        final notifier = container.read(clipManagerProvider.notifier);

        final clip = notifier.addClip(
          limitClipDuration: false,
          video: EditorVideo.file('/path/to/video.mp4'),
          duration: const Duration(seconds: 2),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );

        // Simulate proof generation
        notifier.refreshClip(
          clip.copyWith(proofManifestJson: '{"hash":"abc123"}'),
        );

        // Verify proof exists
        expect(
          container.read(clipManagerProvider).clips.first.proofManifestJson,
          isNotNull,
        );

        await notifier.clearAll();

        final state = container.read(clipManagerProvider);
        expect(state.clips, isEmpty);
      });

      test('getClipById returns clip with current proof state', () {
        final notifier = container.read(clipManagerProvider.notifier);

        final clip = notifier.addClip(
          limitClipDuration: false,
          video: EditorVideo.file('/path/to/video.mp4'),
          duration: const Duration(seconds: 2),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );

        // Initially no proof
        expect(notifier.getClipById(clip.id)?.proofManifestJson, isNull);

        // Add proof
        notifier.refreshClip(
          clip.copyWith(proofManifestJson: '{"hash":"abc123"}'),
        );

        // getClipById returns updated state
        final updated = notifier.getClipById(clip.id);
        expect(updated?.proofManifestJson, equals('{"hash":"abc123"}'));
      });

      test('getClipById returns null for deleted clip', () async {
        final notifier = container.read(clipManagerProvider.notifier);

        final clip = notifier.addClip(
          limitClipDuration: false,
          video: EditorVideo.file('/path/to/video.mp4'),
          duration: const Duration(seconds: 2),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );

        expect(notifier.getClipById(clip.id), isNotNull);

        await notifier.removeClipById(clip.id);

        expect(notifier.getClipById(clip.id), isNull);
      });

      test('refreshClip is no-op for deleted clip '
          '(simulates proof arriving after deletion)', () async {
        final notifier = container.read(clipManagerProvider.notifier);

        final clip = notifier.addClip(
          limitClipDuration: false,
          video: EditorVideo.file('/path/to/video.mp4'),
          duration: const Duration(seconds: 2),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );

        // Delete the clip
        await notifier.removeClipById(clip.id);
        expect(container.read(clipManagerProvider).clips, isEmpty);

        // Simulate late proof arrival — refreshClip should not re-add the clip
        notifier.refreshClip(
          clip.copyWith(proofManifestJson: '{"hash":"late_proof"}'),
        );

        final state = container.read(clipManagerProvider);
        expect(
          state.clips,
          isEmpty,
          reason: 'Deleted clip should not reappear from late proof update',
        );
      });
    });

    group('updateGhostFrame', () {
      test('updates ghost frame path for existing clip', () {
        final notifier = container.read(clipManagerProvider.notifier);

        notifier.addClip(
          limitClipDuration: false,
          video: EditorVideo.file('/path/to/video.mp4'),
          duration: const Duration(seconds: 2),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );
        final clipId = container.read(clipManagerProvider).clips[0].id;

        notifier.updateGhostFrame(
          clipId: clipId,
          ghostFramePath: '/path/to/ghost.jpg',
        );

        final state = container.read(clipManagerProvider);
        expect(state.clips[0].ghostFramePath, equals('/path/to/ghost.jpg'));
      });

      test('does not throw for non-existent clip', () {
        final notifier = container.read(clipManagerProvider.notifier);

        // Should log a warning but not throw
        notifier.updateGhostFrame(
          clipId: 'non_existent',
          ghostFramePath: '/path/to/ghost.jpg',
        );

        final state = container.read(clipManagerProvider);
        expect(state.clips, isEmpty);
      });

      test('preserves other clip fields when updating ghost frame', () {
        final notifier = container.read(clipManagerProvider.notifier);

        notifier.addClip(
          limitClipDuration: false,
          video: EditorVideo.file('/path/to/video.mp4'),
          duration: const Duration(seconds: 2),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
          thumbnailPath: '/path/to/thumb.jpg',
        );
        final clipId = container.read(clipManagerProvider).clips[0].id;

        notifier.updateGhostFrame(
          clipId: clipId,
          ghostFramePath: '/path/to/ghost.jpg',
        );

        final clip = container.read(clipManagerProvider).clips[0];
        expect(clip.thumbnailPath, equals('/path/to/thumb.jpg'));
        expect(clip.duration, equals(const Duration(seconds: 2)));
        expect(clip.ghostFramePath, equals('/path/to/ghost.jpg'));
      });
    });
  });
}
