// ABOUTME: Comprehensive test verifying all app routes are properly configured
// ABOUTME: Tests both grid and feed modes for explore, search, hashtag, and profile routes

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/screens/home_screen_router.dart';
import 'package:openvine/screens/notifications_screen.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/screens/pure/search_screen_pure.dart';
import 'package:openvine/screens/settings_screen.dart';
import 'package:openvine/screens/video_editor_screen.dart';
import 'package:openvine/screens/video_metadata/video_metadata_screen.dart';
import 'package:openvine/screens/video_recorder_screen.dart';

void main() {
  group('App Router - All Routes', () {
    testWidgets('${HomeScreenRouter.pathWithIndex} route works', (
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
      router.go(HomeScreenRouter.pathForIndex(0));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        HomeScreenRouter.pathForIndex(0),
      );

      router.go(HomeScreenRouter.pathForIndex(5));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        HomeScreenRouter.pathForIndex(5),
      );
    });

    testWidgets('${ExploreScreen.path} route works (grid mode)', (
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
      router.go(ExploreScreen.path);
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        ExploreScreen.path,
      );
    });

    testWidgets('${ExploreScreen.pathWithIndex} route works (feed mode)', (
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

    testWidgets('${NotificationsScreen.pathWithIndex} route works', (
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

    testWidgets('${ProfileScreenRouter.pathWithIndex} route works', (
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
      router.go(ProfileScreenRouter.pathForIndex('me', 0));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        ProfileScreenRouter.pathForIndex('me', 0),
      );

      router.go(ProfileScreenRouter.pathForIndex('npub1abc', 5));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        ProfileScreenRouter.pathForIndex('npub1abc', 5),
      );
    });

    testWidgets('${SearchScreenPure.path} route works (empty search)', (
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
      router.go(SearchScreenPure.path);
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        SearchScreenPure.path,
      );
    });

    testWidgets('${SearchScreenPure.pathWithTerm} route works (grid mode)', (
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
      router.go(SearchScreenPure.pathForTerm(term: 'bitcoin'));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        SearchScreenPure.pathForTerm(term: 'bitcoin'),
      );
    });

    testWidgets(
      '${SearchScreenPure.pathWithTermAndIndex} route works (feed mode)',
      (tester) async {
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

        router.go(SearchScreenPure.pathForTerm(term: 'nostr', index: 3));
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.toString(),
          SearchScreenPure.pathForTerm(term: 'nostr', index: 3),
        );
      },
    );

    testWidgets('${HashtagScreenRouter.path} route works (grid mode)', (
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
      router.go(HashtagScreenRouter.pathForTag('bitcoin'));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        HashtagScreenRouter.pathForTag('bitcoin'),
      );
    });

    testWidgets(
      '${HashtagScreenRouter.pathWithIndex} route works (feed mode)',
      (tester) async {
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
      },
    );

    testWidgets('${SettingsScreen.path} route works', (tester) async {
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

    testWidgets('${VideoRecorderScreen.path} route works', (tester) async {
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
      router.go(VideoRecorderScreen.path);
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        VideoRecorderScreen.path,
      );
    });

    testWidgets('${VideoEditorScreen.path} route works', (tester) async {
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
      );
    });

    testWidgets('${VideoMetadataScreen.path} route works', (tester) async {
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
      router.go(VideoMetadataScreen.path);
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        VideoMetadataScreen.path,
      );
    });
    // TOOD(any): Fix and re-enable these tests
  }, skip: true);
}
