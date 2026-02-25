// ABOUTME: Tests for app shell header with dynamic titles
// ABOUTME: Verifies header shows correct title and camera button for each route

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/notifications_screen.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/screens/pure/search_screen_pure.dart';

void main() {
  Widget shell(ProviderContainer c) => UncontrolledProviderScope(
    container: c,
    child: ProviderScope(
      child: MaterialApp.router(routerConfig: c.read(goRouterProvider)),
    ),
  );

  testWidgets('Header shows Divine on home', (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await tester.pumpWidget(shell(c));
    c.read(goRouterProvider).go(VideoFeedPage.pathForIndex(0));
    await tester.pump();
    expect(find.text('Divine'), findsOneWidget);
    expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);
    // TODO(any): Fix and re-enable these tests
  }, skip: true);

  testWidgets('Header shows Explore on explore', (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await tester.pumpWidget(shell(c));
    c.read(goRouterProvider).go(ExploreScreen.pathForIndex(0));
    await tester.pump();
    await tester.pump(); // Extra pump for provider updates
    // Find specifically in AppBar (not bottom nav)
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Explore')),
      findsOneWidget,
    );
    // TODO(any): Fix and re-enable these tests
  }, skip: true);

  testWidgets('Header shows #tag on hashtag', (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await tester.pumpWidget(shell(c));
    c
        .read(goRouterProvider)
        .go(HashtagScreenRouter.pathForTag('rust%20lang', index: 0));
    await tester.pump();
    expect(find.text('#rust lang'), findsOneWidget);
    // TODO(any): Fix and re-enable these tests
  }, skip: true);

  testWidgets('Header shows Profile on profile', (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await tester.pumpWidget(shell(c));
    c.read(goRouterProvider).go(ProfileScreenRouter.pathForIndex('npubXYZ', 0));
    await tester.pump();
    // Find specifically in AppBar (not bottom nav)
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Profile')),
      findsOneWidget,
    );
    // TODO(any): Fix and re-enable these tests
  }, skip: true);

  group('Back button visibility', () {
    testWidgets('Back button shown on hashtag route', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(shell(c));
      c
          .read(goRouterProvider)
          .go(HashtagScreenRouter.pathForTag('comedy', index: 0));
      await tester.pumpAndSettle();

      // Should find back button in AppBar
      final backButton = find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.arrow_back),
      );
      expect(backButton, findsOneWidget);
    });

    testWidgets('Back button shown on search route', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(shell(c));
      c.read(goRouterProvider).go(SearchScreenPure.path);
      await tester.pumpAndSettle();

      // Should find back button in AppBar
      final backButton = find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.arrow_back),
      );
      expect(backButton, findsOneWidget);
    });

    testWidgets('No back button on home route', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(shell(c));
      c.read(goRouterProvider).go(VideoFeedPage.pathForIndex(0));
      await tester.pumpAndSettle();

      // Should NOT find back button in AppBar
      final backButton = find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.arrow_back),
      );
      expect(backButton, findsNothing);
    });

    testWidgets('No back button on explore route', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(shell(c));
      c.read(goRouterProvider).go(ExploreScreen.pathForIndex(0));
      await tester.pumpAndSettle();

      // Should NOT find back button in AppBar
      final backButton = find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.arrow_back),
      );
      expect(backButton, findsNothing);
    });

    testWidgets('No back button on profile route', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(shell(c));
      c
          .read(goRouterProvider)
          .go(ProfileScreenRouter.pathForIndex('npubXYZ', 0));
      await tester.pumpAndSettle();

      // Should NOT find back button in AppBar
      final backButton = find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.arrow_back),
      );
      expect(backButton, findsNothing);
    });

    testWidgets('No back button on notifications route', (tester) async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(shell(c));
      c.read(goRouterProvider).go(NotificationsScreen.pathForIndex(0));
      await tester.pumpAndSettle();

      // Should NOT find back button in AppBar
      final backButton = find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.arrow_back),
      );
      expect(backButton, findsNothing);
    });
    // TODO(any): Fix and re-enable these tests
  }, skip: true);
}
