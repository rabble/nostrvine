// ABOUTME: Unit tests for EditorProvider (Riverpod) validating state mutations and provider behavior
// ABOUTME: Tests all EditorNotifier methods and state transitions using ProviderContainer

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockDraftStorageService extends Mock implements DraftStorageService {}

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
          true,
          reason: 'allowAudioReuse should default to true',
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

    group('setProcessing', () {
      test('sets isProcessing to true', () {
        container.read(videoEditorProvider.notifier).setProcessing(true);

        expect(
          container.read(videoEditorProvider).isProcessing,
          isTrue,
        );
      });

      test('sets isProcessing to false', () {
        container.read(videoEditorProvider.notifier).setProcessing(true);
        container.read(videoEditorProvider.notifier).setProcessing(false);

        expect(
          container.read(videoEditorProvider).isProcessing,
          isFalse,
        );
      });

      test('is no-op when value unchanged', () {
        final stateBefore = container.read(videoEditorProvider);

        container.read(videoEditorProvider.notifier).setProcessing(false);

        expect(
          identical(container.read(videoEditorProvider), stateBefore),
          isTrue,
        );
      });
    });

    group('startRenderVideo', () {
      tearDown(() {
        VideoEditorRenderService.renderVideoToClipOverride = null;
      });

      test(
        'resets isProcessing to false when finalRenderedClip '
        'already exists',
        () async {
          final notifier = container.read(videoEditorProvider.notifier);

          // Simulate the UI calling setProcessing(true) before render
          notifier.setProcessing(true);
          expect(
            container.read(videoEditorProvider).isProcessing,
            isTrue,
            reason: 'isProcessing should be true before startRenderVideo',
          );

          // Set finalRenderedClip on the notifier state to simulate
          // a previously completed render
          notifier.state = notifier.state.copyWith(
            finalRenderedClip: DivineVideoClip(
              id: 'already-rendered',
              video: EditorVideo.file('/docs/rendered.mp4'),
              duration: const Duration(seconds: 5),
              recordedAt: DateTime.now(),
              targetAspectRatio: .vertical,
              originalAspectRatio: 9 / 16,
            ),
          );

          // Call startRenderVideo — should early-return and reset
          // isProcessing to false
          await notifier.startRenderVideo();

          expect(
            container.read(videoEditorProvider).isProcessing,
            isFalse,
            reason:
                'isProcessing should be false after early return '
                'when finalRenderedClip already exists',
          );
        },
      );

      test(
        'sets finalRenderedClip when render completes',
        () async {
          final notifier = container.read(videoEditorProvider.notifier);

          container
              .read(clipManagerProvider.notifier)
              .addClip(
                limitClipDuration: false,
                video: EditorVideo.file('/docs/clip.mp4'),
                targetAspectRatio: .vertical,
                originalAspectRatio: 9 / 16,
                duration: const Duration(seconds: 2),
              );

          final renderedClip = DivineVideoClip(
            id: 'rendered',
            video: EditorVideo.file('/docs/rendered.mp4'),
            duration: const Duration(seconds: 2),
            recordedAt: DateTime.now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          );

          VideoEditorRenderService.renderVideoToClipOverride =
              ({
                required clips,
                required editorStateHistory,
                originalAudioVolume = 1.0,
                customAudioVolume = 1.0,
                aiTrainingOptOut = true,
                parameters,
                taskId,
              }) async => (renderedClip, null);

          await notifier.startRenderVideo();

          final state = container.read(videoEditorProvider);
          expect(state.finalRenderedClip, equals(renderedClip));
          expect(state.isProcessing, isFalse);
        },
      );

      test(
        'sets isProcessing to false when render returns null',
        () async {
          final notifier = container.read(videoEditorProvider.notifier);

          container
              .read(clipManagerProvider.notifier)
              .addClip(
                limitClipDuration: false,
                video: EditorVideo.file('/docs/clip.mp4'),
                targetAspectRatio: .vertical,
                originalAspectRatio: 9 / 16,
                duration: const Duration(seconds: 2),
              );

          VideoEditorRenderService.renderVideoToClipOverride =
              ({
                required clips,
                required editorStateHistory,
                originalAudioVolume = 1.0,
                customAudioVolume = 1.0,
                aiTrainingOptOut = true,
                parameters,
                taskId,
              }) async => null;

          await notifier.startRenderVideo();

          expect(
            container.read(videoEditorProvider).isProcessing,
            isFalse,
          );
          expect(
            container.read(videoEditorProvider).finalRenderedClip,
            isNull,
          );
        },
      );

      test(
        'discards stale render when a newer render was started',
        () async {
          final notifier = container.read(videoEditorProvider.notifier);

          container
              .read(clipManagerProvider.notifier)
              .addClip(
                limitClipDuration: false,
                video: EditorVideo.file('/docs/clip.mp4'),
                targetAspectRatio: .vertical,
                originalAspectRatio: 9 / 16,
                duration: const Duration(seconds: 2),
              );

          final slowCompleter = Completer<(DivineVideoClip, String?)?>();
          final fastCompleter = Completer<(DivineVideoClip, String?)?>();

          var callCount = 0;
          VideoEditorRenderService.renderVideoToClipOverride =
              ({
                required clips,
                required editorStateHistory,
                originalAudioVolume = 1.0,
                customAudioVolume = 1.0,
                aiTrainingOptOut = true,
                parameters,
                taskId,
              }) {
                callCount++;
                // First call = slow render, second call = fast render
                return callCount == 1
                    ? slowCompleter.future
                    : fastCompleter.future;
              };

          final staleClip = DivineVideoClip(
            id: 'stale',
            video: EditorVideo.file('/docs/stale.mp4'),
            duration: const Duration(seconds: 2),
            recordedAt: DateTime.now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          );
          final freshClip = DivineVideoClip(
            id: 'fresh',
            video: EditorVideo.file('/docs/fresh.mp4'),
            duration: const Duration(seconds: 3),
            recordedAt: DateTime.now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          );

          // Start first (slow) render
          final render1 = notifier.startRenderVideo();
          // Start second (fast) render — increments _renderGeneration
          final render2 = notifier.startRenderVideo();

          expect(callCount, equals(2));

          // Fast render completes first
          fastCompleter.complete((freshClip, null));
          await render2;

          // Slow render completes after — should be discarded
          slowCompleter.complete((staleClip, null));
          await render1;

          final state = container.read(videoEditorProvider);
          expect(
            state.finalRenderedClip?.id,
            equals('fresh'),
            reason:
                'should keep the result from the latest render, '
                'not the stale one',
          );
        },
      );

      test(
        'stale render does not reset isProcessing',
        () async {
          final notifier = container.read(videoEditorProvider.notifier);

          container
              .read(clipManagerProvider.notifier)
              .addClip(
                limitClipDuration: false,
                video: EditorVideo.file('/docs/clip.mp4'),
                targetAspectRatio: .vertical,
                originalAspectRatio: 9 / 16,
                duration: const Duration(seconds: 2),
              );

          final slowCompleter = Completer<(DivineVideoClip, String?)?>();
          final fastCompleter = Completer<(DivineVideoClip, String?)?>();

          var callCount = 0;
          VideoEditorRenderService.renderVideoToClipOverride =
              ({
                required clips,
                required editorStateHistory,
                originalAudioVolume = 1.0,
                customAudioVolume = 1.0,
                aiTrainingOptOut = true,
                parameters,
                taskId,
              }) {
                callCount++;
                return callCount == 1
                    ? slowCompleter.future
                    : fastCompleter.future;
              };

          // Start first (slow) render
          final render1 = notifier.startRenderVideo();
          // Start second render — will complete with null (cancelled)
          final render2 = notifier.startRenderVideo();

          // Second render returns null (simulating cancellation)
          fastCompleter.complete(null);
          await render2;

          // isProcessing should be false after the latest render
          // returned null
          expect(
            container.read(videoEditorProvider).isProcessing,
            isFalse,
          );

          // Now the stale render completes — should be silently
          // discarded without touching state
          final staleClip = DivineVideoClip(
            id: 'stale',
            video: EditorVideo.file('/docs/stale.mp4'),
            duration: const Duration(seconds: 2),
            recordedAt: DateTime.now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          );
          slowCompleter.complete((staleClip, null));
          await render1;

          expect(
            container.read(videoEditorProvider).finalRenderedClip,
            isNull,
            reason:
                'stale render result must not set '
                'finalRenderedClip',
          );
        },
      );

      test(
        'passes draftId as taskId to render service',
        () async {
          final notifier = container.read(videoEditorProvider.notifier);

          container
              .read(clipManagerProvider.notifier)
              .addClip(
                limitClipDuration: false,
                video: EditorVideo.file('/docs/clip.mp4'),
                targetAspectRatio: .vertical,
                originalAspectRatio: 9 / 16,
                duration: const Duration(seconds: 2),
              );

          notifier.setDraftId('my-draft-123');

          String? capturedTaskId;
          VideoEditorRenderService.renderVideoToClipOverride =
              ({
                required clips,
                required editorStateHistory,
                originalAudioVolume = 1.0,
                customAudioVolume = 1.0,
                aiTrainingOptOut = true,
                parameters,
                taskId,
              }) async {
                capturedTaskId = taskId;
                return null;
              };

          await notifier.startRenderVideo();

          expect(
            capturedTaskId,
            equals('my-draft-123'),
            reason: 'draftId should be used as the render taskId',
          );
        },
      );

      test(
        'uses autoSaveId as taskId when no draftId is set',
        () async {
          final notifier = container.read(videoEditorProvider.notifier);

          container
              .read(clipManagerProvider.notifier)
              .addClip(
                limitClipDuration: false,
                video: EditorVideo.file('/docs/clip.mp4'),
                targetAspectRatio: .vertical,
                originalAspectRatio: 9 / 16,
                duration: const Duration(seconds: 2),
              );

          String? capturedTaskId;
          VideoEditorRenderService.renderVideoToClipOverride =
              ({
                required clips,
                required editorStateHistory,
                originalAudioVolume = 1.0,
                customAudioVolume = 1.0,
                aiTrainingOptOut = true,
                parameters,
                taskId,
              }) async {
                capturedTaskId = taskId;
                return null;
              };

          await notifier.startRenderVideo();

          expect(
            capturedTaskId,
            equals(VideoEditorConstants.autoSaveId),
            reason:
                'should fall back to autoSaveId when '
                'no draftId is set',
          );
        },
      );
    });

    group('invalidateFinalRenderedClip', () {
      test(
        'is a no-op when finalRenderedClip is null',
        () {
          final notifier = container.read(videoEditorProvider.notifier);
          final stateBefore = container.read(videoEditorProvider);

          expect(stateBefore.finalRenderedClip, isNull);

          notifier.invalidateFinalRenderedClip();

          expect(
            identical(container.read(videoEditorProvider), stateBefore),
            isTrue,
            reason:
                'state should be the exact same instance '
                'when clip is already null',
          );
        },
      );

      test(
        'is a no-op when finalRenderedClip is null even if '
        'isProcessing is true',
        () {
          final notifier = container.read(videoEditorProvider.notifier);

          notifier.setProcessing(true);
          final stateBefore = container.read(videoEditorProvider);

          expect(stateBefore.finalRenderedClip, isNull);
          expect(stateBefore.isProcessing, isTrue);

          notifier.invalidateFinalRenderedClip();

          // isProcessing should still be true — cancelRenderVideo was
          // never called because clip was null.
          expect(
            container.read(videoEditorProvider).isProcessing,
            isTrue,
            reason:
                'isProcessing should remain true because '
                'invalidate is a no-op when clip is null',
          );
        },
      );
    });

    group('cancelRenderVideo', () {
      test(
        'resets isProcessing to false when clips are already empty',
        () async {
          final notifier = container.read(videoEditorProvider.notifier);

          container
              .read(clipManagerProvider.notifier)
              .addClip(
                video: EditorVideo.file('/docs/original.mp4'),
                targetAspectRatio: .vertical,
                originalAspectRatio: 9 / 16,
                duration: const Duration(seconds: 2),
                limitClipDuration: false,
              );

          notifier.setProcessing(true);
          container.read(clipManagerProvider.notifier).clearClips();

          await notifier.cancelRenderVideo();

          expect(
            container.read(videoEditorProvider).isProcessing,
            isFalse,
          );
        },
      );

      test(
        'resets isProcessing to false without clips',
        () async {
          final notifier = container.read(videoEditorProvider.notifier);

          notifier.setProcessing(true);
          expect(
            container.read(videoEditorProvider).isProcessing,
            isTrue,
          );

          await notifier.cancelRenderVideo();

          expect(
            container.read(videoEditorProvider).isProcessing,
            isFalse,
            reason:
                'isProcessing should always reset to false '
                'after cancel, regardless of clip state',
          );
        },
      );

      test(
        'uses draftId as taskId for cancel',
        () async {
          final notifier = container.read(videoEditorProvider.notifier);

          notifier.setDraftId('custom-draft-id');
          notifier.setProcessing(true);

          // cancelRenderVideo should not throw — it uses
          // draftId internally as the task identifier
          await notifier.cancelRenderVideo();

          expect(
            container.read(videoEditorProvider).isProcessing,
            isFalse,
          );
          expect(notifier.draftId, equals('custom-draft-id'));
        },
      );

      test(
        'uses default autoSaveId when no draftId is set',
        () async {
          final notifier = container.read(videoEditorProvider.notifier);

          notifier.setProcessing(true);

          // Without setting a custom draftId, it should fall back
          // to VideoEditorConstants.autoSaveId
          expect(
            notifier.draftId,
            equals(VideoEditorConstants.autoSaveId),
          );

          await notifier.cancelRenderVideo();

          expect(
            container.read(videoEditorProvider).isProcessing,
            isFalse,
          );
        },
      );
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
            limitClipDuration: false,
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
            limitClipDuration: false,
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
            limitClipDuration: false,
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
            limitClipDuration: false,
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

    group('restoreDraft', () {
      late _MockDraftStorageService mockDraftStorage;
      late ProviderContainer container;

      setUp(() {
        mockDraftStorage = _MockDraftStorageService();
        container = ProviderContainer(
          overrides: [
            draftStorageServiceProvider.overrideWithValue(mockDraftStorage),
          ],
        );
      });

      tearDown(() {
        container.dispose();
      });

      test('returns false when draft is not found', () async {
        when(
          () => mockDraftStorage.getDraftById(any()),
        ).thenAnswer((_) async => null);

        final result = await container
            .read(videoEditorProvider.notifier)
            .restoreDraft();

        expect(result, isFalse);
        verify(
          () => mockDraftStorage.getDraftById(
            VideoEditorConstants.autoSaveId,
          ),
        ).called(1);
      });

      test('returns false when draft is not found for custom id', () async {
        when(
          () => mockDraftStorage.getDraftById('custom-draft-id'),
        ).thenAnswer((_) async => null);

        final result = await container
            .read(videoEditorProvider.notifier)
            .restoreDraft('custom-draft-id');

        expect(result, isFalse);
        verify(
          () => mockDraftStorage.getDraftById('custom-draft-id'),
        ).called(1);
      });

      test('uses autoSaveId when no draftId is provided', () async {
        when(
          () => mockDraftStorage.getDraftById(any()),
        ).thenAnswer((_) async => null);

        await container.read(videoEditorProvider.notifier).restoreDraft();

        verify(
          () => mockDraftStorage.getDraftById(
            VideoEditorConstants.autoSaveId,
          ),
        ).called(1);
      });
    });
  });
}
