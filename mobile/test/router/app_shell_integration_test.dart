// ABOUTME: Integration tests for app shell with GoRouter
// ABOUTME: Tests shell rendering, deep links, tab state preservation, back navigation

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/home_feed_provider.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/router/app_shell.dart';
import 'package:openvine/router/route_normalization_provider.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/screens/home_screen_router.dart';
import 'package:openvine/screens/profile_screen_router.dart';

void main() {
  // Disable HomeFeed timer in tests by setting poll interval to 1 year
  final testOverrides = [
    homeFeedPollIntervalProvider.overrideWithValue(const Duration(days: 365)),
  ];

  Widget shell(ProviderContainer c) => UncontrolledProviderScope(
    container: c,
    child: MaterialApp.router(routerConfig: c.read(goRouterProvider)),
  );

  String currentLocation(ProviderContainer c) {
    final router = c.read(goRouterProvider);
    return router.routeInformationProvider.value.uri.toString();
  }

  group('A) App shell renders & normalizes', () {
    testWidgets('renders with goRouterProvider and normalization active', (
      tester,
    ) async {
      final c = ProviderContainer(overrides: testOverrides);
      addTearDown(c.dispose);

      await tester.pumpWidget(shell(c));

      // Activate normalization provider
      c.read(routeNormalizationProvider);

      await tester.pump();

      // Should start at initial location
      expect(currentLocation(c), HomeScreenRouter.pathForIndex(0));

      // Find AppShell widget to verify shell is rendered
      expect(find.byType(AppShell), findsOneWidget);
    });

    testWidgets(
      'normalizes /home/-3 to /home/0 with correct bottom nav index',
      (tester) async {
        final c = ProviderContainer(overrides: testOverrides);
        addTearDown(c.dispose);

        await tester.pumpWidget(shell(c));

        // Activate normalization provider
        c.read(routeNormalizationProvider);

        c.read(goRouterProvider).go(HomeScreenRouter.pathForIndex(-3));
        await tester.pump(); // Process the navigation
        await tester.pump(); // Process the post-frame callback redirect

        // After normalization, router location should be canonical
        expect(currentLocation(c), HomeScreenRouter.pathForIndex(0));

        // Bottom nav should show Home tab (index 0) as selected
        final bottomNav = tester.widget<BottomNavigationBar>(
          find.byType(BottomNavigationBar),
        );
        expect(bottomNav.currentIndex, 0);
      },
    );
    // TODO(any): Fix and re-enable these tests
  }, skip: true);

  group('B) Deep links land in correct tab', () {
    testWidgets('navigating to /profile/npubXYZ/2 selects Profile tab', (
      tester,
    ) async {
      final c = ProviderContainer(overrides: testOverrides);
      addTearDown(c.dispose);

      await tester.pumpWidget(shell(c));

      c.read(routeNormalizationProvider);

      c
          .read(goRouterProvider)
          .go(ProfileScreenRouter.pathForIndex('npubXYZ', 2));
      await tester.pump(); // Process the navigation
      await tester.pump(); // Process the post-frame callback

      // Should be at profile route
      expect(
        currentLocation(c),
        ProfileScreenRouter.pathForIndex('npubXYZ', 2),
      );

      // Bottom nav should show Profile tab (index 3) as selected
      final bottomNav = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(bottomNav.currentIndex, 3);
    });

    testWidgets('navigating to /explore/5 selects Explore tab', (tester) async {
      final c = ProviderContainer(overrides: testOverrides);
      addTearDown(c.dispose);

      await tester.pumpWidget(shell(c));

      c.read(routeNormalizationProvider);

      c.read(goRouterProvider).go(ExploreScreen.pathForIndex(5));
      await tester.pump(); // Process the navigation
      await tester.pump(); // Process the post-frame callback

      // Should be at explore route
      expect(currentLocation(c), ExploreScreen.pathForIndex(5));

      // Bottom nav should show Explore tab (index 1) as selected
      final bottomNav = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(bottomNav.currentIndex, 1);
    });

    testWidgets('navigating to /hashtag/rust/3 selects Tags tab', (
      tester,
    ) async {
      final c = ProviderContainer(overrides: testOverrides);
      addTearDown(c.dispose);

      await tester.pumpWidget(shell(c));

      c.read(routeNormalizationProvider);

      c
          .read(goRouterProvider)
          .go(HashtagScreenRouter.pathForTag('rust', index: 3));
      await tester.pump(); // Process the navigation
      await tester.pump(); // Process the post-frame callback

      // Should be at hashtag route
      expect(
        currentLocation(c),
        HashtagScreenRouter.pathForTag('rust', index: 3),
      );

      // Bottom nav should show Tags tab (index 2) as selected
      final bottomNav = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(bottomNav.currentIndex, 2);
    });
    // TODO(any): Fix and re-enable these tests
  }, skip: true);

  group('C) Tab switching preserves state', () {
    testWidgets('switching tabs preserves route within each tab', (
      tester,
    ) async {
      final c = ProviderContainer(overrides: testOverrides);
      addTearDown(c.dispose);

      await tester.pumpWidget(shell(c));

      c.read(routeNormalizationProvider);

      // Start at home/2
      c.read(goRouterProvider).go(HomeScreenRouter.pathForIndex(2));
      await tester.pump();
      await tester.pump();

      expect(currentLocation(c), HomeScreenRouter.pathForIndex(2));

      // Navigate within home tab to home/3
      c.read(goRouterProvider).go(HomeScreenRouter.pathForIndex(3));
      await tester.pump();
      await tester.pump();

      expect(currentLocation(c), HomeScreenRouter.pathForIndex(3));

      // Switch to Explore tab
      c.read(goRouterProvider).go(ExploreScreen.pathForIndex(0));
      await tester.pump();
      await tester.pump();

      expect(currentLocation(c), ExploreScreen.pathForIndex(0));

      // Switch back to Home tab via bottom nav
      final bottomNav = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      bottomNav.onTap!(0); // Tap Home tab
      await tester.pump();
      await tester.pump();

      // Should return to canonical /home/0 (basePathForTab behavior)
      // This is expected because onTap navigates to canonical paths
      expect(currentLocation(c), HomeScreenRouter.pathForIndex(0));
    });

    testWidgets(
      'per-tab navigators maintain separate state across tab switches',
      (tester) async {
        final c = ProviderContainer(overrides: testOverrides);
        addTearDown(c.dispose);

        await tester.pumpWidget(shell(c));

        c.read(routeNormalizationProvider);

        // Navigate to /explore/7
        c.read(goRouterProvider).go(ExploreScreen.pathForIndex(7));
        await tester.pump();
        await tester.pump();

        expect(currentLocation(c), ExploreScreen.pathForIndex(7));

        // Switch to Profile tab
        c.read(goRouterProvider).go(ProfileScreenRouter.pathForIndex('me', 5));
        await tester.pump();
        await tester.pump();

        expect(currentLocation(c), ProfileScreenRouter.pathForIndex('me', 5));

        // Navigate directly back to explore (not via bottom nav tap)
        c.read(goRouterProvider).go(ExploreScreen.pathForIndex(7));
        await tester.pump();
        await tester.pump();

        // Should be back at /explore/7
        expect(currentLocation(c), ExploreScreen.pathForIndex(7));
      },
    );
    // TODO(any): Fix and re-enable these tests
  }, skip: true);

  group('D) Back behavior', () {
    testWidgets('can navigate back within tab stack', (tester) async {
      final c = ProviderContainer(overrides: testOverrides);
      addTearDown(c.dispose);

      await tester.pumpWidget(shell(c));

      c.read(routeNormalizationProvider);

      // Navigate to home/2
      c.read(goRouterProvider).go(HomeScreenRouter.pathForIndex(2));
      await tester.pump();
      await tester.pump();

      expect(currentLocation(c), HomeScreenRouter.pathForIndex(2));

      // Navigate to home/5
      c.read(goRouterProvider).go(HomeScreenRouter.pathForIndex(5));
      await tester.pump();
      await tester.pump();

      expect(currentLocation(c), HomeScreenRouter.pathForIndex(5));

      // Go back
      c.read(goRouterProvider).pop();
      await tester.pump();
      await tester.pump();

      // Should be back at home/2
      expect(currentLocation(c), HomeScreenRouter.pathForIndex(2));
    });

    testWidgets('bottom nav tap navigates to canonical tab path', (
      tester,
    ) async {
      final c = ProviderContainer(overrides: testOverrides);
      addTearDown(c.dispose);

      await tester.pumpWidget(shell(c));

      c.read(routeNormalizationProvider);

      // Start at /home/7
      c.read(goRouterProvider).go(HomeScreenRouter.pathForIndex(7));
      await tester.pump();
      await tester.pump();

      expect(currentLocation(c), HomeScreenRouter.pathForIndex(7));

      // Tap Explore via bottom nav
      final bottomNav = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      bottomNav.onTap!(1); // Tap Explore tab
      await tester.pump();
      await tester.pump();

      // Should navigate to canonical explore path
      expect(currentLocation(c), ExploreScreen.pathForIndex(0));

      // Tap Home via bottom nav
      bottomNav.onTap!(0); // Tap Home tab
      await tester.pump();
      await tester.pump();

      // Should navigate to canonical home path, not back to /home/7
      expect(currentLocation(c), HomeScreenRouter.pathForIndex(0));
    });
    // TODO(any): Fix and re-enable these tests
  }, skip: true);
}
