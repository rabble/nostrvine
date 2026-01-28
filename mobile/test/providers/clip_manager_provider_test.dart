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
        aspectRatio: .vertical,
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
        aspectRatio: .vertical,
      );
      notifier.addClip(
        video: EditorVideo.file('/path/to/video2.mp4'),
        duration: const Duration(seconds: 1),
        aspectRatio: .vertical,
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
        aspectRatio: .vertical,
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
        aspectRatio: .vertical,
      );
      final clipId = container.read(clipManagerProvider).clips[0].id;
      notifier.updateThumbnail(clipId, '/path/to/thumb.jpg');

      final state = container.read(clipManagerProvider);
      expect(state.clips[0].thumbnailPath, equals('/path/to/thumb.jpg'));
    });

    test('updateClipDuration updates clip duration', () {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.addClip(
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 2),
        aspectRatio: .vertical,
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
        aspectRatio: .vertical,
      );
      notifier.addClip(
        video: EditorVideo.file('/path/to/video2.mp4'),
        duration: const Duration(seconds: 2),
        aspectRatio: .vertical,
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
        aspectRatio: .vertical,
      );
      notifier.addClip(
        video: EditorVideo.file('/path/to/video2.mp4'),
        duration: const Duration(seconds: 2),
        aspectRatio: .vertical,
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
        aspectRatio: .vertical,
      );

      final state = container.read(clipManagerProvider);
      expect(state.canRecordMore, isTrue);
    });

    test('canRecordMore is false when at limit', () {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.addClip(
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: VideoEditorConstants.maxDuration,
        aspectRatio: .vertical,
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
        aspectRatio: .vertical,
        thumbnailPath: '/path/to/thumb.jpg',
      );

      final clip2 = notifier.addClip(
        video: EditorVideo.file(sharedFilePath),
        duration: clipDuration,
        aspectRatio: .vertical,
        thumbnailPath: '/path/to/thumb.jpg',
      );

      final clip3 = notifier.addClip(
        video: EditorVideo.file(sharedFilePath),
        duration: clipDuration,
        aspectRatio: .vertical,
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
  });
}
