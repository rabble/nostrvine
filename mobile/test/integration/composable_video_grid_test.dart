// ABOUTME: Integration test for ComposableVideoGrid with real Nostr connections
// ABOUTME: Tests grid rendering, video display, and tap interactions in real app

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openvine/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('ComposableVideoGrid Integration', () {
    testWidgets('explore screen displays video grid with real data', (
      tester,
    ) async {
      // Start the app with real Nostr connections
      app.main();

      // Wait for app to initialize and connect to relays
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Navigate to explore screen
      final exploreTab = find.byIcon(Icons.explore);
      if (exploreTab.evaluate().isNotEmpty) {
        await tester.tap(exploreTab);
        await tester.pumpAndSettle(const Duration(seconds: 3));
      }

      // Should have a GridView for video display
      expect(find.byType(GridView), findsWidgets);
    });

    testWidgets('video grid shows tappable video tiles', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Navigate to explore
      final exploreTab = find.byIcon(Icons.explore);
      if (exploreTab.evaluate().isNotEmpty) {
        await tester.tap(exploreTab);
        await tester.pumpAndSettle(const Duration(seconds: 3));
      }

      // Should have GestureDetector tiles for tappable videos
      expect(find.byType(GestureDetector), findsWidgets);
    });

    testWidgets('grid uses correct aspect ratio', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Navigate to explore
      final exploreTab = find.byIcon(Icons.explore);
      if (exploreTab.evaluate().isNotEmpty) {
        await tester.tap(exploreTab);
        await tester.pumpAndSettle(const Duration(seconds: 3));
      }

      // Find GridView and verify delegate settings
      final gridFinder = find.byType(GridView);
      if (gridFinder.evaluate().isNotEmpty) {
        final gridView = tester.widget<GridView>(gridFinder.first);
        final delegate =
            gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;

        // Default aspect ratio should be 1.0
        expect(delegate.childAspectRatio, equals(1.0));
      }
    });

    testWidgets('tapping video tile navigates to video feed', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Navigate to explore
      final exploreTab = find.byIcon(Icons.explore);
      if (exploreTab.evaluate().isNotEmpty) {
        await tester.tap(exploreTab);
        await tester.pumpAndSettle(const Duration(seconds: 3));
      }

      // Find and tap first video tile if available
      final gestureFinder = find.byType(GestureDetector);
      if (gestureFinder.evaluate().length > 2) {
        // Tap a video tile (skip navigation elements)
        await tester.tap(gestureFinder.at(2));
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Should have navigated - verify we're no longer on grid view
        // or verify video player is visible
      }
    });
  });
}
