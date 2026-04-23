// ABOUTME: Unit tests for clip strip tiles library entry points.
// ABOUTME: Validates VideoEditorTimelineClipStrip constructor wiring.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_timeline_clip_strip.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group(VideoEditorTimelineClipStrip, () {
    test('stores constructor parameters', () {
      final clips = [_createTestClip(id: 'clip-1', seconds: 3)];
      final controller = ScrollController();

      final widget = VideoEditorTimelineClipStrip(
        clips: clips,
        totalWidth: 320,
        pixelsPerSecond: 80,
        scrollController: controller,
        isInteracting: true,
      );

      expect(widget.clips, same(clips));
      expect(widget.totalWidth, equals(320));
      expect(widget.pixelsPerSecond, equals(80));
      expect(widget.scrollController, same(controller));
      expect(widget.isInteracting, isTrue);

      controller.dispose();
    });

    test('is a StatefulWidget', () {
      final widget = VideoEditorTimelineClipStrip(
        clips: [_createTestClip(id: 'clip-2')],
        totalWidth: 240,
        pixelsPerSecond: 60,
      );

      expect(widget, isA<StatefulWidget>());
    });
  });
}

DivineVideoClip _createTestClip({
  required String id,
  int seconds = 2,
}) {
  return DivineVideoClip(
    id: id,
    video: EditorVideo.file('/tmp/test_$id.mp4'),
    duration: Duration(seconds: seconds),
    recordedAt: DateTime(2025),
    originalAspectRatio: 9 / 16,
    targetAspectRatio: model.AspectRatio.vertical,
  );
}
