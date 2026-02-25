// ABOUTME: Tests all real navigation scenarios used in the app
// ABOUTME: Verifies every route pattern and navigation flow works

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
import 'package:openvine/screens/settings_screen.dart';
import 'package:openvine/screens/video_editor/video_clip_editor_screen.dart';
import 'package:openvine/screens/video_editor/video_editor_screen.dart';

void main() {
  group('Real Navigation Scenarios', () {
    testWidgets('Home tab navigation', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      router.go(VideoFeedPage.pathForIndex(0));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        VideoFeedPage.pathForIndex(0),
      );

      router.go(VideoFeedPage.pathForIndex(5));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        VideoFeedPage.pathForIndex(5),
      );
    });

    testWidgets('Explore tab tap - grid mode', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      router.go(ExploreScreen.path);
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        ExploreScreen.path,
        reason: 'Explore tab tap should navigate to grid mode',
      );
    });

    testWidgets('Explore grid → feed navigation', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      router.go(ExploreScreen.pathForIndex(0));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        ExploreScreen.pathForIndex(0),
      );

      router.go(ExploreScreen.pathForIndex(3));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        ExploreScreen.pathForIndex(3),
      );
    });

    testWidgets('Hashtag grid mode', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      router.go(HashtagScreenRouter.pathForTag('bitcoin'));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        HashtagScreenRouter.pathForTag('bitcoin'),
      );
    });

    testWidgets('Hashtag feed mode', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      router.go(HashtagScreenRouter.pathForTag('bitcoin', index: 0));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        HashtagScreenRouter.pathForTag('bitcoin', index: 0),
      );

      router.go(HashtagScreenRouter.pathForTag('nostr', index: 5));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        HashtagScreenRouter.pathForTag('nostr', index: 5),
      );
    });

    testWidgets('Profile navigation', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      router.go(ProfileScreenRouter.pathForIndex('npub1xyz', 0));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        ProfileScreenRouter.pathForIndex('npub1xyz', 0),
      );

      router.go(ProfileScreenRouter.pathForIndex('npub1xyz', 5));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        ProfileScreenRouter.pathForIndex('npub1xyz', 5),
      );
    });

    testWidgets('Search empty', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      router.go(SearchScreenPure.path);
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        SearchScreenPure.path,
      );
    });

    testWidgets('Search with term - grid mode', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      router.go(SearchScreenPure.pathForTerm(term: 'bitcoin'));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        SearchScreenPure.pathForTerm(term: 'bitcoin'),
      );
    });

    testWidgets('Search with term - feed mode', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      router.go(SearchScreenPure.pathForTerm(term: 'bitcoin', index: 0));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        SearchScreenPure.pathForTerm(term: 'bitcoin', index: 0),
      );

      router.go(SearchScreenPure.pathForTerm(term: 'bitcoin', index: 3));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        SearchScreenPure.pathForTerm(term: 'bitcoin', index: 3),
      );
    });

    testWidgets('Settings route', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      router.go(SettingsScreen.path);
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        SettingsScreen.path,
      );
    });

    testWidgets('Notifications navigation', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      router.go(NotificationsScreen.pathForIndex(0));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        NotificationsScreen.pathForIndex(0),
      );

      router.go(NotificationsScreen.pathForIndex(2));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        NotificationsScreen.pathForIndex(2),
      );
    });

    testWidgets('Profile/me special route', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      // /profile/me/0 should be handled (used in camera after upload)
      router.go(ProfileScreenRouter.pathForIndex('me', 0));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        ProfileScreenRouter.pathForIndex('me', 0),
        reason: 'Profile me route should work for current user navigation',
      );
    });

    testWidgets('Edit video route', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      router.go(VideoEditorScreen.path);
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        VideoEditorScreen.path,
        reason: 'Edit video route should exist',
      );
    });

    testWidgets('Edit video-clip route', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      router.go(VideoClipEditorScreen.path);
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        VideoClipEditorScreen.path,
        reason: 'Edit video-clip route should exist',
      );
    });

    testWidgets('Home video feed swiping', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      // Swiping through home feed updates index in URL
      router.go(VideoFeedPage.pathForIndex(0));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        VideoFeedPage.pathForIndex(0),
      );

      router.go(VideoFeedPage.pathForIndex(1));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        VideoFeedPage.pathForIndex(1),
      );

      router.go(VideoFeedPage.pathForIndex(10));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        VideoFeedPage.pathForIndex(10),
      );
    });

    testWidgets('Explore back to grid from feed', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      // Navigate to feed mode
      router.go(ExploreScreen.pathForIndex(5));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        ExploreScreen.pathForIndex(5),
      );

      // Back button should go to grid mode
      router.go(ExploreScreen.path);
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        ExploreScreen.path,
        reason: 'Back from explore feed should return to grid mode',
      );
    });

    testWidgets('Hashtag back to grid from feed', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      // Navigate to hashtag feed mode
      router.go(HashtagScreenRouter.pathForTag('bitcoin', index: 5));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        HashtagScreenRouter.pathForTag('bitcoin', index: 5),
      );

      // Back button should go to hashtag grid mode
      router.go(HashtagScreenRouter.path);
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        HashtagScreenRouter.path,
        reason: 'Back from hashtag feed should return to grid mode',
      );
    });

    testWidgets('Search back to grid from feed', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      // Navigate to search feed mode
      router.go(SearchScreenPure.pathForTerm(term: 'bitcoin', index: 3));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        SearchScreenPure.pathForTerm(term: 'bitcoin', index: 3),
      );

      // Back button should go to search grid mode
      router.go(SearchScreenPure.pathForTerm(term: 'bitcoin'));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        SearchScreenPure.pathForTerm(term: 'bitcoin'),
        reason: 'Back from search feed should return to grid mode',
      );
    });

    testWidgets('URL-encoded hashtags', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      // Hashtags with spaces or special chars should be URL-encoded
      router.go(HashtagScreenRouter.pathForTag('my%20tag', index: 0));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        HashtagScreenRouter.pathForTag('my%20tag', index: 0),
        reason: 'URL-encoded hashtags should work',
      );
    });

    testWidgets('URL-encoded search terms', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      // Search terms with spaces should be URL-encoded
      router.go(SearchScreenPure.pathForTerm(term: 'hello world'));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        SearchScreenPure.pathForTerm(term: 'hello%20world'),
        reason: 'URL-encoded search terms should work',
      );
    });

    testWidgets('Back button navigates from hashtag feed to grid', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      // Navigate to hashtag feed mode
      router.go(HashtagScreenRouter.pathForTag('bitcoin', index: 5));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        HashtagScreenRouter.pathForTag('bitcoin', index: 5),
      );

      // Find and tap the back button in AppBar
      final backButton = find.byIcon(Icons.arrow_back);
      expect(
        backButton,
        findsOneWidget,
        reason: 'Back button should be visible in hashtag feed mode',
      );

      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Should navigate to hashtag grid mode
      expect(
        router.routeInformationProvider.value.uri.toString(),
        HashtagScreenRouter.pathForTag('bitcoin'),
        reason: 'Tapping back button should navigate from feed to grid mode',
      );
    });

    testWidgets('Back button navigates from search feed to grid', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      // Navigate to search feed mode
      router.go(SearchScreenPure.pathForTerm(term: 'nostr', index: 3));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        SearchScreenPure.pathForTerm(term: 'nostr', index: 3),
      );

      // Find and tap the back button
      final backButton = find.byIcon(Icons.arrow_back);
      expect(backButton, findsOneWidget);

      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Should navigate to search grid mode
      expect(
        router.routeInformationProvider.value.uri.toString(),
        SearchScreenPure.pathForTerm(term: 'nostr'),
        reason: 'Tapping back button should navigate from search feed to grid',
      );
    });

    testWidgets('Back button navigates from hashtag grid to explore', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);

      // Navigate to hashtag grid mode
      router.go(HashtagScreenRouter.pathForTag('bitcoin'));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        HashtagScreenRouter.pathForTag('bitcoin'),
      );

      // Find and tap the back button
      final backButton = find.byIcon(Icons.arrow_back);
      expect(
        backButton,
        findsOneWidget,
        reason: 'Back button should be visible in hashtag grid mode',
      );

      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Should navigate back to explore
      expect(
        router.routeInformationProvider.value.uri.toString(),
        ExploreScreen.path,
        reason: 'Tapping back from hashtag grid should go to explore',
      );
    });
    // TODO(any): Fix and re-enable these tests
  }, skip: true);
}
