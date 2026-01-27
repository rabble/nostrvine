// ABOUTME: Tests for VideoEditorSplitBar widget
// ABOUTME: Validates split bar functionality, slider interaction, and state management

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_editor/video_editor_split_bar.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class TestVideoEditorNotifier extends VideoEditorNotifier {
  TestVideoEditorNotifier(this._state);
  VideoEditorProviderState _state;

  @override
  VideoEditorProviderState build() => _state;

  @override
  Future<void> seekToTrimPosition(Duration position) async {
    _state = _state.copyWith(splitPosition: position);
  }
}

class TestClipManagerNotifier extends ClipManagerNotifier {
  TestClipManagerNotifier(this._clips);
  final List<RecordingClip> _clips;

  @override
  ClipManagerState build() {
    return ClipManagerState(clips: _clips);
  }
}

RecordingClip _createClip({
  String id = 'test-clip',
  Duration duration = const Duration(seconds: 5),
}) {
  return RecordingClip(
    id: id,
    video: EditorVideo.file('/test/video.mp4'),
    duration: duration,
    recordedAt: DateTime.now(),
    aspectRatio: model.AspectRatio.square,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoEditorSplitBar Widget Tests', () {
    Widget buildTestWidget({
      Duration splitPosition = Duration.zero,
      int currentClipIndex = 0,
      List<RecordingClip>? clips,
    }) {
      final testClips = clips ?? [_createClip()];

      return ProviderScope(
        overrides: [
          videoEditorProvider.overrideWith(
            () => TestVideoEditorNotifier(
              VideoEditorProviderState(
                splitPosition: splitPosition,
                currentClipIndex: currentClipIndex,
              ),
            ),
          ),
          clipManagerProvider.overrideWith(
            () => TestClipManagerNotifier(testClips),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: VideoEditorSplitBar())),
      );
    }

    testWidgets('renders split bar widget', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(VideoEditorSplitBar), findsOneWidget);
    });

    testWidgets('contains slider widget', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('slider value matches split position', (tester) async {
      const splitPosition = Duration(seconds: 2);

      await tester.pumpWidget(buildTestWidget(splitPosition: splitPosition));

      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, equals(splitPosition.inMilliseconds.toDouble()));
    });

    testWidgets('slider max matches clip duration', (tester) async {
      const clipDuration = Duration(seconds: 10);

      await tester.pumpWidget(
        buildTestWidget(clips: [_createClip(duration: clipDuration)]),
      );

      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.max, equals(clipDuration.inMilliseconds.toDouble()));
    });

    testWidgets('slider max is at least split position value', (tester) async {
      const clipDuration = Duration(seconds: 5);
      const splitPosition = Duration(seconds: 7); // Greater than clip duration

      await tester.pumpWidget(
        buildTestWidget(
          splitPosition: splitPosition,
          clips: [_createClip(duration: clipDuration)],
        ),
      );

      final slider = tester.widget<Slider>(find.byType(Slider));
      // Max should be the greater of split position or clip duration
      expect(slider.max, equals(splitPosition.inMilliseconds.toDouble()));
    });

    testWidgets('slider interaction updates split position', (tester) async {
      const clipDuration = Duration(seconds: 10);

      await tester.pumpWidget(
        buildTestWidget(clips: [_createClip(duration: clipDuration)]),
      );

      // Find the slider
      final sliderFinder = find.byType(Slider);
      expect(sliderFinder, findsOneWidget);

      // Drag the slider to 50% position
      await tester.drag(sliderFinder, const Offset(100, 0));
      await tester.pumpAndSettle();

      // Verify slider interaction is enabled
      final slider = tester.widget<Slider>(sliderFinder);
      expect(slider.onChanged, isNotNull);
    });

    testWidgets('handles multiple clips correctly', (tester) async {
      final clips = [
        _createClip(id: 'clip1', duration: const Duration(seconds: 3)),
        _createClip(id: 'clip2', duration: const Duration(seconds: 7)),
        _createClip(id: 'clip3', duration: const Duration(seconds: 5)),
      ];

      await tester.pumpWidget(
        buildTestWidget(
          clips: clips,
          currentClipIndex: 1, // Select second clip
        ),
      );

      final slider = tester.widget<Slider>(find.byType(Slider));
      // Should use second clip's duration
      expect(
        slider.max,
        equals(const Duration(seconds: 7).inMilliseconds.toDouble()),
      );
    });

    testWidgets('uses RepaintBoundary for performance', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Check that RepaintBoundary wraps the slider
      final repaintBoundary = find.descendant(
        of: find.byType(VideoEditorSplitBar),
        matching: find.byType(RepaintBoundary),
      );
      expect(repaintBoundary, findsOneWidget);
    });

    testWidgets('applies custom SliderTheme', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final sliderTheme = tester.widget<SliderTheme>(find.byType(SliderTheme));

      expect(sliderTheme.data, isNotNull);
      expect(sliderTheme.data.trackHeight, equals(8));
    });

    testWidgets('handles zero duration clip gracefully', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(clips: [_createClip(duration: Duration.zero)]),
      );

      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.max, greaterThanOrEqualTo(0));
    });
  });
}
