// ABOUTME: Unit tests for VideoEditorTimelineBody.
// ABOUTME: Verifies constructor wiring for core timeline body dependencies.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_body.dart';

void main() {
  group(VideoEditorTimelineBody, () {
    test('stores constructor parameters', () {
      final scrollController = ScrollController();
      final playhead = ValueNotifier(Duration.zero);
      final clips = <DivineVideoClip>[];

      final widget = VideoEditorTimelineBody(
        totalDuration: const Duration(seconds: 12),
        pixelsPerSecond: 80,
        scrollController: scrollController,
        scrollPadding: 16,
        clips: clips,
        totalWidth: 960,
        isInteracting: false,
        onReorder: (_) {},
        onReorderChanged: (_) {},
        playheadPosition: playhead,
      );

      expect(widget.totalDuration, equals(const Duration(seconds: 12)));
      expect(widget.pixelsPerSecond, equals(80));
      expect(widget.scrollController, same(scrollController));
      expect(widget.scrollPadding, equals(16));
      expect(widget.clips, same(clips));
      expect(widget.totalWidth, equals(960));
      expect(widget.playheadPosition, same(playhead));

      scrollController.dispose();
      playhead.dispose();
    });
  });
}
