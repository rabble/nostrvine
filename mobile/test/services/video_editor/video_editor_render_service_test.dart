// ABOUTME: Tests VideoEditorRenderService.buildImageLayers — the overlay-layer
// ABOUTME: scaling and editor→output timeline mapping applied at export.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Offset, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:pro_image_editor/pro_image_editor.dart' as pie;
import 'package:pro_video_editor/pro_video_editor.dart'
    show ClipTransition, ClipTransitionType, EditorVideo;

void main() {
  DivineVideoClip clip(
    String id,
    Duration duration, {
    ClipTransition? transition,
  }) => DivineVideoClip(
    id: id,
    video: EditorVideo.file('${Directory.systemTemp.path}/$id.mp4'),
    duration: duration,
    recordedAt: DateTime(2026),
    targetAspectRatio: model.AspectRatio.vertical,
    originalAspectRatio: 9 / 16,
    transition: transition,
  );

  pie.ExportedLayer layer({
    Duration? startTime,
    Duration? endTime,
    Offset offset = Offset.zero,
    Size logicalSize = const Size(10, 20),
  }) => pie.ExportedLayer(
    layer: pie.Layer(
      startTime: startTime,
      endTime: endTime,
      offset: offset,
    ),
    bytes: Uint8List.fromList(const [1, 2, 3]),
    logicalSize: logicalSize,
  );

  group('buildImageLayers', () {
    // Two 2s clips joined by a 400ms dissolve: an overlap removes its 400ms
    // blend, so the 4s editor timeline renders to a 3.6s output. The transition
    // is the outgoing transition of clip A (the a→b boundary).
    final overlapClips = [
      clip(
        'a',
        const Duration(seconds: 2),
        transition: const ClipTransition(
          type: ClipTransitionType.dissolve,
          duration: Duration(milliseconds: 400),
        ),
      ),
      clip('b', const Duration(seconds: 2)),
    ];
    final noTransitionClips = [
      clip('a', const Duration(seconds: 2)),
      clip('b', const Duration(seconds: 2)),
    ];

    test('returns null when there are no captured layers', () {
      expect(
        VideoEditorRenderService.buildImageLayers(
          capturedLayers: const [],
          bodySize: const Size(100, 200),
          videoSize: const Size(300, 600),
          timelineMap: TransitionTimelineMap.fromClips(noTransitionClips),
        ),
        isNull,
      );
    });

    test('returns null when bodySize is null', () {
      expect(
        VideoEditorRenderService.buildImageLayers(
          capturedLayers: [layer()],
          bodySize: null,
          videoSize: const Size(300, 600),
          timelineMap: TransitionTimelineMap.fromClips(noTransitionClips),
        ),
        isNull,
      );
    });

    test('scales offset and size from body space into video pixel space', () {
      // scale = videoWidth / bodyWidth = 300 / 100 = 3.
      final layers = VideoEditorRenderService.buildImageLayers(
        capturedLayers: [layer()],
        bodySize: const Size(100, 200),
        videoSize: const Size(300, 600),
        timelineMap: TransitionTimelineMap.fromClips(noTransitionClips),
      )!;

      final built = layers.single;
      // (bodyW/2 + dx - logicalW/2) * scale = (50 + 0 - 5) * 3 = 135.
      expect(built.offset, const Offset(135, 270));
      expect(built.size, const Size(30, 60));
    });

    test('passes layer times through unchanged when there is no overlap '
        'transition', () {
      final layers = VideoEditorRenderService.buildImageLayers(
        capturedLayers: [
          layer(startTime: Duration.zero, endTime: const Duration(seconds: 4)),
        ],
        bodySize: const Size(100, 200),
        videoSize: const Size(300, 600),
        timelineMap: TransitionTimelineMap.fromClips(noTransitionClips),
      )!;

      expect(layers.single.startTime, Duration.zero);
      expect(layers.single.endTime, const Duration(seconds: 4));
    });

    test('maps a full-length layer end onto the shorter output axis when an '
        'overlap transition compresses the timeline', () {
      final map = TransitionTimelineMap.fromClips(overlapClips);
      // Sanity: the overlap removes its 400ms blend from the 4s editor total.
      expect(map.outputDuration, const Duration(milliseconds: 3600));

      final layers = VideoEditorRenderService.buildImageLayers(
        capturedLayers: [
          // A full-length layer whose leave animation is anchored to the
          // editor-timeline end (4s).
          layer(startTime: Duration.zero, endTime: const Duration(seconds: 4)),
        ],
        bodySize: const Size(100, 200),
        videoSize: const Size(300, 600),
        timelineMap: map,
      )!;

      // The end must land on the real (shorter) video end, not 4s past it.
      expect(layers.single.startTime, Duration.zero);
      expect(layers.single.endTime, const Duration(milliseconds: 3600));
    });

    test('leaves null start/end times un-anchored', () {
      final layers = VideoEditorRenderService.buildImageLayers(
        capturedLayers: [layer()],
        bodySize: const Size(100, 200),
        videoSize: const Size(300, 600),
        timelineMap: TransitionTimelineMap.fromClips(overlapClips),
      )!;

      expect(layers.single.startTime, isNull);
      expect(layers.single.endTime, isNull);
    });
  });
}
