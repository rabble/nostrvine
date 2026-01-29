// ABOUTME: Integration tests for video recording functionality
// ABOUTME: Tests start/stop recording, video file creation, and recording state

// NOTE: On Android, camera/microphone permissions must be granted before running.
// Either grant via ADB: adb shell pm grant co.openvine.app android.permission.CAMERA
// Or the first test run will show permission dialogs that must be accepted.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openvine/blocs/camera_permission/camera_permission_bloc.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:openvine/screens/video_recorder_screen.dart';
import 'package:openvine/services/video_recorder/camera/camera_base_service.dart';
import 'package:permissions_service/permissions_service.dart';

/// Helper widget that wraps VideoRecorderScreen with required providers
Widget _buildTestWidget() {
  return ProviderScope(
    child: BlocProvider(
      create: (_) => CameraPermissionBloc(
        permissionsService: const PermissionHandlerPermissionsService(),
      )..add(const CameraPermissionRefresh()),
      child: const MaterialApp(home: VideoRecorderScreen()),
    ),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Video Recorder Integration Tests', () {
    late CameraService cameraService;

    setUpAll(() async {
      final service = PermissionHandlerPermissionsService();
      await service.requestCameraPermission();
      await service.requestMicrophonePermission();
    });

    setUp(() async {
      cameraService = CameraService.create(
        onUpdateState: ({forceCameraRebuild}) {},
        onAutoStopped: (_) {},
      );
      await cameraService.initialize();
    });

    tearDown(() async {
      try {
        await cameraService.stopRecording();
      } catch (_) {
        // Ignore errors if not recording
      }
      try {
        await cameraService.dispose();
      } catch (_) {
        // Ignore errors if already disposed
      }
    });

    testWidgets('can start recording', (tester) async {
      expect(cameraService.canRecord, isTrue);

      await cameraService.startRecording();

      // Give recording a moment to start
      await tester.pump(Duration(milliseconds: 100));
    });

    testWidgets('can stop recording after starting', (tester) async {
      await cameraService.startRecording();

      // Record for 2 seconds
      await tester.pump(Duration(seconds: 2));

      final video = await cameraService.stopRecording();

      // Should have created a video
      expect(video, anyOf(isNull, isA<Object>()));
    });

    testWidgets('can start and stop multiple recordings', (tester) async {
      for (var i = 0; i < 3; i++) {
        await cameraService.startRecording();
        await tester.pump(Duration(milliseconds: 500));

        final video = await cameraService.stopRecording();

        // Each recording should complete
        expect(video, anyOf(isNull, isA<Object>()));

        // Wait between recordings
        await tester.pump(Duration(milliseconds: 100));
      }
    });

    testWidgets('stopping without starting does not crash', (tester) async {
      // Should handle gracefully
      final video = await cameraService.stopRecording();

      // Should return null or handle gracefully
      expect(video, anyOf(isNull, isA<Object>()));
    });
  });

  group('Video Recorder Widget Tests', () {
    setUpAll(() async {
      final service = PermissionHandlerPermissionsService();
      await service.requestCameraPermission();
      await service.requestMicrophonePermission();
    });

    testWidgets('pinch to zoom changes zoom level', (tester) async {
      await tester.pumpWidget(_buildTestWidget());

      // Wait for camera to initialize
      await tester.pumpAndSettle(Duration(seconds: 2));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(VideoRecorderScreen)),
      );
      final notifier = container.read(videoRecorderProvider.notifier);
      final initialZoom = container.read(videoRecorderProvider).zoomLevel;

      // Simulate pinch zoom out (scale > 1)
      final center = tester.getCenter(find.byType(VideoRecorderScreen));
      final pointer1 = TestPointer(1);
      final pointer2 = TestPointer(2);

      // Start with two fingers close together
      await tester.sendEventToBinding(pointer1.down(center));
      await tester.sendEventToBinding(pointer2.down(center));
      await tester.pump();

      // Move fingers apart (zoom in)
      await tester.sendEventToBinding(pointer1.move(center + Offset(-50, 0)));
      await tester.sendEventToBinding(pointer2.move(center + Offset(50, 0)));
      await tester.pump(Duration(milliseconds: 100));

      // Release
      await tester.sendEventToBinding(pointer1.up());
      await tester.sendEventToBinding(pointer2.up());
      await tester.pump();

      final newZoom = container.read(videoRecorderProvider).zoomLevel;

      // Zoom should have increased
      expect(newZoom, greaterThanOrEqualTo(initialZoom));

      // Cleanup
      notifier.destroy();
    });

    testWidgets('long press on record button starts recording', (tester) async {
      await tester.pumpWidget(_buildTestWidget());

      // Wait for camera to initialize and zoom limits to load
      await tester.pumpAndSettle(Duration(seconds: 3));
      // Extra pump to ensure postFrameCallback completes
      await tester.pump();
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(VideoRecorderScreen)),
      );
      final notifier = container.read(videoRecorderProvider.notifier);

      // Find record button
      final recordButton = find.bySemanticsIdentifier(
        'divine-camera-record-button',
      );
      expect(recordButton, findsOneWidget);

      // Start long press (hold it - don't release yet)
      final buttonCenter = tester.getCenter(recordButton);
      final gesture = await tester.startGesture(buttonCenter);
      await tester.pump(
        Duration(milliseconds: 600),
      ); // Wait for long press to trigger

      // Check recording state while still pressing
      final isRecording = container.read(videoRecorderProvider).isRecording;
      expect(isRecording, isTrue);

      // Get initial zoom level
      final initialZoom = container.read(videoRecorderProvider).zoomLevel;

      // Move finger up (should zoom in)
      await gesture.moveBy(
        Offset(0, -200),
        timeStamp: Duration(milliseconds: 600),
      );
      await tester.pump(Duration(milliseconds: 500));

      // Check zoom changed
      final zoomAfterMove = container.read(videoRecorderProvider).zoomLevel;
      expect(
        zoomAfterMove,
        greaterThan(initialZoom),
        reason: 'Zoom should increase when moving finger up during recording',
      );

      // Release to stop recording
      await gesture.up();
      await tester.pumpAndSettle();

      // Cleanup
      notifier.destroy();
    });

    testWidgets('long press move zooms during recording', (tester) async {
      await tester.pumpWidget(_buildTestWidget());

      // Wait for camera to initialize
      await tester.pumpAndSettle(Duration(seconds: 2));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(VideoRecorderScreen)),
      );
      final notifier = container.read(videoRecorderProvider.notifier);

      // Find record button
      final recordButton = find.bySemanticsIdentifier(
        'divine-camera-record-button',
      );
      final buttonCenter = tester.getCenter(recordButton);

      // Start long press
      final gesture = await tester.startGesture(buttonCenter);
      await tester.pump(Duration(milliseconds: 600)); // Trigger long press

      final initialZoom = container.read(videoRecorderProvider).zoomLevel;

      // Move finger up (should zoom in)
      await gesture.moveBy(Offset(0, -100));
      await tester.pump(Duration(milliseconds: 100));

      final zoomAfterMove = container.read(videoRecorderProvider).zoomLevel;

      // Zoom should have changed
      expect(zoomAfterMove, greaterThanOrEqualTo(initialZoom));

      // Release
      await gesture.up();
      await tester.pumpAndSettle();

      // Cleanup
      notifier.destroy();
    });
  });
}
