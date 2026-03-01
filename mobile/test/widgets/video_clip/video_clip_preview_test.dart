// ABOUTME: Tests for VideoClipPreview widget
// ABOUTME: Basic structure tests - video playback tests require platform setup

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/saved_clip.dart';
import 'package:openvine/widgets/video_clip/video_clip_preview.dart';

void main() {
  group(VideoClipPreview, () {
    final testClip = SavedClip(
      id: 'test-clip-1',
      filePath: '/path/to/video.mp4',
      thumbnailPath: null,
      duration: const Duration(seconds: 5),
      createdAt: DateTime(2026),
      aspectRatio: 'vertical',
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
