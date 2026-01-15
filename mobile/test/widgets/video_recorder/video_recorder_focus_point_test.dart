// ABOUTME: Tests for VideoRecorderFocusPoint widget
// ABOUTME: Validates focus point indicator, animations, and position calculations

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_focus_point.dart';

import '../../mocks/mock_camera_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoRecorderFocusPoint Widget Tests', () {
    late MockCameraService mockCamera;

    setUp(() async {
      mockCamera = MockCameraService.create(
        onUpdateState: ({forceCameraRebuild}) {},
        onAutoStopped: (_) {},
      );
      await mockCamera.initialize();
    });

    Widget buildTestWidget() {
      return ProviderScope(
        overrides: [
          videoRecorderProvider.overrideWith(
            () => VideoRecorderNotifier(mockCamera),
          ),
        ],
        child: MaterialApp(home: Scaffold(body: VideoRecorderFocusPoint())),
      );
    }

    testWidgets('renders focus point widget', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      expect(find.byType(VideoRecorderFocusPoint), findsOneWidget);
    });

    testWidgets('contains IgnorePointer to prevent touch interference', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      expect(
        find.descendant(
          of: find.byType(VideoRecorderFocusPoint),
          matching: find.byType(IgnorePointer),
        ),
        findsOneWidget,
      );
    });

    testWidgets('is initially invisible when focusPoint is zero', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );

      expect(animatedOpacity.opacity, equals(0.0));
    });

    testWidgets('renders focus point at correct position', (tester) async {
      final cameraSize = Size(400, 600);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoRecorderProvider.overrideWith(() {
              final notifier = VideoRecorderNotifier(mockCamera);
              // Set initial state with a focus point
              Future.microtask(() {
                notifier.state = notifier.state.copyWith(
                  focusPoint: Offset(0.5, 0.5),
                );
              });
              return notifier;
            }),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: cameraSize.width,
                height: cameraSize.height,
                child: VideoRecorderFocusPoint(),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Find the Positioned widget within VideoRecorderFocusPoint
      final positioned = tester.widget<Positioned>(
        find.descendant(
          of: find.byType(VideoRecorderFocusPoint),
          matching: find.byType(Positioned),
        ),
      );

      final indicatorSize = VideoRecorderFocusPoint.indicatorSize;

      expect(positioned.left, equals(cameraSize.width / 2 - indicatorSize / 2));
      expect(positioned.top, equals(cameraSize.height / 2 - indicatorSize / 2));
    });
  });
}
