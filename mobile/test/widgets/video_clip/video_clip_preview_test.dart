// ABOUTME: Tests for VideoClipPreview widget
// ABOUTME: Basic structure tests - video playback tests require platform setup

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/widgets/video_clip/video_clip_preview.dart';
import 'package:pro_video_editor/core/models/video/editor_video_model.dart';

void main() {
  group(VideoClipPreview, () {
    final testClip = DivineVideoClip(
      id: 'test-clip-1',
      video: EditorVideo.file('/path/to/video.mp4'),
      duration: const Duration(seconds: 5),
      recordedAt: DateTime(2026),
      targetAspectRatio: .vertical,
      originalAspectRatio: 9 / 16,
    );

    test('can be instantiated', () {
      expect(
        VideoClipPreview(clip: testClip),
        isA<VideoClipPreview>(),
      );
    });

    test('accepts onDelete callback', () {
      expect(
        VideoClipPreview(clip: testClip, onDelete: () {}),
        isA<VideoClipPreview>(),
      );
    });
  });
}
