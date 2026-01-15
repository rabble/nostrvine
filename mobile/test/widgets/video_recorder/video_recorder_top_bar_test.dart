// ABOUTME: Tests for VideoRecorderTopBar widget
// ABOUTME: Validates top bar UI, close button, and confirm button

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:openvine/widgets/divine_icon_button.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_segment_bar.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_top_bar.dart';

import '../../mocks/mock_camera_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoRecorderTopBar Widget Tests', () {
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
          home: Scaffold(body: Stack(children: [VideoRecorderTopBar()])),
        ),
      );
    }

    testWidgets('renders top bar widget', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(VideoRecorderTopBar), findsOneWidget);
    });

    testWidgets('contains close button', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is DivineIconButton &&
              widget.semanticLabel == 'Close video recorder',
        ),
        findsOneWidget,
      );
    });

    testWidgets('contains segment bar', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(VideoRecorderSegmentBar), findsOneWidget);
    });

    testWidgets('is positioned at top of screen', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final positioned = tester.widget<Positioned>(
        find.byType(Positioned).first,
      );

      expect(positioned.top, equals(0));
      expect(positioned.left, equals(0));
      expect(positioned.right, equals(0));
    });

    testWidgets('uses SafeArea for status bar', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(SafeArea), findsOneWidget);
    });
  });
}
