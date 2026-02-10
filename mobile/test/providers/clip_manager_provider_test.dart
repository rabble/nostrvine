// ABOUTME: Tests for ClipManagerProvider - Riverpod state management
// ABOUTME: Validates state updates and provider lifecycle

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group('ClipManagerProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
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
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 2),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      final state = container.read(clipManagerProvider);
      expect(state.clips.length, equals(1));
      expect(state.totalDuration, equals(const Duration(seconds: 2)));
    });

    test('deleteClip removes clip from state', () {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.addClip(
        video: EditorVideo.file('/path/to/video1.mp4'),
        duration: const Duration(seconds: 2),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );
      notifier.addClip(
        video: EditorVideo.file('/path/to/video2.mp4'),
        duration: const Duration(seconds: 1),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      final clipId = container.read(clipManagerProvider).clips[0].id;
      notifier.removeClipById(clipId);

      final state = container.read(clipManagerProvider);
      expect(state.clips.length, equals(1));
    });

    test('selectClip updates selected clip state', () {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.addClip(
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

    test('removeLastClip removes last clip', () {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.addClip(
        video: EditorVideo.file('/path/to/video1.mp4'),
        duration: const Duration(seconds: 1),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );
      notifier.addClip(
        video: EditorVideo.file('/path/to/video2.mp4'),
        duration: const Duration(seconds: 2),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      expect(container.read(clipManagerProvider).clips.length, equals(2));

      notifier.removeLastClip();

      final state = container.read(clipManagerProvider);
      expect(state.clips.length, equals(1));
    });

    test('clearAll removes all clips and resets state', () {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.addClip(
        video: EditorVideo.file('/path/to/video1.mp4'),
        duration: const Duration(seconds: 1),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );
      notifier.addClip(
        video: EditorVideo.file('/path/to/video2.mp4'),
        duration: const Duration(seconds: 2),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      notifier.clearAll();

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
        video: EditorVideo.file(sharedFilePath),
        duration: clipDuration,
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
        thumbnailPath: '/path/to/thumb.jpg',
      );

      final clip2 = notifier.addClip(
        video: EditorVideo.file(sharedFilePath),
        duration: clipDuration,
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
        thumbnailPath: '/path/to/thumb.jpg',
      );

      final clip3 = notifier.addClip(
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
          video: EditorVideo.file('/path/to/video1.mp4'),
          duration: const Duration(seconds: 2),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );
        notifier.addClip(
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
            video: EditorVideo.file('/path/to/existing1.mp4'),
            duration: const Duration(seconds: 2),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          );
          notifier.addClip(
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
            video: EditorVideo.file('/path/to/draft1.mp4'),
            duration: const Duration(seconds: 1),
            targetAspectRatio: .square,
            originalAspectRatio: 1,
          );
          final draftClip2 = notifier.addClip(
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
          video: EditorVideo.file('/path/to/existing.mp4'),
          duration: const Duration(seconds: 2),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );

        expect(container.read(clipManagerProvider).clips.length, equals(1));

        // Create clips to add (simulating draft clips)
        notifier.addClip(
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
    });
  });
}
