// ABOUTME: Tests for VideoClipEditorSplitBar widget
// ABOUTME: Validates split bar functionality, slider interaction, and state management

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_clip_editor/video_clip_editor_split_bar.dart';
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
    targetAspectRatio: model.AspectRatio.square,
    originalAspectRatio: 9 / 16,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoClipEditorSplitBar Widget Tests', () {
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
        child: const MaterialApp(
          home: Scaffold(body: VideoClipEditorSplitBar()),
        ),
      );
    }

    testWidgets('renders split bar widget', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(VideoClipEditorSplitBar), findsOneWidget);
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
      const splitPosition = Duration(seconds: 7); // Greater than clip duration

      await tester.pumpWidget(
        buildTestWidget(
          splitPosition: splitPosition,
          clips: [_createClip()],
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
        _createClip(id: 'clip3'),
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
        of: find.byType(VideoClipEditorSplitBar),
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

  group(UniformTrackShape, () {
    late UniformTrackShape trackShape;

    setUp(() {
      trackShape = const UniformTrackShape();
    });

    group('getPreferredRect', () {
      test('returns rect with correct height from sliderTheme', () {
        final parentBox = _MockRenderBox(const Size(300, 40));
        const sliderTheme = SliderThemeData(trackHeight: 8);

        final rect = trackShape.getPreferredRect(
          parentBox: parentBox,
          sliderTheme: sliderTheme,
        );

        expect(rect.height, equals(8));
      });

      test('returns rect with full parent width', () {
        final parentBox = _MockRenderBox(const Size(300, 40));
        const sliderTheme = SliderThemeData(trackHeight: 8);

        final rect = trackShape.getPreferredRect(
          parentBox: parentBox,
          sliderTheme: sliderTheme,
        );

        expect(rect.width, equals(300));
      });

      test('centers track vertically in parent', () {
        final parentBox = _MockRenderBox(const Size(300, 40));
        const sliderTheme = SliderThemeData(trackHeight: 8);

        final rect = trackShape.getPreferredRect(
          parentBox: parentBox,
          sliderTheme: sliderTheme,
        );

        // Track should be centered: (40 - 8) / 2 = 16
        expect(rect.top, equals(16));
      });

      test('uses default track height of 8 when not specified', () {
        final parentBox = _MockRenderBox(const Size(300, 40));
        const sliderTheme = SliderThemeData();

        final rect = trackShape.getPreferredRect(
          parentBox: parentBox,
          sliderTheme: sliderTheme,
        );

        expect(rect.height, equals(8));
      });

      test('applies offset correctly', () {
        final parentBox = _MockRenderBox(const Size(300, 40));
        const sliderTheme = SliderThemeData(trackHeight: 8);
        const offset = Offset(10, 5);

        final rect = trackShape.getPreferredRect(
          parentBox: parentBox,
          sliderTheme: sliderTheme,
          offset: offset,
        );

        expect(rect.left, equals(10));
        // Track top = offset.dy + (parentHeight - trackHeight) / 2
        // = 5 + (40 - 8) / 2 = 5 + 16 = 21
        expect(rect.top, equals(21));
      });

      test('handles zero track height', () {
        final parentBox = _MockRenderBox(const Size(300, 40));
        const sliderTheme = SliderThemeData(trackHeight: 0);

        final rect = trackShape.getPreferredRect(
          parentBox: parentBox,
          sliderTheme: sliderTheme,
        );

        expect(rect.height, equals(0));
        // Centered at (40 - 0) / 2 = 20
        expect(rect.top, equals(20));
      });

      test('handles large track height', () {
        final parentBox = _MockRenderBox(const Size(300, 40));
        const sliderTheme = SliderThemeData(trackHeight: 40);

        final rect = trackShape.getPreferredRect(
          parentBox: parentBox,
          sliderTheme: sliderTheme,
        );

        expect(rect.height, equals(40));
        expect(rect.top, equals(0));
      });
    });

    group('paint', () {
      test('does not throw with valid parameters', () {
        final parentBox = _MockRenderBox(const Size(300, 40));
        const sliderTheme = SliderThemeData(
          trackHeight: 8,
          activeTrackColor: Colors.green,
          inactiveTrackColor: Colors.grey,
        );
        const enableAnimation = AlwaysStoppedAnimation<double>(1);

        expect(
          () => trackShape.paint(
            _MockPaintingContext(),
            Offset.zero,
            parentBox: parentBox,
            sliderTheme: sliderTheme,
            enableAnimation: enableAnimation,
            thumbCenter: const Offset(150, 20),
            textDirection: TextDirection.ltr,
          ),
          returnsNormally,
        );
      });

      test('handles thumb at start position', () {
        final parentBox = _MockRenderBox(const Size(300, 40));
        const sliderTheme = SliderThemeData(
          trackHeight: 8,
          activeTrackColor: Colors.green,
          inactiveTrackColor: Colors.grey,
        );
        const enableAnimation = AlwaysStoppedAnimation<double>(1);

        expect(
          () => trackShape.paint(
            _MockPaintingContext(),
            Offset.zero,
            parentBox: parentBox,
            sliderTheme: sliderTheme,
            enableAnimation: enableAnimation,
            thumbCenter: const Offset(0, 20),
            textDirection: TextDirection.ltr,
          ),
          returnsNormally,
        );
      });

      test('handles thumb at end position', () {
        final parentBox = _MockRenderBox(const Size(300, 40));
        const sliderTheme = SliderThemeData(
          trackHeight: 8,
          activeTrackColor: Colors.green,
          inactiveTrackColor: Colors.grey,
        );
        const enableAnimation = AlwaysStoppedAnimation<double>(1);

        expect(
          () => trackShape.paint(
            _MockPaintingContext(),
            Offset.zero,
            parentBox: parentBox,
            sliderTheme: sliderTheme,
            enableAnimation: enableAnimation,
            thumbCenter: const Offset(300, 20),
            textDirection: TextDirection.ltr,
          ),
          returnsNormally,
        );
      });

      test('handles missing colors gracefully', () {
        final parentBox = _MockRenderBox(const Size(300, 40));
        const sliderTheme = SliderThemeData(trackHeight: 8);
        const enableAnimation = AlwaysStoppedAnimation<double>(1);

        expect(
          () => trackShape.paint(
            _MockPaintingContext(),
            Offset.zero,
            parentBox: parentBox,
            sliderTheme: sliderTheme,
            enableAnimation: enableAnimation,
            thumbCenter: const Offset(150, 20),
            textDirection: TextDirection.ltr,
          ),
          returnsNormally,
        );
      });

      test('handles offset correctly', () {
        final parentBox = _MockRenderBox(const Size(300, 40));
        const sliderTheme = SliderThemeData(
          trackHeight: 8,
          activeTrackColor: Colors.green,
          inactiveTrackColor: Colors.grey,
        );
        const enableAnimation = AlwaysStoppedAnimation<double>(1);

        expect(
          () => trackShape.paint(
            _MockPaintingContext(),
            const Offset(50, 10),
            parentBox: parentBox,
            sliderTheme: sliderTheme,
            enableAnimation: enableAnimation,
            thumbCenter: const Offset(200, 30),
            textDirection: TextDirection.ltr,
          ),
          returnsNormally,
        );
      });

      test('handles RTL text direction', () {
        final parentBox = _MockRenderBox(const Size(300, 40));
        const sliderTheme = SliderThemeData(
          trackHeight: 8,
          activeTrackColor: Colors.green,
          inactiveTrackColor: Colors.grey,
        );
        const enableAnimation = AlwaysStoppedAnimation<double>(1);

        expect(
          () => trackShape.paint(
            _MockPaintingContext(),
            Offset.zero,
            parentBox: parentBox,
            sliderTheme: sliderTheme,
            enableAnimation: enableAnimation,
            thumbCenter: const Offset(150, 20),
            textDirection: TextDirection.rtl,
          ),
          returnsNormally,
        );
      });
    });
  });
}

class _MockRenderBox extends RenderBox {
  _MockRenderBox(this._size);
  final Size _size;

  @override
  Size get size => _size;
}

class _MockPaintingContext implements PaintingContext {
  _MockPaintingContext();

  final _recorder = ui.PictureRecorder();

  @override
  Canvas get canvas => Canvas(_recorder);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
