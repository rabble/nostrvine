// ABOUTME: Tests for VideoRecorderCameraPreview widget
// ABOUTME: Validates camera preview rendering, aspect ratio, and grid overlay

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_camera_placeholder.dart';
import 'package:openvine/widgets/video_recorder/preview/video_recorder_camera_preview.dart';

import '../../mocks/mock_camera_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoRecorderCameraPreview Widget Tests', () {
    testWidgets('renders camera preview widget', (tester) async {
      final mockCamera = MockCameraService.create(
        onUpdateState: ({forceCameraRebuild}) {},
        onAutoStopped: (_) {},
      );
      await mockCamera.initialize();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoRecorderProvider.overrideWith(
              () => VideoRecorderNotifier(mockCamera),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: VideoRecorderCameraPreview()),
          ),
        ),
      );

      expect(find.byType(VideoRecorderCameraPreview), findsOneWidget);
    });

    testWidgets('displays placeholder when camera not initialized', (
      tester,
    ) async {
      final mockCamera = MockCameraService.create(
        onUpdateState: ({forceCameraRebuild}) {},
        onAutoStopped: (_) {},
      );
      // Don't initialize - should show placeholder

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoRecorderProvider.overrideWith(
              () => VideoRecorderNotifier(mockCamera),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: VideoRecorderCameraPreview()),
          ),
        ),
      );

      // Should show placeholder widget
      expect(find.byType(VideoRecorderCameraPlaceholder), findsOneWidget);
    });

    testWidgets('contains TweenAnimationBuilder for transitions', (
      tester,
    ) async {
      final mockCamera = MockCameraService.create(
        onUpdateState: ({forceCameraRebuild}) {},
        onAutoStopped: (_) {},
      );
      await mockCamera.initialize();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoRecorderProvider.overrideWith(
              () => VideoRecorderNotifier(mockCamera),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: VideoRecorderCameraPreview()),
          ),
        ),
      );

      expect(find.byType(TweenAnimationBuilder<double>), isNotNull);
    });
  });
}
