// ABOUTME: Tests for VideoRecorderTopBar widget
// ABOUTME: Validates top bar UI, close button, and confirm button

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
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

      expect(find.bySemanticsLabel('Close video recorder'), findsOneWidget);
    });

    testWidgets('contains next button when hasClips', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Pump to allow AnimatedSwitcher to finish
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Continue to video editor'), findsOneWidget);
    });

    testWidgets('is aligned at top center', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final align = tester.widget<Align>(find.byType(Align).first);

      expect(align.alignment, equals(Alignment.topCenter));
    });

    testWidgets('uses SafeArea for status bar', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(SafeArea), findsOneWidget);
    });
  });
}
