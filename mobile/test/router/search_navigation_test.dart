// ABOUTME: Test for search navigation integration
// ABOUTME: Verifies search route and navigation helpers work correctly

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/screens/pure/search_screen_pure.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/video_event_service.dart';

import 'search_navigation_test.mocks.dart';

@GenerateMocks([AuthService, NostrClient, VideoEventService])
void main() {
  late MockAuthService mockAuthService;
  late MockNostrClient mockNostrService;
  late MockVideoEventService mockVideoEventService;

  setUp(() {
    mockAuthService = MockAuthService();
    mockNostrService = MockNostrClient();
    mockVideoEventService = MockVideoEventService();

    // Setup basic stubs
    when(mockAuthService.isAuthenticated).thenReturn(false);
    when(mockAuthService.currentKeyContainer).thenReturn(null);
    when(mockNostrService.isInitialized).thenReturn(false);
  });

  group('Search Navigation', () {
    testWidgets('pushSearch() navigates to search screen', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(mockAuthService),
          nostrServiceProvider.overrideWithValue(mockNostrService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap search button in app bar
      final searchButton = find.byTooltip('Search');
      expect(searchButton, findsOneWidget);

      await tester.tap(searchButton);
      await tester.pumpAndSettle();

      // Verify we're on the search screen
      expect(find.byType(SearchScreenPure), findsOneWidget);
    });

    testWidgets('Search screen has search bar and tabs', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SearchScreenPure())),
      );

      await tester.pumpAndSettle();

      // Verify search bar exists
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search videos, users, hashtags...'), findsOneWidget);

      // Verify tabs exist
      expect(find.text('Videos (0)'), findsOneWidget);
      expect(find.text('Users (0)'), findsOneWidget);
      expect(find.text('Hashtags (0)'), findsOneWidget);
    });

    testWidgets('Back button returns from search screen', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(mockAuthService),
          nostrServiceProvider.overrideWithValue(mockNostrService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to search
      final searchButton = find.byTooltip('Search');
      await tester.tap(searchButton);
      await tester.pumpAndSettle();

      // Verify we're on search screen
      expect(find.byType(SearchScreenPure), findsOneWidget);

      // Tap back button
      final backButton = find.byIcon(Icons.arrow_back);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Verify we're back on home screen
      expect(find.byType(SearchScreenPure), findsNothing);
    });
  });
}
