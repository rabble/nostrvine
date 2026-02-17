// ABOUTME: Unit tests for EditorProvider (Riverpod) validating state mutations and provider behavior
// ABOUTME: Tests all EditorNotifier methods and state transitions using ProviderContainer

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group('VideoEditorProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    group('initial state', () {
      test('should have default values', () {
        final state = container.read(videoEditorProvider);

        expect(
          state.currentClipIndex,
          0,
          reason: 'currentClipIndex should default to 0',
        );
        expect(
          state.currentPosition,
          Duration.zero,
          reason: 'currentPosition should default to zero',
        );
        expect(
          state.splitPosition,
          Duration.zero,
          reason: 'splitPosition should default to zero',
        );
        expect(
          state.isEditing,
          false,
          reason: 'isEditing should default to false',
        );
        expect(
          state.isReordering,
          false,
          reason: 'isReordering should default to false',
        );
        expect(
          state.isOverDeleteZone,
          false,
          reason: 'isOverDeleteZone should default to false',
        );
        expect(
          state.isPlaying,
          false,
          reason: 'isPlaying should default to false',
        );
        expect(state.isMuted, false, reason: 'isMuted should default to false');
        expect(
          state.isProcessing,
          false,
          reason: 'isProcessing should default to false',
        );
      });
    });

    group('selectClip', () {
      test('should update currentClipIndex', () {
        // Add clips first
        container
            .read(clipManagerProvider.notifier)
            .addClip(
              video: EditorVideo.file('/test/clip1.mp4'),
              targetAspectRatio: .square,
              originalAspectRatio: 9 / 16,
              duration: const Duration(seconds: 2),
            );
        container
            .read(clipManagerProvider.notifier)
            .addClip(
              video: EditorVideo.file('/test/clip2.mp4'),
              targetAspectRatio: .square,
              originalAspectRatio: 9 / 16,
              duration: const Duration(seconds: 2),
            );

        container.read(videoEditorProvider.notifier).selectClipByIndex(1);
        final state = container.read(videoEditorProvider);

        expect(state.currentClipIndex, 1);
        expect(state.isPlaying, false);
      });

      test('should calculate currentPosition from previous clips', () {
        // Add clips with known durations
        container
            .read(clipManagerProvider.notifier)
            .addClip(
              video: EditorVideo.file('/test/clip1.mp4'),
              targetAspectRatio: .square,
              originalAspectRatio: 9 / 16,
              duration: const Duration(seconds: 2),
            );
        container
            .read(clipManagerProvider.notifier)
            .addClip(
              video: EditorVideo.file('/test/clip2.mp4'),
              targetAspectRatio: .square,
              originalAspectRatio: 9 / 16,
              duration: const Duration(seconds: 3),
            );

        container.read(videoEditorProvider.notifier).selectClipByIndex(1);
        final state = container.read(videoEditorProvider);

        // Position should be sum of previous clips (2 seconds)
        expect(state.currentPosition, const Duration(seconds: 2));
      });

      test('should reset splitPosition to zero', () {
        container.read(videoEditorProvider.notifier).selectClipByIndex(0);
        final state = container.read(videoEditorProvider);

        expect(state.splitPosition, Duration.zero);
      });
    });

    group('clip reordering', () {
      test('startClipReordering should set isReordering to true', () {
        container.read(videoEditorProvider.notifier).startClipReordering();
        final state = container.read(videoEditorProvider);

        expect(state.isReordering, true);
      });

      test('stopClipReordering should set isReordering to false', () {
        container.read(videoEditorProvider.notifier).startClipReordering();
        container.read(videoEditorProvider.notifier).stopClipReordering();
        final state = container.read(videoEditorProvider);

        expect(state.isReordering, false);
        expect(state.isOverDeleteZone, false);
      });
    });

    group('clip editing', () {
      test('startClipEditing should set isEditing to true', () {
        // Add a clip first
        container
            .read(clipManagerProvider.notifier)
            .addClip(
              video: EditorVideo.file('/test/clip.mp4'),
              targetAspectRatio: .square,
              originalAspectRatio: 9 / 16,
              duration: const Duration(seconds: 4),
            );

        container.read(videoEditorProvider.notifier).startClipEditing();
        final state = container.read(videoEditorProvider);

        expect(state.isEditing, true);
        expect(state.isPlaying, false);
      });

      test(
        'startClipEditing should set splitPosition to half of clip duration',
        () {
          container
              .read(clipManagerProvider.notifier)
              .addClip(
                video: EditorVideo.file('/test/clip.mp4'),
                targetAspectRatio: .square,
                originalAspectRatio: 9 / 16,
                duration: const Duration(seconds: 4),
              );

          container.read(videoEditorProvider.notifier).startClipEditing();
          final state = container.read(videoEditorProvider);

          expect(state.splitPosition, const Duration(seconds: 2));
        },
      );

      test('stopClipEditing should set isEditing to false', () {
        container
            .read(clipManagerProvider.notifier)
            .addClip(
              video: EditorVideo.file('/test/clip.mp4'),
              targetAspectRatio: .square,
              originalAspectRatio: 9 / 16,
              duration: const Duration(seconds: 2),
            );

        container.read(videoEditorProvider.notifier).startClipEditing();
        container.read(videoEditorProvider.notifier).stopClipEditing();
        final state = container.read(videoEditorProvider);

        expect(state.isEditing, false);
        expect(state.isPlaying, false);
      });

      test('toggleClipEditing should toggle isEditing state', () {
        container
            .read(clipManagerProvider.notifier)
            .addClip(
              video: EditorVideo.file('/test/clip.mp4'),
              targetAspectRatio: .square,
              originalAspectRatio: 9 / 16,
              duration: const Duration(seconds: 2),
            );

        // First toggle: off -> on
        container.read(videoEditorProvider.notifier).toggleClipEditing();
        expect(container.read(videoEditorProvider).isEditing, true);

        // Second toggle: on -> off
        container.read(videoEditorProvider.notifier).toggleClipEditing();
        expect(container.read(videoEditorProvider).isEditing, false);
      });
    });

    group('playback control', () {
      test('pauseVideo should set isPlaying to false', () {
        container.read(videoEditorProvider.notifier).pauseVideo();
        final state = container.read(videoEditorProvider);

        expect(state.isPlaying, false);
      });

      test(
        'togglePlayPause should toggle isPlaying state when player ready',
        () {
          // Mark player as ready first
          container.read(videoEditorProvider.notifier).setPlayerReady(true);

          // First toggle: off -> on
          container.read(videoEditorProvider.notifier).togglePlayPause();
          expect(container.read(videoEditorProvider).isPlaying, true);

          // Second toggle: on -> off
          container.read(videoEditorProvider.notifier).togglePlayPause();
          expect(container.read(videoEditorProvider).isPlaying, false);
        },
      );

      test('togglePlayPause should not play when player not ready', () {
        // Player is not ready by default
        expect(container.read(videoEditorProvider).isPlayerReady, false);

        // Try to play - should be ignored
        container.read(videoEditorProvider.notifier).togglePlayPause();
        expect(container.read(videoEditorProvider).isPlaying, false);
      });

      test('setPlayerReady should update isPlayerReady state', () {
        container.read(videoEditorProvider.notifier).setPlayerReady(true);
        expect(container.read(videoEditorProvider).isPlayerReady, true);

        container.read(videoEditorProvider.notifier).setPlayerReady(false);
        expect(container.read(videoEditorProvider).isPlayerReady, false);
      });

      test('setHasPlayedOnce should set hasPlayedOnce to true', () {
        expect(container.read(videoEditorProvider).hasPlayedOnce, false);

        container.read(videoEditorProvider.notifier).setHasPlayedOnce();
        expect(container.read(videoEditorProvider).hasPlayedOnce, true);

        // Calling again should have no effect (already true)
        container.read(videoEditorProvider.notifier).setHasPlayedOnce();
        expect(container.read(videoEditorProvider).hasPlayedOnce, true);
      });
    });

    group('delete zone', () {
      test('setOverDeleteZone should update isOverDeleteZone', () {
        container.read(videoEditorProvider.notifier).setOverDeleteZone(true);
        expect(container.read(videoEditorProvider).isOverDeleteZone, true);

        container.read(videoEditorProvider.notifier).setOverDeleteZone(false);
        expect(container.read(videoEditorProvider).isOverDeleteZone, false);
      });
    });

    group('seek and trim', () {
      test('seekToTrimPosition should update splitPosition and pause', () {
        // Mark player as ready and start playback
        container.read(videoEditorProvider.notifier).setPlayerReady(true);
        container.read(videoEditorProvider.notifier).togglePlayPause();
        expect(container.read(videoEditorProvider).isPlaying, true);

        container
            .read(videoEditorProvider.notifier)
            .seekToTrimPosition(const Duration(milliseconds: 1500));
        final state = container.read(videoEditorProvider);

        expect(state.splitPosition, const Duration(milliseconds: 1500));
        expect(state.isPlaying, false);
      });
    });

    group('audio', () {
      test('toggleMute should toggle isMuted state', () {
        // First toggle: unmuted -> muted
        container.read(videoEditorProvider.notifier).toggleMute();
        expect(container.read(videoEditorProvider).isMuted, true);

        // Second toggle: muted -> unmuted
        container.read(videoEditorProvider.notifier).toggleMute();
        expect(container.read(videoEditorProvider).isMuted, false);
      });
    });

    group('reset', () {
      test('should reset all state to defaults', () {
        // Modify some state first
        container.read(videoEditorProvider.notifier)
          ..setPlayerReady(true)
          ..togglePlayPause()
          ..toggleMute();

        // Verify state changed
        var state = container.read(videoEditorProvider);
        expect(
          state.isPlaying,
          true,
          reason: 'isPlaying should be true after togglePlayPause',
        );
        expect(
          state.isMuted,
          true,
          reason: 'isMuted should be true after toggleMute',
        );

        // Reset
        container.read(videoEditorProvider.notifier).reset();
        state = container.read(videoEditorProvider);

        expect(
          state.currentClipIndex,
          0,
          reason: 'currentClipIndex should reset to 0',
        );
        expect(
          state.currentPosition,
          Duration.zero,
          reason: 'currentPosition should reset to zero',
        );
        expect(
          state.splitPosition,
          Duration.zero,
          reason: 'splitPosition should reset to zero',
        );
        expect(
          state.isEditing,
          false,
          reason: 'isEditing should reset to false',
        );
        expect(
          state.isReordering,
          false,
          reason: 'isReordering should reset to false',
        );
        expect(
          state.isPlaying,
          false,
          reason: 'isPlaying should reset to false',
        );
        expect(state.isMuted, false, reason: 'isMuted should reset to false');
        expect(
          state.isProcessing,
          false,
          reason: 'isProcessing should reset to false',
        );
      });
    });

    group('updatePosition', () {
      test('should update currentPosition clamped to max 6300ms', () {
        // Add a clip first so updatePosition works
        container
            .read(clipManagerProvider.notifier)
            .addClip(
              video: EditorVideo.file('/test/clip.mp4'),
              targetAspectRatio: .square,
              originalAspectRatio: 9 / 16,
              duration: const Duration(seconds: 5),
            );
        final clipId = container.read(clipManagerProvider).clips.first.id;

        container
            .read(videoEditorProvider.notifier)
            .updatePosition(clipId, const Duration(seconds: 3));
        final state = container.read(videoEditorProvider);

        expect(state.currentPosition, const Duration(seconds: 3));
      });

      test('should clamp position to max duration', () {
        // Add a clip first so updatePosition works
        container
            .read(clipManagerProvider.notifier)
            .addClip(
              video: EditorVideo.file('/test/clip.mp4'),
              targetAspectRatio: .square,
              originalAspectRatio: 9 / 16,
              duration: const Duration(seconds: 5),
            );
        final clipId = container.read(clipManagerProvider).clips.first.id;

        container
            .read(videoEditorProvider.notifier)
            .updatePosition(clipId, const Duration(seconds: 10));
        final state = container.read(videoEditorProvider);

        expect(state.currentPosition, VideoEditorConstants.maxDuration);
      });

      test('should clamp position to min 0', () {
        // Add a clip first so updatePosition works
        container
            .read(clipManagerProvider.notifier)
            .addClip(
              video: EditorVideo.file('/test/clip.mp4'),
              targetAspectRatio: .square,
              originalAspectRatio: 9 / 16,
              duration: const Duration(seconds: 5),
            );
        final clipId = container.read(clipManagerProvider).clips.first.id;

        container
            .read(videoEditorProvider.notifier)
            .updatePosition(clipId, const Duration(seconds: -5));
        final state = container.read(videoEditorProvider);

        expect(state.currentPosition, Duration.zero);
      });

      test('should ignore position updates from wrong clipId', () {
        // Add a clip first
        container
            .read(clipManagerProvider.notifier)
            .addClip(
              video: EditorVideo.file('/test/clip.mp4'),
              targetAspectRatio: .square,
              originalAspectRatio: 9 / 16,
              duration: const Duration(seconds: 5),
            );

        // Try to update with wrong clipId - should be ignored
        container
            .read(videoEditorProvider.notifier)
            .updatePosition('wrong-clip-id', const Duration(seconds: 3));
        final state = container.read(videoEditorProvider);

        // Position should remain at default (zero)
        expect(state.currentPosition, Duration.zero);
      });

      test('should add offset from previous clips when not editing', () {
        // Add clips with known durations
        container
            .read(clipManagerProvider.notifier)
            .addClip(
              video: EditorVideo.file('/test/clip1.mp4'),
              targetAspectRatio: .square,
              originalAspectRatio: 9 / 16,
              duration: const Duration(seconds: 2),
            );
        container
            .read(clipManagerProvider.notifier)
            .addClip(
              video: EditorVideo.file('/test/clip2.mp4'),
              targetAspectRatio: .square,
              originalAspectRatio: 9 / 16,
              duration: const Duration(seconds: 2),
            );
        final clip2Id = container.read(clipManagerProvider).clips[1].id;

        // Select second clip
        container.read(videoEditorProvider.notifier).selectClipByIndex(1);

        // Update position by 500ms within the clip
        container
            .read(videoEditorProvider.notifier)
            .updatePosition(clip2Id, const Duration(milliseconds: 500));

        final state = container.read(videoEditorProvider);
        // Should be 2000ms (offset) + 500ms (position) = 2500ms
        expect(state.currentPosition, const Duration(milliseconds: 2500));
      });

      test('should not add offset when editing', () {
        container
            .read(clipManagerProvider.notifier)
            .addClip(
              video: EditorVideo.file('/test/clip1.mp4'),
              targetAspectRatio: .square,
              originalAspectRatio: 9 / 16,
              duration: const Duration(seconds: 2),
            );
        container
            .read(clipManagerProvider.notifier)
            .addClip(
              video: EditorVideo.file('/test/clip2.mp4'),
              targetAspectRatio: .square,
              originalAspectRatio: 9 / 16,
              duration: const Duration(seconds: 2),
            );
        final clip2Id = container.read(clipManagerProvider).clips[1].id;

        // Select second clip and start editing
        container.read(videoEditorProvider.notifier)
          ..selectClipByIndex(1)
          ..startClipEditing();

        // Update position by 500ms within the clip
        container
            .read(videoEditorProvider.notifier)
            .updatePosition(clip2Id, const Duration(milliseconds: 500));

        final state = container.read(videoEditorProvider);
        // Should be just 500ms (no offset in editing mode)
        expect(state.currentPosition, const Duration(milliseconds: 500));
      });
    });

    group('setDraftId', () {
      test('should set the draft ID', () {
        final id = 'test-draft-id';
        container.read(videoEditorProvider.notifier).setDraftId(id);

        expect(id, container.read(videoEditorProvider.notifier).draftId);
      });
    });
  });

  group('getActiveDraft', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('should use _clips when finalRenderedClip is null', () {
      // Add clips to the clip manager
      container
          .read(clipManagerProvider.notifier)
          .addClip(
            video: EditorVideo.file('/docs/original.mp4'),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
            duration: const Duration(seconds: 2),
          );

      container.read(videoEditorProvider.notifier).setDraftId('test-draft');

      // finalRenderedClip is null by default, so getActiveDraft should
      // use _clips for both autosave and non-autosave
      final draft = container
          .read(videoEditorProvider.notifier)
          .getActiveDraft();

      expect(draft.clips, hasLength(1));
      expect(draft.id, equals('test-draft'));
    });

    test('autosave should always use _clips even if '
        'finalRenderedClip were set', () {
      // Add clips to the clip manager
      container
          .read(clipManagerProvider.notifier)
          .addClip(
            video: EditorVideo.file('/docs/original.mp4'),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
            duration: const Duration(seconds: 2),
          );

      // Autosave should use _clips
      final autosaveDraft = container
          .read(videoEditorProvider.notifier)
          .getActiveDraft(isAutosave: true);

      expect(autosaveDraft.clips, hasLength(1));
      expect(autosaveDraft.id, equals(VideoEditorConstants.autoSaveId));
    });
  });

  group('VideoEditorProviderState', () {
    test('copyWith should preserve unchanged values', () {
      final original = VideoEditorProviderState(
        currentClipIndex: 2,
        currentPosition: const Duration(seconds: 3),
        splitPosition: const Duration(seconds: 1),
        isEditing: true,
        isReordering: true,
        isOverDeleteZone: true,
        isPlaying: true,
        isMuted: true,
        isProcessing: true,
      );

      final copied = original.copyWith();

      expect(copied.currentClipIndex, 2);
      expect(copied.currentPosition, const Duration(seconds: 3));
      expect(copied.splitPosition, const Duration(seconds: 1));
      expect(copied.isEditing, true);
      expect(copied.isReordering, true);
      expect(copied.isOverDeleteZone, true);
      expect(copied.isPlaying, true);
      expect(copied.isMuted, true);
      expect(copied.isProcessing, true);
    });

    test('copyWith should update only specified values', () {
      final original = VideoEditorProviderState(
        currentClipIndex: 2,
        isEditing: true,
        isMuted: true,
      );

      final copied = original.copyWith(currentClipIndex: 5, isEditing: false);

      expect(copied.currentClipIndex, 5);
      expect(copied.isEditing, false);
      expect(copied.isMuted, true); // Unchanged
    });

    group('isValidToPost', () {
      test('returns false when finalRenderedClip is null', () {
        final state = VideoEditorProviderState();

        expect(state.finalRenderedClip, isNull);
        expect(state.isValidToPost, isFalse);
      });

      test('returns true when finalRenderedClip is set and not processing', () {
        final state = VideoEditorProviderState(
          finalRenderedClip: RecordingClip(
            id: 'rendered',
            video: EditorVideo.file('/docs/rendered.mp4'),
            duration: const Duration(seconds: 3),
            recordedAt: DateTime.now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          ),
        );

        expect(state.isValidToPost, isTrue);
      });

      test('returns false when metadataLimitReached even with clip', () {
        final state = VideoEditorProviderState(
          metadataLimitReached: true,
          finalRenderedClip: RecordingClip(
            id: 'rendered',
            video: EditorVideo.file('/docs/rendered.mp4'),
            duration: const Duration(seconds: 3),
            recordedAt: DateTime.now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          ),
        );

        expect(state.isValidToPost, isFalse);
      });

      test('returns false when isProcessing even with clip', () {
        final state = VideoEditorProviderState(
          isProcessing: true,
          finalRenderedClip: RecordingClip(
            id: 'rendered',
            video: EditorVideo.file('/docs/rendered.mp4'),
            duration: const Duration(seconds: 3),
            recordedAt: DateTime.now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          ),
        );

        expect(state.isValidToPost, isFalse);
      });
    });
  });
}
