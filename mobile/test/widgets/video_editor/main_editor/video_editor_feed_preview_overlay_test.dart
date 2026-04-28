// ABOUTME: Unit tests for VideoEditorFeedPreviewOverlay.
// ABOUTME: Verifies constructor wiring and widget type.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_feed_preview_overlay.dart';

void main() {
  group(VideoEditorFeedPreviewOverlay, () {
    test('stores constructor parameters', () {
      const overlay = VideoEditorFeedPreviewOverlay(
        targetAspectRatio: 9 / 16,
        isFeedPreviewVisible: true,
      );

      expect(overlay.targetAspectRatio, equals(9 / 16));
      expect(overlay.isFeedPreviewVisible, isTrue);
    });

    test('is a ConsumerWidget', () {
      const overlay = VideoEditorFeedPreviewOverlay(
        targetAspectRatio: 1,
        isFeedPreviewVisible: false,
      );

      expect(overlay, isA<ConsumerWidget>());
    });
  });
}
