// ABOUTME: Widget tests for VideoClipEditorProgressBar widget
// ABOUTME: Tests progress bar segments, colors, and animations

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_clip_editor/video_clip_editor_progress_bar.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group('VideoClipEditorProgressBar Widget Tests', () {
    testWidgets('displays progress bar with correct number of segments', (
      tester,
    ) async {
      final clips = List.generate(
        3,
        (i) => RecordingClip(
          id: 'clip$i',
          video: EditorVideo.file('/test/clip$i.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          aspectRatio: .vertical,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clipManagerProvider.overrideWith(
              () => TestClipManagerNotifier(ClipManagerState(clips: clips)),
            ),
            videoEditorProvider.overrideWith(
              () => TestVideoEditorNotifier(VideoEditorProviderState()),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: VideoClipEditorProgressBar()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Progress bar should be present
      expect(find.byType(VideoClipEditorProgressBar), findsOneWidget);

      // Row should have 3 Expanded widgets (one per clip)
      final row = tester.widget<Row>(find.byType(Row));
      expect(row.children.whereType<Expanded>().length, 3);
    });

    testWidgets('segments have proportional widths based on clip duration', (
      tester,
    ) async {
      final clips = [
        RecordingClip(
          id: 'clip1',
          video: EditorVideo.file('/test/clip1.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          aspectRatio: .vertical,
        ),
        RecordingClip(
          id: 'clip2',
          video: EditorVideo.file('/test/clip2.mp4'),
          duration: const Duration(seconds: 4),
          recordedAt: DateTime.now(),
          aspectRatio: .vertical,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clipManagerProvider.overrideWith(
              () => TestClipManagerNotifier(ClipManagerState(clips: clips)),
            ),
            videoEditorProvider.overrideWith(
              () => TestVideoEditorNotifier(VideoEditorProviderState()),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: VideoClipEditorProgressBar()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Expanded widgets have correct flex values
      final expandedWidgets = tester
          .widgetList<Expanded>(find.byType(Expanded))
          .toList();
      expect(expandedWidgets[0].flex, 2000); // 2 seconds = 2000ms
      expect(expandedWidgets[1].flex, 4000); // 4 seconds = 4000ms
    });

    testWidgets('completed clips show green color', (tester) async {
      final clips = List.generate(
        3,
        (i) => RecordingClip(
          id: 'clip$i',
          video: EditorVideo.file('/test/clip$i.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          aspectRatio: .vertical,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clipManagerProvider.overrideWith(
              () => TestClipManagerNotifier(ClipManagerState(clips: clips)),
            ),
            videoEditorProvider.overrideWith(
              () => TestVideoEditorNotifier(
                VideoEditorProviderState(currentClipIndex: 2),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: VideoClipEditorProgressBar()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Get all AnimatedContainers
      final containers = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .toList();

      // First two clips should be green (completed)
      final firstClipDecoration = containers[0].decoration as BoxDecoration?;
      final secondClipDecoration = containers[1].decoration as BoxDecoration?;
      expect(firstClipDecoration?.color, const Color(0xFF146346));
      expect(secondClipDecoration?.color, const Color(0xFF146346));

      // Current clip (index 2) should be gray
      final currentClipDecoration = containers[2].decoration as BoxDecoration?;
      expect(currentClipDecoration?.color, const Color(0xFF404040));
    });

    testWidgets('reordering clip shows special styling', (tester) async {
      final clips = [
        RecordingClip(
          id: 'clip1',
          video: EditorVideo.file('/test/clip1.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          aspectRatio: .vertical,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clipManagerProvider.overrideWith(
              () => TestClipManagerNotifier(ClipManagerState(clips: clips)),
            ),
            videoEditorProvider.overrideWith(
              () => TestVideoEditorNotifier(
                VideoEditorProviderState(isReordering: true),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: VideoClipEditorProgressBar()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Get the AnimatedContainer
      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer).first,
      );
      final decoration = container.decoration as BoxDecoration?;

      // Should have green color
      expect(decoration?.color, const Color(0xFF27C58B));

      // Should have yellow border
      expect(decoration?.border, isNotNull);
      final border = decoration?.border as Border?;
      expect(border?.top.color, const Color(0xFFEBDE3B));
      expect(border?.top.width, 3);
    });

    testWidgets('displays progress overlay on current clip', (tester) async {
      final clips = [
        RecordingClip(
          id: 'clip1',
          video: EditorVideo.file('/test/clip1.mp4'),
          duration: const Duration(seconds: 10),
          recordedAt: DateTime.now(),
          aspectRatio: .vertical,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clipManagerProvider.overrideWith(
              () => TestClipManagerNotifier(ClipManagerState(clips: clips)),
            ),
            videoEditorProvider.overrideWith(
              () => TestVideoEditorNotifier(
                VideoEditorProviderState(currentPosition: Duration(seconds: 5)),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: VideoClipEditorProgressBar()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // FractionallySizedBox should be present for progress overlay
      expect(find.byType(FractionallySizedBox), findsOneWidget);

      // Verify it's 50% of the clip (5s / 10s = 0.5)
      final fractionalBox = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(fractionalBox.widthFactor, 0.5);
    });

    testWidgets('first and last segments have rounded corners', (tester) async {
      final clips = [
        RecordingClip(
          id: 'clip1',
          video: EditorVideo.file('/test/clip1.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          aspectRatio: .vertical,
        ),
        RecordingClip(
          id: 'clip2',
          video: EditorVideo.file('/test/clip2.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          aspectRatio: .vertical,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clipManagerProvider.overrideWith(
              () => TestClipManagerNotifier(ClipManagerState(clips: clips)),
            ),
            videoEditorProvider.overrideWith(
              () => TestVideoEditorNotifier(VideoEditorProviderState()),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: VideoClipEditorProgressBar()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final containers = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .toList();

      // First segment should have left rounded corners
      final firstDecoration = containers[0].decoration as BoxDecoration?;
      final firstBorderRadius = firstDecoration?.borderRadius as BorderRadius?;
      expect(firstBorderRadius?.topLeft, const Radius.circular(999));
      expect(firstBorderRadius?.bottomLeft, const Radius.circular(999));

      // Last segment should have right rounded corners
      final lastDecoration = containers[1].decoration as BoxDecoration?;
      final lastBorderRadius = lastDecoration?.borderRadius as BorderRadius?;
      expect(lastBorderRadius?.topRight, const Radius.circular(999));
      expect(lastBorderRadius?.bottomRight, const Radius.circular(999));
    });
  });
}

class TestVideoEditorNotifier extends VideoEditorNotifier {
  TestVideoEditorNotifier(this._state);
  final VideoEditorProviderState _state;

  @override
  VideoEditorProviderState build() => _state;
}

class TestClipManagerNotifier extends ClipManagerNotifier {
  TestClipManagerNotifier(this._state);
  final ClipManagerState _state;

  @override
  ClipManagerState build() => _state;
}
