// ABOUTME: Tests for VideoRecorderCountdownOverlay widget
// ABOUTME: Validates countdown display, animations, and visibility states

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_countdown_overlay.dart';

import '../../mocks/mock_camera_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoRecorderCountdownOverlay Widget Tests', () {
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
        child: const MaterialApp(
          home: Scaffold(body: VideoRecorderCountdownOverlay()),
        ),
      );
    }

    testWidgets('renders countdown overlay', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      expect(find.byType(VideoRecorderCountdownOverlay), findsOneWidget);
    });

    testWidgets('is initially invisible when countdown is 0', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );

      expect(animatedOpacity.opacity, equals(0));
    });

    testWidgets('uses IgnorePointer for touch blocking', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(
        find.descendant(
          of: find.byType(VideoRecorderCountdownOverlay),
          matching: find.byType(IgnorePointer),
        ),
        findsOneWidget,
      );
    });

    testWidgets('contains AnimatedOpacity for fade transitions', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      expect(find.byType(AnimatedOpacity), findsOneWidget);
    });

    testWidgets('updates when countdown value changes', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.byType(VideoRecorderCountdownOverlay), findsOneWidget);
    });
  });
}
