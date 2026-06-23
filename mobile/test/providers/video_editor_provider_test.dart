// ABOUTME: Unit tests for EditorProvider (Riverpod) validating state mutations and provider behavior
// ABOUTME: Tests all EditorNotifier methods and state transitions using ProviderContainer

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:characters/characters.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/video_editor/video_editor_audio_render.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:openvine/widgets/video_editor/sticker_editor/video_editor_sticker.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show CompleteParameters, WidgetLayer, WidgetLayerExportConfigs;
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockDraftStorageService extends Mock implements DraftStorageService {}

void main() {
  group('VideoEditorProvider', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
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
            .updateMetadata(title: 'Test Title');

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

    group('updateMetadata description trimming', () {
      test(
        'truncates description by grapheme clusters without splitting emoji',
        () {
          final notifier = container.read(videoEditorProvider.notifier);

          // Build a description that exceeds descriptionLimit by repeating a
          // multi-code-unit emoji ("🎉" is one grapheme but 2 UTF-16 code
          // units). Naive substring on UTF-16 code units would split the
          // surrogate pair at the boundary and produce an invalid string.
          const emoji = '🎉';
          final longDescription =
              emoji * (VideoEditorConstants.descriptionLimit + 10);

          notifier.updateMetadata(description: longDescription);
          final stored = container.read(videoEditorProvider).description;

          expect(
            stored.characters.length,
            VideoEditorConstants.descriptionLimit,
            reason: 'should be truncated to limit measured in graphemes',
          );
          // The truncated string must remain composed of full emoji
          // graphemes — i.e. its UTF-16 code-unit length must be exactly
          // 2 * descriptionLimit (each emoji = 2 code units).
          expect(
            stored.length,
            VideoEditorConstants.descriptionLimit * 2,
            reason: 'no surrogate pair was split mid-character',
          );
          expect(
            stored.characters.every((g) => g == emoji),
            isTrue,
            reason: 'every grapheme is the original emoji',
          );
        },
      );

      test('preserves descriptions shorter than the limit verbatim', () {
        final notifier = container.read(videoEditorProvider.notifier);

        notifier.updateMetadata(description: 'short text');
        expect(container.read(videoEditorProvider).description, 'short text');
      });

      test('trims whitespace before applying the grapheme limit', () {
        final notifier = container.read(videoEditorProvider.notifier);

        notifier.updateMetadata(description: '   hello world   ');
        expect(container.read(videoEditorProvider).description, 'hello world');
      });
    });

    group('setDraftId', () {
      test('should set the draft ID', () {
        const id = 'test-draft-id';
        container.read(videoEditorProvider.notifier).setDraftId(id);

        expect(id, container.read(videoEditorProvider.notifier).draftId);
      });
    });

    group('audio render mapping', () {
      test('selected local import is rendered as file audio', () {
        final sound = AudioEvent.fromLocalImport(
          id: 'local_import_1700000000000',
          filePath: '/tmp/imported/snare.mp3',
          createdAt: 1700000000,
          title: 'snare',
          mimeType: 'audio/mpeg',
          duration: 2,
        );

        final track = audioTrackFromSoundForRender(sound);

        expect(track, isNotNull);
        expect(track!.audio.hasFile, isTrue);
        expect(track.audio.file?.path, equals('/tmp/imported/snare.mp3'));
        expect(track.audio.hasNetworkUrl, isFalse);
      });

      test('selected absolute-path url is rendered as file audio', () {
        const sound = AudioEvent(
          id: 'video_source_copy_3',
          pubkey: 'pk',
          createdAt: 1700000000,
          url: '/tmp/extracted/selected.m4a',
          duration: 3,
        );

        final track = audioTrackFromSoundForRender(sound);

        expect(track, isNotNull);
        expect(track!.audio.hasFile, isTrue);
        expect(track.audio.file?.path, equals('/tmp/extracted/selected.m4a'));
        expect(track.audio.hasNetworkUrl, isFalse);
      });

      test('selected sound without a resolvable source is skipped', () {
        const sound = AudioEvent(
          id: 'video_source_no_url',
          pubkey: 'pk',
          createdAt: 1700000000,
          duration: 3,
        );

        expect(audioTrackFromSoundForRender(sound), isNull);
      });

      test('selected sound without a known duration is skipped', () {
        const sound = AudioEvent(
          id: 'video_source_no_duration',
          pubkey: 'pk',
          createdAt: 1700000000,
          url: 'https://media.divine.video/abc',
        );

        expect(audioTrackFromSoundForRender(sound), isNull);
      });

      test(
        'selected sound with a start offset gets a valid composition window',
        () {
          const sound = AudioEvent(
            id: 'video_selected_offset',
            pubkey: 'pk',
            createdAt: 1700000000,
            url: 'https://media.divine.video/abc',
            duration: 6.533,
            startOffset: Duration(milliseconds: 292),
          );

          final track = audioTrackFromSoundForRender(sound);

          // Regression: previously startTime=startOffset and endTime=null
          // produced an invalid [0.292s, 0.0s] window the native renderer
          // dropped with "no time remaining in composition".
          expect(track, isNotNull);
          expect(track!.startTime, equals(Duration.zero));
          expect(track.endTime, equals(const Duration(milliseconds: 6533)));
          expect(
            track.audioStartTime,
            equals(const Duration(milliseconds: 292)),
          );
          // Null = play to file end, clipped by the composition window.
          expect(track.audioEndTime, isNull);
        },
      );

      test(
        'meta network original sound renders with its composition window and '
        'plays to file end',
        () {
          const event = AudioEvent(
            id: 'video_source_copy_1',
            pubkey: 'pk',
            createdAt: 1700000000,
            url: 'https://media.divine.video/abc123',
            duration: 6.533,
            startOffset: Duration(milliseconds: 292),
            endTime: Duration(milliseconds: 3966),
          );

          final track = audioTrackFromMetaForRender(event);

          expect(track, isNotNull);
          expect(track!.audio.hasNetworkUrl, isTrue);
          expect(
            track.audioStartTime,
            equals(const Duration(milliseconds: 292)),
          );
          // Null = play to the end of the file; the composition window clips
          // it. (Previously startOffset + full length overran the file end.)
          expect(track.audioEndTime, isNull);
          expect(track.startTime, equals(Duration.zero));
          expect(track.endTime, equals(const Duration(milliseconds: 3966)));
        },
      );

      test(
        'meta track with an invalid window plays across the whole video',
        () {
          // A sound added before its duration was known persists endTime=0.
          const event = AudioEvent(
            id: 'video_source_no_window',
            pubkey: 'pk',
            createdAt: 1700000000,
            url: 'https://media.divine.video/abc123',
            startOffset: Duration(milliseconds: 100),
          );

          final track = audioTrackFromMetaForRender(event);

          expect(track, isNotNull);
          // Both null = play for the entire video, instead of an invalid
          // zero-length [start, 0] window the native renderer would drop.
          expect(track!.startTime, isNull);
          expect(track.endTime, isNull);
          expect(
            track.audioStartTime,
            equals(const Duration(milliseconds: 100)),
          );
          expect(track.audioEndTime, isNull);
        },
      );

      test('meta absolute-path url renders as file audio', () {
        const event = AudioEvent(
          id: 'video_source_copy_2',
          pubkey: 'pk',
          createdAt: 1700000000,
          url: '/tmp/extracted/original.m4a',
          duration: 3,
        );

        final track = audioTrackFromMetaForRender(event);

        expect(track, isNotNull);
        expect(track!.audio.hasFile, isTrue);
        expect(track.audio.file?.path, equals('/tmp/extracted/original.m4a'));
      });

      test('meta local import renders as file audio', () {
        final event = AudioEvent.fromLocalImport(
          id: 'local_import_1700000000000',
          filePath: '/tmp/imported/beat.mp3',
          createdAt: 1700000000,
          title: 'beat',
          mimeType: 'audio/mpeg',
          duration: 4,
        );

        final track = audioTrackFromMetaForRender(event);

        expect(track, isNotNull);
        expect(track!.audio.hasFile, isTrue);
        expect(track.audio.file?.path, equals('/tmp/imported/beat.mp3'));
      });

      test('meta track without a resolvable source is skipped', () {
        const event = AudioEvent(
          id: 'video_source_no_url',
          pubkey: 'pk',
          createdAt: 1700000000,
        );

        expect(audioTrackFromMetaForRender(event), isNull);
      });
    });

    group('setProcessing', () {
      test('sets isProcessing to true', () {
        container.read(videoEditorProvider.notifier).setProcessing(true);

        expect(container.read(videoEditorProvider).isProcessing, isTrue);
      });

      test('sets isProcessing to false', () {
        container.read(videoEditorProvider.notifier).setProcessing(true);
        container.read(videoEditorProvider.notifier).setProcessing(false);

        expect(container.read(videoEditorProvider).isProcessing, isFalse);
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

      test('resets isProcessing to false when finalRenderedClip '
          'already exists', () async {
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
      });

      test('sets finalRenderedClip when render completes', () async {
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
              parameters,
              taskId,
            }) async => (renderedClip, null);

        await notifier.startRenderVideo();

        final state = container.read(videoEditorProvider);
        expect(state.finalRenderedClip, equals(renderedClip));
        expect(state.isProcessing, isFalse);
      });

      test('sets isProcessing to false when render returns null', () async {
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
              parameters,
              taskId,
            }) async => null;

        await notifier.startRenderVideo();

        expect(container.read(videoEditorProvider).isProcessing, isFalse);
        expect(container.read(videoEditorProvider).finalRenderedClip, isNull);
      });

      test('discards stale render when a newer render was started', () async {
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
      });

      test('stale render does not reset isProcessing', () async {
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
        expect(container.read(videoEditorProvider).isProcessing, isFalse);

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
      });

      test('passes draftId as taskId to render service', () async {
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
      });

      test('uses autoSaveId as taskId when no draftId is set', () async {
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
      });
    });

    group('invalidateFinalRenderedClip', () {
      test('is a no-op when finalRenderedClip is null', () {
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
      });

      test('is a no-op when finalRenderedClip is null even if '
          'isProcessing is true', () {
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
      });
    });

    group('updateCover', () {
      test('is a no-op when finalRenderedClip is null', () {
        final notifier = container.read(videoEditorProvider.notifier);
        final stateBefore = container.read(videoEditorProvider);

        expect(stateBefore.finalRenderedClip, isNull);

        notifier.updateCover(
          thumbnailPath: '/docs/cover.jpg',
          thumbnailTimestamp: const Duration(seconds: 2),
        );

        expect(
          identical(container.read(videoEditorProvider), stateBefore),
          isTrue,
          reason:
              'state should be the exact same instance when '
              'finalRenderedClip is null — no autosave triggered',
        );
      });

      test('updates thumbnailPath and thumbnailTimestamp on the clip', () {
        final notifier = container.read(videoEditorProvider.notifier);

        notifier.state = notifier.state.copyWith(
          finalRenderedClip: DivineVideoClip(
            id: 'rendered',
            video: EditorVideo.file('/docs/rendered.mp4'),
            duration: const Duration(seconds: 5),
            recordedAt: DateTime.now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          ),
        );

        notifier.updateCover(
          thumbnailPath: '/docs/cover.jpg',
          thumbnailTimestamp: const Duration(seconds: 2),
        );

        final updatedClip = container
            .read(videoEditorProvider)
            .finalRenderedClip;
        expect(updatedClip, isNotNull);
        expect(updatedClip!.thumbnailPath, '/docs/cover.jpg');
        expect(updatedClip.thumbnailTimestamp, const Duration(seconds: 2));
      });

      test('persists the cover position on state so it survives a '
          're-render', () {
        final notifier = container.read(videoEditorProvider.notifier);

        notifier.state = notifier.state.copyWith(
          finalRenderedClip: DivineVideoClip(
            id: 'rendered',
            video: EditorVideo.file('/docs/rendered.mp4'),
            duration: const Duration(seconds: 5),
            recordedAt: DateTime.now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          ),
        );

        notifier.updateCover(
          thumbnailPath: '/docs/cover.jpg',
          thumbnailTimestamp: const Duration(seconds: 2),
        );

        final state = container.read(videoEditorProvider);
        expect(
          state.thumbnailTimestamp,
          const Duration(seconds: 2),
          reason:
              'updateCover must record the cover position on state, not '
              'only on finalRenderedClip, so it survives invalidation',
        );
        expect(
          state.customThumbnailPath,
          '/docs/cover.jpg',
          reason:
              'updateCover must record the cover image path durably so cover '
              'displays survive finalRenderedClip being cleared',
        );
      });
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

          expect(container.read(videoEditorProvider).isProcessing, isFalse);
        },
      );

      test('resets isProcessing to false without clips', () async {
        final notifier = container.read(videoEditorProvider.notifier);

        notifier.setProcessing(true);
        expect(container.read(videoEditorProvider).isProcessing, isTrue);

        await notifier.cancelRenderVideo();

        expect(
          container.read(videoEditorProvider).isProcessing,
          isFalse,
          reason:
              'isProcessing should always reset to false '
              'after cancel, regardless of clip state',
        );
      });

      test('uses draftId as taskId for cancel', () async {
        final notifier = container.read(videoEditorProvider.notifier);

        notifier.setDraftId('custom-draft-id');
        notifier.setProcessing(true);

        // cancelRenderVideo should not throw — it uses
        // draftId internally as the task identifier
        await notifier.cancelRenderVideo();

        expect(container.read(videoEditorProvider).isProcessing, isFalse);
        expect(notifier.draftId, equals('custom-draft-id'));
      });

      test('uses default autoSaveId when no draftId is set', () async {
        final notifier = container.read(videoEditorProvider.notifier);

        notifier.setProcessing(true);

        // Without setting a custom draftId, it should fall back
        // to VideoEditorConstants.autoSaveId
        expect(notifier.draftId, equals(VideoEditorConstants.autoSaveId));

        await notifier.cancelRenderVideo();

        expect(container.read(videoEditorProvider).isProcessing, isFalse);
      });
    });
  });

  group('getActiveDraft', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
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

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
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

      final copied = original.copyWith(isProcessing: false, title: 'Updated');

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

      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        mockDraftStorage = _MockDraftStorageService();
        container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
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
          () => mockDraftStorage.getDraftById(VideoEditorConstants.autoSaveId),
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
          () => mockDraftStorage.getDraftById(VideoEditorConstants.autoSaveId),
        ).called(1);
      });

      test('restores the saved cover position onto state', () async {
        final draft = DivineVideoDraft.create(
          id: 'draft-1',
          clips: [
            DivineVideoClip(
              id: 'c1',
              video: EditorVideo.file('/docs/clip.mp4'),
              duration: const Duration(seconds: 3),
              recordedAt: DateTime.now(),
              targetAspectRatio: .vertical,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: 'Title',
          description: '',
          hashtags: const {},
          selectedApproach: 'video',
          thumbnailTimestamp: const Duration(milliseconds: 900),
        );
        when(
          () => mockDraftStorage.getDraftById('draft-1'),
        ).thenAnswer((_) async => draft);

        final result = await container
            .read(videoEditorProvider.notifier)
            .restoreDraft('draft-1');

        expect(result, isTrue);
        expect(
          container.read(videoEditorProvider).thumbnailTimestamp,
          const Duration(milliseconds: 900),
          reason: 'reopening a draft must restore the selected cover position',
        );
      });

      test('restores the durable custom cover path onto state', () async {
        final draft = DivineVideoDraft.create(
          id: 'draft-1',
          clips: [
            DivineVideoClip(
              id: 'c1',
              video: EditorVideo.file('/docs/clip.mp4'),
              duration: const Duration(seconds: 3),
              recordedAt: DateTime.now(),
              targetAspectRatio: .vertical,
              originalAspectRatio: 9 / 16,
            ),
          ],
          title: 'Title',
          description: '',
          hashtags: const {},
          selectedApproach: 'video',
          thumbnailTimestamp: const Duration(milliseconds: 900),
          customThumbnailPath: '/docs/cover.jpg',
        );
        when(
          () => mockDraftStorage.getDraftById('draft-1'),
        ).thenAnswer((_) async => draft);

        await container
            .read(videoEditorProvider.notifier)
            .restoreDraft('draft-1');

        expect(
          container.read(videoEditorProvider).customThumbnailPath,
          '/docs/cover.jpg',
          reason:
              'the selected cover image path must survive reopening a draft, '
              'independently of finalRenderedClip (#5181)',
        );
      });

      test(
        'restores a draft whose editorEditingParameters contain a sticker '
        'widget layer without crashing on the widgetLoader assertion',
        () async {
          const sticker = StickerData.network(
            'https://stickers.example.com/heart.png',
            description: 'Red heart',
            tags: ['heart'],
            packData: StickerPackData(
              packId: 'reactions',
              packName: 'Reactions',
            ),
          );
          final stickerLayer = WidgetLayer(
            width: 120,
            widget: const VideoEditorSticker(
              sticker: sticker,
              enableLimitCacheSize: false,
            ),
            meta: sticker.toJson(),
            exportConfigs: WidgetLayerExportConfigs(
              id: 'sticker-${sticker.description}',
              meta: sticker.toJson(),
            ),
          );
          final params = CompleteParameters(
            blur: 0,
            originalImageSize: const Size(1080, 1920),
            temporaryDecodedImageSize: const Size(1080, 1920),
            bodySize: const Size(400, 800),
            editorSize: const Size(400, 800),
            matrixFilterList: const [],
            matrixTuneAdjustmentsList: const [],
            startTime: null,
            endTime: null,
            cropWidth: null,
            cropHeight: null,
            rotateTurns: 0,
            cropX: null,
            cropY: null,
            flipX: false,
            flipY: false,
            image: Uint8List(0),
            isTransformed: false,
            layers: [stickerLayer],
          );

          // Mirror how a draft persists editorEditingParameters: the in-memory
          // CompleteParameters is serialized via toMap() and round-tripped
          // through JSON into storage.
          final persistedParameters =
              json.decode(json.encode(params.toMap())) as Map<String, dynamic>;

          final draft = DivineVideoDraft.create(
            id: 'draft-1',
            clips: [
              DivineVideoClip(
                id: 'c1',
                video: EditorVideo.file('/docs/clip.mp4'),
                duration: const Duration(seconds: 3),
                recordedAt: DateTime.now(),
                targetAspectRatio: .vertical,
                originalAspectRatio: 9 / 16,
              ),
            ],
            title: 'Title',
            description: '',
            hashtags: const {},
            selectedApproach: 'video',
            editorEditingParameters: persistedParameters,
          );
          when(
            () => mockDraftStorage.getDraftById('draft-1'),
          ).thenAnswer((_) async => draft);

          // restoreDraft rehydrates editorEditingParameters via
          // completeParametersFromDraftMap, which threads
          // videoEditorStickerWidgetLoader so the exported-by-id sticker layer
          // rebuilds into a VideoEditorSticker. Reverting that call site to a
          // bare CompleteParameters.fromMap would throw the widgetLoader
          // assertion here, surfacing as a thrown restore rather than a green
          // test (#5474).
          final result = await container
              .read(videoEditorProvider.notifier)
              .restoreDraft('draft-1');

          expect(result, isTrue);
        },
      );
    });
  });

  group('cover thumbnail persistence', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('getActiveDraft sources thumbnailTimestamp from the persisted '
        'cover position when finalRenderedClip is absent', () {
      final notifier = container.read(videoEditorProvider.notifier);

      container
          .read(clipManagerProvider.notifier)
          .addClip(
            limitClipDuration: false,
            video: EditorVideo.file('/docs/original.mp4'),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
            duration: const Duration(seconds: 2),
          );

      // The cover lives only on state, mirroring the window after invalidation
      // clears finalRenderedClip but before a re-render.
      notifier.state = notifier.state.copyWith(
        thumbnailTimestamp: const Duration(milliseconds: 1200),
        customThumbnailPath: '/docs/cover.jpg',
      );

      final draft = notifier.getActiveDraft();

      expect(
        draft.thumbnailTimestamp,
        const Duration(milliseconds: 1200),
        reason:
            'the published cover is derived from draft.thumbnailTimestamp, so '
            'it must reflect the selected position even without a rendered clip',
      );
      expect(
        draft.customThumbnailPath,
        '/docs/cover.jpg',
        reason:
            'the durable cover path must persist so the drafts list keeps '
            'showing the selected cover after finalRenderedClip is cleared',
      );
    });
  });

  group('saveAsDraft', () {
    late _MockDraftStorageService mockDraftStorage;
    late ProviderContainer container;

    setUpAll(() {
      registerFallbackValue(
        DivineVideoDraft.create(
          id: 'fallback',
          clips: const [],
          title: '',
          description: '',
          hashtags: const {},
          selectedApproach: 'video',
        ),
      );
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      mockDraftStorage = _MockDraftStorageService();
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          draftStorageServiceProvider.overrideWithValue(mockDraftStorage),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('returns true and clears isSavingDraft on success', () async {
      when(() => mockDraftStorage.saveDraft(any())).thenAnswer((_) async {});
      when(() => mockDraftStorage.deleteDraft(any())).thenAnswer((_) async {});

      final result = await container
          .read(videoEditorProvider.notifier)
          .saveAsDraft(enforceCreateNewDraft: true);

      expect(result, isTrue);
      expect(
        container.read(videoEditorProvider).isSavingDraft,
        isFalse,
        reason: 'a successful save must re-enable the save button',
      );
    });

    test('clears isSavingDraft and returns false when the write hangs', () {
      // Reproduces the dead "Save for later" button: a draft write that never
      // resolves must not leave isSavingDraft stuck true for the session.
      when(
        () => mockDraftStorage.saveDraft(any()),
      ).thenAnswer((_) => Completer<void>().future);

      fakeAsync((async) {
        final notifier = container.read(videoEditorProvider.notifier);
        bool? result;
        notifier
            .saveAsDraft(enforceCreateNewDraft: true)
            .then((value) => result = value);

        expect(
          container.read(videoEditorProvider).isSavingDraft,
          isTrue,
          reason: 'the button is disabled while a save is in flight',
        );

        async.elapse(
          VideoEditorConstants.draftSaveTimeout + const Duration(seconds: 1),
        );

        expect(result, isFalse, reason: 'a timed-out save reports failure');
        expect(
          container.read(videoEditorProvider).isSavingDraft,
          isFalse,
          reason: 'a timed-out save must re-enable the save button',
        );
      });
    });

    test('returns false while a previous save is still in flight', () {
      when(
        () => mockDraftStorage.saveDraft(any()),
      ).thenAnswer((_) => Completer<void>().future);

      fakeAsync((async) {
        final notifier = container.read(videoEditorProvider.notifier);
        unawaited(notifier.saveAsDraft(enforceCreateNewDraft: true));
        async.flushMicrotasks();

        bool? secondResult;
        notifier
            .saveAsDraft(enforceCreateNewDraft: true)
            .then((value) => secondResult = value);
        async.flushMicrotasks();

        expect(
          secondResult,
          isFalse,
          reason: 'concurrent saves are rejected by the in-flight guard',
        );
      });
    });

    test('does not abandon autosave cleanup after a successful draft save', () {
      // The autosave delete must run to completion: an abandoned delete could
      // later wipe a new session's recovery point. So a stalled cleanup keeps
      // isSavingDraft true and the save unresolved rather than being dropped.
      when(() => mockDraftStorage.saveDraft(any())).thenAnswer((_) async {});

      fakeAsync((async) {
        // Create the completer inside the fake zone so completing it later is
        // driven by `async.flushMicrotasks()` rather than the root zone.
        final cleanup = Completer<void>();
        when(
          () => mockDraftStorage.deleteDraft(any()),
        ).thenAnswer((_) => cleanup.future);

        final notifier = container.read(videoEditorProvider.notifier);
        bool? result;
        notifier
            .saveAsDraft(enforceCreateNewDraft: true)
            .then((value) => result = value);

        // Let the write resolve so we are parked on the pending cleanup.
        async.flushMicrotasks();
        // Time passing must not abandon the cleanup.
        async.elapse(
          VideoEditorConstants.draftSaveTimeout + const Duration(seconds: 5),
        );

        expect(
          result,
          isNull,
          reason: 'the save stays in flight while the cleanup is pending',
        );
        expect(
          container.read(videoEditorProvider).isSavingDraft,
          isTrue,
          reason: 'the autosave cleanup is not abandoned on a timeout',
        );

        cleanup.complete();
        async.flushMicrotasks();

        expect(result, isTrue);
        expect(
          container.read(videoEditorProvider).isSavingDraft,
          isFalse,
          reason: 'the save resolves once the cleanup lands',
        );
      });
    });
  });
}
