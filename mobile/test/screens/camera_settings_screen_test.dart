// ABOUTME: Widget tests for camera settings screen UI and functionality
// ABOUTME: Tests settings navigation, configuration updates, and preset buttons

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:openvine/screens/camera_settings_screen.dart';
import 'package:openvine/services/camera_service.dart';

void main() {
  group('CameraSettingsScreen', () {
    late CameraService mockCameraService;

    setUp(() {
      mockCameraService = CameraService();
    });

    tearDown(() {
      mockCameraService.dispose();
    });

    Widget createTestWidget() {
      return MaterialApp(
        home: ChangeNotifierProvider<CameraService>.value(
          value: mockCameraService,
          child: const CameraSettingsScreen(),
        ),
      );
    }

    testWidgets('displays settings screen with all sections', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check for main sections (some may appear multiple times, so use findsAtLeastNWidgets)
      expect(find.text('Camera Settings'), findsOneWidget);
      expect(find.text('Recording Duration'), findsAtLeastNWidgets(1));
      expect(find.text('Frame Rate'), findsAtLeastNWidgets(1));
      expect(find.text('Recording Options'), findsOneWidget);
      expect(find.text('Quality Settings'), findsOneWidget);
      expect(find.text('Quick Presets'), findsOneWidget);
      expect(find.text('Current Configuration'), findsOneWidget);
    });

    testWidgets('displays current configuration values', (WidgetTester tester) async {
      // Set a specific configuration
      mockCameraService.useVineConfiguration(
        duration: const Duration(seconds: 8),
        fps: 7.0,
        autoStop: true,
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check that current values are displayed (may appear in multiple places)
      expect(find.text('8s'), findsAtLeastNWidgets(1));
      expect(find.text('7.0 FPS'), findsAtLeastNWidgets(1));
      expect(find.text('56 frames'), findsAtLeastNWidgets(1)); // 8 * 7
    });

    testWidgets('duration slider updates configuration', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find the duration slider
      final durationSlider = find.byType(Slider).first;
      expect(durationSlider, findsOneWidget);

      // Slide to a new value (10 seconds)
      await tester.drag(durationSlider, const Offset(100, 0));
      await tester.pumpAndSettle();

      // Verify the configuration was updated
      expect(mockCameraService.maxVineDuration.inSeconds, greaterThan(6));
    });

    testWidgets('frame rate slider updates configuration', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find the frame rate slider (second slider)
      final frameRateSlider = find.byType(Slider).last;
      expect(frameRateSlider, findsOneWidget);

      // Slide to a new value
      await tester.drag(frameRateSlider, const Offset(50, 0));
      await tester.pumpAndSettle();

      // Verify the configuration was updated
      expect(mockCameraService.targetFPS, greaterThan(5.0));
    });

    testWidgets('auto-stop switch toggles setting', (WidgetTester tester) async {
      // Start with auto-stop enabled
      mockCameraService.useVineConfiguration(autoStop: true);
      
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find and tap the switch
      final autoStopSwitch = find.byType(Switch);
      expect(autoStopSwitch, findsOneWidget);
      
      await tester.tap(autoStopSwitch);
      await tester.pumpAndSettle();

      // Verify auto-stop was disabled
      expect(mockCameraService.enableAutoStop, false);
    });

    testWidgets('preset buttons update configuration', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Test Vine Classic preset
      await tester.tap(find.text('Vine Classic'));
      await tester.pumpAndSettle();

      expect(mockCameraService.maxVineDuration, const Duration(seconds: 6));
      expect(mockCameraService.targetFPS, 5.0);

      // Test Quick Snap preset
      await tester.tap(find.text('Quick Snap'));
      await tester.pumpAndSettle();

      expect(mockCameraService.maxVineDuration, const Duration(seconds: 3));
      expect(mockCameraService.targetFPS, 8.0);

      // Test Extended preset
      await tester.tap(find.text('Extended'));
      await tester.pumpAndSettle();

      expect(mockCameraService.maxVineDuration, const Duration(seconds: 12));
      expect(mockCameraService.targetFPS, 4.0);

      // Test High Motion preset
      await tester.tap(find.text('High Motion'));
      await tester.pumpAndSettle();

      expect(mockCameraService.maxVineDuration, const Duration(seconds: 8));
      expect(mockCameraService.targetFPS, 10.0);
    });

    testWidgets('quality buttons show selection feedback', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Test quality selection (currently just shows snackbar)
      await tester.tap(find.text('High'));
      await tester.pumpAndSettle();

      // Should show snackbar with selection
      expect(find.text('High quality selected'), findsOneWidget);
    });

    testWidgets('current configuration info updates with changes', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Change configuration using preset
      await tester.tap(find.text('High Motion'));
      await tester.pumpAndSettle();

      // Verify info section shows updated values (may appear in multiple places)
      expect(find.text('8s'), findsAtLeastNWidgets(1)); // duration
      expect(find.text('10.0 FPS'), findsAtLeastNWidgets(1)); // fps
      expect(find.text('80 frames'), findsAtLeastNWidgets(1)); // 8 * 10
      expect(find.text('Enabled'), findsAtLeastNWidgets(1)); // auto-stop
    });

    testWidgets('settings screen has app bar with title', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verify the app bar and title exist
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Camera Settings'), findsOneWidget);
    });
  });
}