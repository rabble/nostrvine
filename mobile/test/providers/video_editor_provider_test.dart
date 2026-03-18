// ABOUTME: Unit tests for EditorProvider (Riverpod) validating state mutations and provider behavior
// ABOUTME: Tests all EditorNotifier methods and state transitions using ProviderContainer

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
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
          state.isProcessing,
          false,
          reason: 'isProcessing should default to false',
        );
        expect(
          state.originalAudioVolume,
          1.0,
          reason: 'originalAudioVolume should default to 1.0',
        );
        expect(
          state.customAudioVolume,
          1.0,
          reason: 'customAudioVolume should default to 1.0',
        );
        expect(
          state.isSavingDraft,
          false,
          reason: 'isSavingDraft should default to false',
        );
        expect(
          state.allowAudioReuse,
          false,
          reason: 'allowAudioReuse should default to false',
        );
        expect(state.title, isEmpty, reason: 'title should default to empty');
        expect(
          state.description,
          isEmpty,
          reason: 'description should default to empty',
        );
        expect(state.tags, isEmpty, reason: 'tags should default to empty');
        expect(
          state.metadataLimitReached,
          false,
          reason: 'metadataLimitReached should default to false',
        );
        expect(
          state.finalRenderedClip,
          isNull,
          reason: 'finalRenderedClip should default to null',
        );
      });
    });

    group('reset', () {
      test('should reset all state to defaults', () {
        // Modify some provider-owned state
        container
            .read(videoEditorProvider.notifier)
            .updateMetadata(
              title: 'Test Title',
            );

        // Verify state changed
        var state = container.read(videoEditorProvider);
        expect(state.title, 'Test Title');

        // Reset
        container.read(videoEditorProvider.notifier).reset();
        state = container.read(videoEditorProvider);

        expect(state.title, isEmpty, reason: 'title should reset to empty');
        expect(
          state.isProcessing,
          false,
          reason: 'isProcessing should reset to false',
        );
        expect(
          state.metadataLimitReached,
          false,
          reason: 'metadataLimitReached should reset to false',
        );
      });
    });

    group('updateMetadata hashtag extraction', () {
      test('extracts hashtag when # is typed before existing word', () {
        final notifier = container.read(videoEditorProvider.notifier);

        // First type "hello"
        notifier.updateMetadata(description: 'hello');
        expect(container.read(videoEditorProvider).tags, isEmpty);

        // Then insert # before "hello" to make "#hello"
        notifier.updateMetadata(description: '#hello');
        expect(container.read(videoEditorProvider).tags, contains('hello'));
      });

      test('extracts hashtag at end of description', () {
        final notifier = container.read(videoEditorProvider.notifier);

        notifier.updateMetadata(description: 'check out #flutter');
        expect(container.read(videoEditorProvider).tags, contains('flutter'));
      });

      test('extracts hashtag in middle of description', () {
        final notifier = container.read(videoEditorProvider.notifier);

        notifier.updateMetadata(description: 'check #dart today');
        expect(container.read(videoEditorProvider).tags, contains('dart'));
      });

      test('removes tag when # is deleted from description', () {
        final notifier = container.read(videoEditorProvider.notifier);

        notifier.updateMetadata(description: 'hello #world');
        expect(container.read(videoEditorProvider).tags, contains('world'));

        notifier.updateMetadata(description: 'hello world');
        expect(
          container.read(videoEditorProvider).tags,
          isNot(contains('world')),
        );
      });

      test('preserves manually added tags when description changes', () {
        final notifier = container.read(videoEditorProvider.notifier);

        // Manually add a tag
        notifier.updateMetadata(tags: {'manual'});
        expect(container.read(videoEditorProvider).tags, contains('manual'));

        // Change description - manual tag should persist
        notifier.updateMetadata(description: 'some text');
        expect(container.read(videoEditorProvider).tags, contains('manual'));
      });

      test('extracts hashtag from title field', () {
        final notifier = container.read(videoEditorProvider.notifier);

        notifier.updateMetadata(title: 'My #video title');
        expect(container.read(videoEditorProvider).tags, contains('video'));
      });
    });

    group('setDraftId', () {
      test('should set the draft ID', () {
        const id = 'test-draft-id';
        container.read(videoEditorProvider.notifier).setDraftId(id);

        expect(id, container.read(videoEditorProvider.notifier).draftId);
      });
    });

    group('setOriginalAudioVolume', () {
      test('updates originalAudioVolume in state', () {
        container
            .read(videoEditorProvider.notifier)
            .setOriginalAudioVolume(0.5);

        expect(
          container.read(videoEditorProvider).originalAudioVolume,
          equals(0.5),
        );
      });

      test('clamps value to 0.0 minimum', () {
        container
            .read(videoEditorProvider.notifier)
            .setOriginalAudioVolume(-0.5);

        expect(
          container.read(videoEditorProvider).originalAudioVolume,
          equals(0.0),
        );
      });

      test('clamps value to 1.0 maximum', () {
        container
            .read(videoEditorProvider.notifier)
            .setOriginalAudioVolume(1.5);

        expect(
          container.read(videoEditorProvider).originalAudioVolume,
          equals(1.0),
        );
      });
    });

    group('setCustomAudioVolume', () {
      test('updates customAudioVolume in state', () {
        container.read(videoEditorProvider.notifier).setCustomAudioVolume(0.3);

        expect(
          container.read(videoEditorProvider).customAudioVolume,
          equals(0.3),
        );
      });

      test('clamps value to 0.0 minimum', () {
        container.read(videoEditorProvider.notifier).setCustomAudioVolume(-1);

        expect(
          container.read(videoEditorProvider).customAudioVolume,
          equals(0.0),
        );
      });

      test('clamps value to 1.0 maximum', () {
        container.read(videoEditorProvider.notifier).setCustomAudioVolume(2);

        expect(
          container.read(videoEditorProvider).customAudioVolume,
          equals(1.0),
        );
      });
    });

    group('previewOriginalAudioVolume', () {
      test('updates originalAudioVolume in state', () {
        container
            .read(videoEditorProvider.notifier)
            .previewOriginalAudioVolume(0.7);

        expect(
          container.read(videoEditorProvider).originalAudioVolume,
          equals(0.7),
        );
      });

      test('clamps value to valid range', () {
        container
            .read(videoEditorProvider.notifier)
            .previewOriginalAudioVolume(5);

        expect(
          container.read(videoEditorProvider).originalAudioVolume,
          equals(1.0),
        );
      });

      test('is no-op when value unchanged', () {
        final stateBefore = container.read(videoEditorProvider);

        container
            .read(videoEditorProvider.notifier)
            .previewOriginalAudioVolume(1);

        expect(
          identical(container.read(videoEditorProvider), stateBefore),
          isTrue,
        );
      });
    });

    group('previewCustomAudioVolume', () {
      test('updates customAudioVolume in state', () {
        container
            .read(videoEditorProvider.notifier)
            .previewCustomAudioVolume(0.4);

        expect(
          container.read(videoEditorProvider).customAudioVolume,
          equals(0.4),
        );
      });

      test('clamps value to valid range', () {
        container
            .read(videoEditorProvider.notifier)
            .previewCustomAudioVolume(-0.2);

        expect(
          container.read(videoEditorProvider).customAudioVolume,
          equals(0.0),
        );
      });

      test('is no-op when value unchanged', () {
        final stateBefore = container.read(videoEditorProvider);

        container
            .read(videoEditorProvider.notifier)
            .previewCustomAudioVolume(1);

        expect(
          identical(container.read(videoEditorProvider), stateBefore),
          isTrue,
        );
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
    group('isValidToPost', () {
      test('returns false when finalRenderedClip is null', () {
        final state = VideoEditorProviderState();

        expect(state.finalRenderedClip, isNull);
        expect(state.isValidToPost, isFalse);
      });

      test('returns true when finalRenderedClip is set and not processing', () {
        final state = VideoEditorProviderState(
          finalRenderedClip: DivineVideoClip(
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
          finalRenderedClip: DivineVideoClip(
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
          finalRenderedClip: DivineVideoClip(
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
        isProcessing: true,
        isSavingDraft: true,
        allowAudioReuse: true,
        title: 'Test',
        description: 'Desc',
        tags: const {'tag1'},
        metadataLimitReached: true,
      );

      final copied = original.copyWith();

      expect(copied.isProcessing, true);
      expect(copied.isSavingDraft, true);
      expect(copied.allowAudioReuse, true);
      expect(copied.title, 'Test');
      expect(copied.description, 'Desc');
      expect(copied.tags, equals({'tag1'}));
      expect(copied.metadataLimitReached, true);
    });

    test('copyWith should update only specified values', () {
      final original = VideoEditorProviderState(
        isProcessing: true,
        title: 'Original',
      );

      final copied = original.copyWith(
        isProcessing: false,
        title: 'Updated',
      );

      expect(copied.isProcessing, false);
      expect(copied.title, 'Updated');
    });

    group('isValidToPost', () {
      test('returns false when finalRenderedClip is null', () {
        final state = VideoEditorProviderState();

        expect(state.finalRenderedClip, isNull);
        expect(state.isValidToPost, isFalse);
      });

      test('returns true when finalRenderedClip is set and not processing', () {
        final state = VideoEditorProviderState(
          finalRenderedClip: DivineVideoClip(
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
          finalRenderedClip: DivineVideoClip(
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
          finalRenderedClip: DivineVideoClip(
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
