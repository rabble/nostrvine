// ABOUTME: Unit tests for VideoEditorFeedPreviewOverlay.
// ABOUTME: Verifies constructor wiring and widget type.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_feed_preview_overlay.dart';

void main() {
  group(VideoEditorFeedPreviewOverlay, () {
    test('stores constructor parameters', () {
      const overlay = VideoEditorFeedPreviewOverlay(
        renderSize: Size(1080, 1920),
        targetAspectRatio: 9 / 16,
        isFeedPreviewVisible: true,
      );

      expect(overlay.renderSize, equals(const Size(1080, 1920)));
      expect(overlay.targetAspectRatio, equals(9 / 16));
      expect(overlay.isFeedPreviewVisible, isTrue);
    });

    test('is a ConsumerWidget', () {
      const overlay = VideoEditorFeedPreviewOverlay(
        renderSize: Size(300, 500),
        targetAspectRatio: 1,
        isFeedPreviewVisible: false,
      );

      expect(overlay, isA<ConsumerWidget>());
    });
  });
}
