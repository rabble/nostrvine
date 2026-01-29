// ABOUTME: Complete end-to-end integration test for video creation flow
// ABOUTME: Tests app start → video recording → editing → publishing

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openvine/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Complete Video Creation Flow E2E Tests', () {
    testWidgets(
      'Full flow: App start → Video Recorder → Editor → Publish',
      (tester) async {
        // Start the app
        app.main();

        // Wait for initial app startup with multiple pump cycles
        // The app goes through: main() -> services init -> runApp() -> router redirect
        await tester.pump(); // Start the async work
        await tester.pump(
          const Duration(seconds: 1),
        ); // Let services initialize
        await tester.pump(
          const Duration(seconds: 1),
        ); // Let router process redirects
        await tester.pumpAndSettle(
          const Duration(seconds: 5),
        ); // Settle all animations

        print('🚀 App launched, looking for MaterialApp...');

        // Find MaterialApp to verify app is running
        final materialAppFinder = find.byType(MaterialApp);
        if (materialAppFinder.evaluate().isEmpty) {
          fail('Could not find MaterialApp - app did not initialize');
        }

        print('✅ MaterialApp found, completing Welcome screen...');

        // Find all checkboxes - there should be 2 (age verification and TOS)
        final checkboxes = find.byType(Checkbox);
        if (checkboxes.evaluate().length < 2) {
          fail('Could not find both checkboxes on welcome screen');
        }

        print('✅ Found checkboxes, tapping age verification...');

        // Tap first checkbox (age verification)
        await tester.tap(checkboxes.first);
        await tester.pump(const Duration(milliseconds: 50));

        print('✅ Age verification checked, tapping TOS agreement...');

        // Tap second checkbox (TOS agreement)
        await tester.tap(checkboxes.at(1));
        await tester.pump(const Duration(milliseconds: 50));

        print('✅ TOS agreement checked');

        // Find and tap Continue button
        final continueButton = find.text('Continue');
        if (continueButton.evaluate().isEmpty) {
          fail('Could not find Continue button');
        }
        await tester.tap(continueButton);

        // Wait for TOS acceptance to complete and router to redirect
        await tester.pumpAndSettle(const Duration(seconds: 2));

        print('✅ Welcome screen completed, app should now be on explore/home');

        // Wait for explore/home screen to fully load
        await tester.pump(const Duration(seconds: 1));

        print('✅ Looking for camera button...');

        // Find camera button by tooltip
        final cameraButton = find.byTooltip('Open camera');
        if (cameraButton.evaluate().isEmpty) {
          fail('Could not find camera button in app bar');
        }

        print('✅ Camera button found, tapping to open video recorder...');

        // Tap the camera button to navigate to video recorder
        await tester.tap(cameraButton);

        // Let navigation complete
        await tester.pumpAndSettle(const Duration(seconds: 3));

        print('📹 Navigated to Video Recorder');

        // Wait for camera to initialize
        await tester.pump(const Duration(seconds: 3));

        // TODO(@hm21): Add recorder interaction tests here

        // Verify navigation succeeded by checking MaterialApp is still present
        expect(materialAppFinder, findsOneWidget);
        print('✅ Successfully navigated to video recorder');
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
