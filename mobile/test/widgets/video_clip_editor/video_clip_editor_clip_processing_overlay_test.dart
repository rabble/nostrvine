// ABOUTME: Tests for VideoClipEditorProcessingOverlay widget
// ABOUTME: Verifies opacity and visibility based on clip processing state

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/widgets/video_clip_editor/video_clip_editor_processing_overlay.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

RecordingClip _createClip({Completer<bool>? processingCompleter}) {
  return RecordingClip(
    id: 'test-clip',
    video: EditorVideo.file('/test/video.mp4'),
    duration: const Duration(seconds: 2),
    recordedAt: DateTime.now(),
    aspectRatio: model.AspectRatio.square,
    processingCompleter: processingCompleter,
  );
}

void main() {
  group('VideoClipEditorProcessingOverlay', () {
    testWidgets('should be visible when clip is processing', (tester) async {
      final completer = Completer<bool>();
      final clip = _createClip(processingCompleter: completer);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: VideoClipEditorProcessingOverlay(clip: clip)),
        ),
      );

      // Should show overlay when processing
      final overlayFinder = find.byWidgetPredicate(
        (widget) =>
            widget is ColoredBox &&
            widget.color == const Color.fromARGB(180, 0, 0, 0),
      );
      expect(overlayFinder, findsOneWidget);
    });

    testWidgets('should be invisible when clip is not processing', (
      tester,
    ) async {
      final clip = _createClip(); // No processingCompleter

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: VideoClipEditorProcessingOverlay(clip: clip)),
        ),
      );

      // Should not show overlay when not processing
      final overlayFinder = find.byWidgetPredicate(
        (widget) =>
            widget is ColoredBox &&
            widget.color == const Color.fromARGB(140, 0, 0, 0),
      );
      expect(overlayFinder, findsNothing);
    });

    testWidgets('should be invisible when processing is completed', (
      tester,
    ) async {
      final completer = Completer<bool>()..complete(true);
      final clip = _createClip(processingCompleter: completer);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: VideoClipEditorProcessingOverlay(clip: clip)),
        ),
      );

      // Should not show overlay when processing is complete
      final overlayFinder = find.byWidgetPredicate(
        (widget) =>
            widget is ColoredBox &&
            widget.color == const Color.fromARGB(140, 0, 0, 0),
      );
      expect(overlayFinder, findsNothing);
    });
  });
}
