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
      // Set a specific recording duration
      mockCameraService.setRecordingDuration(const Duration(seconds: 8));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check that current values are displayed (may appear in multiple places)
      expect(find.text('8s'), findsAtLeastNWidgets(1));
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


    testWidgets('auto-stop switch toggles setting', (WidgetTester tester) async {
      // Start with auto-stop enabled (already default)
      
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

    testWidgets('preset buttons exist and are tappable', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Test that preset buttons exist
      expect(find.text('Vine Classic'), findsOneWidget);
      expect(find.text('Quick Snap'), findsOneWidget);
      expect(find.text('Extended'), findsOneWidget);
      expect(find.text('High Motion'), findsOneWidget);

      // Test that they are tappable
      await tester.tap(find.text('Vine Classic'));
      await tester.pumpAndSettle();
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

    testWidgets('current configuration info is displayed', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verify that configuration info section exists
      expect(find.text('Current Configuration'), findsOneWidget);
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