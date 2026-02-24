// ABOUTME: Tests for VideoRecorderBottomBar widget
// ABOUTME: Validates bottom bar UI, record button, and control buttons

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_bottom_bar.dart';

import '../../mocks/mock_camera_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoRecorderBottomBar Widget Tests', () {
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
        child: MaterialApp(
          home: Scaffold(body: Stack(children: [VideoRecorderBottomBar()])),
        ),
      );
    }

    testWidgets('renders bottom bar widget', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(VideoRecorderBottomBar), findsOneWidget);
    });

    testWidgets('displays flash toggle button', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Flash button should be visible - check for SVG with flash icon path
      expect(
        find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == 'Toggle flash',
        ),
        findsOneWidget,
      );
    });

    testWidgets('displays timer toggle button', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Timer button should be visible
      expect(
        find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == 'Cycle timer',
        ),
        findsOneWidget,
      );
    });

    testWidgets('displays aspect ratio toggle button', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Aspect ratio button should be visible
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is IconButton && widget.tooltip == 'Toggle aspect ratio',
        ),
        findsOneWidget,
      );
    });

    testWidgets('displays camera flip button', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Camera flip button should be visible
      expect(
        find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == 'Switch camera',
        ),
        findsOneWidget,
      );
    });

    testWidgets('displays more options button', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // More options button should be visible
      expect(
        find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == 'More options',
        ),
        findsOneWidget,
      );
    });

    testWidgets('has 5 control buttons', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Flash, Timer, Aspect Ratio, Sound, Flip Camera, More Options
      expect(find.byType(IconButton), findsNWidgets(5));
    });

    testWidgets('uses SafeArea for bottom positioning', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(SafeArea), findsOneWidget);
    });

    testWidgets('contains Row with controls', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Should have a Row with control buttons
      final row = tester.widget<Row>(
        find.descendant(
          of: find.byType(VideoRecorderBottomBar),
          matching: find.byType(Row),
        ),
      );
      expect(row.mainAxisAlignment, equals(MainAxisAlignment.spaceAround));
    });
  });
}
