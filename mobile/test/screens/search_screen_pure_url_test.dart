// ABOUTME: Tests for SearchScreenPure URL integration
// ABOUTME: Verifies search screen reads search term from URL and triggers search

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/pure/search_screen_pure.dart';
import 'package:openvine/services/video_event_service.dart';

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockNostrClient extends Mock implements NostrClient {}

void main() {
  group('SearchScreenPure URL Integration', () {
    late _MockVideoEventService mockVideoEventService;
    late _MockNostrClient mockNostrService;

    setUp(() {
      mockVideoEventService = _MockVideoEventService();
      mockNostrService = _MockNostrClient();

      // Setup default mock behavior
      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(
        () => mockVideoEventService.searchVideos(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async {});
      when(() => mockVideoEventService.searchResults).thenReturn([]);
    });

    testWidgets('reads search term from URL and populates text field', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(mockNostrService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
        ],
      );

      // Build widget tree with router
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      // Navigate to search with term 'nostr'
      container
          .read(goRouterProvider)
          .go(SearchScreenPure.pathForTerm(term: 'nostr'));
      await tester.pump(); // Trigger initial navigation
      await tester.pump(); // Render the screen
      await tester.pump(
        const Duration(milliseconds: 100),
      ); // Allow postFrameCallback to run
      await tester.pump(); // Process search initiation
      await tester.pump(
        const Duration(milliseconds: 800),
      ); // Complete the Future.delayed in _performSearch

      // Assert: Search text field should contain 'nostr'
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, equals('nostr'));

      // Assert: PageContext should reflect search term
      final pageContext = container.read(pageContextProvider);
      expect(pageContext.value?.type, RouteType.search);
      expect(pageContext.value?.searchTerm, 'nostr');

      container.dispose();
    });

    testWidgets('automatically triggers search when search term is in URL', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(mockNostrService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
        ],
      );

      // Build widget tree with router
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      // Navigate to search with term 'bitcoin'
      container
          .read(goRouterProvider)
          .go(SearchScreenPure.pathForTerm(term: 'bitcoin'));
      await tester.pump(); // Trigger initial navigation
      await tester.pump(); // Render the screen
      await tester.pump(
        const Duration(milliseconds: 100),
      ); // Allow postFrameCallback to run
      await tester.pump(); // Process search initiation
      await tester.pump(
        const Duration(milliseconds: 800),
      ); // Complete the Future.delayed in _performSearch

      // Assert: Search should be triggered with 'bitcoin'
      verify(
        () => mockVideoEventService.searchVideos(
          'bitcoin',
          limit: any(named: 'limit'),
        ),
      ).called(greaterThan(0));

      container.dispose();
    });

    testWidgets('shows empty state when search term is null', (tester) async {
      final container = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(mockNostrService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
        ],
      );

      // Build widget tree with router
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      // Navigate to search without term
      container
          .read(goRouterProvider)
          .go(SearchScreenPure.pathForTerm(term: ''));
      await tester.pumpAndSettle();

      // Assert: Empty state UI should be shown
      expect(find.text('Search for videos'), findsOneWidget);
      expect(
        find.text('Enter keywords, hashtags, or user names'),
        findsOneWidget,
      );

      // Assert: Search should NOT be triggered
      verifyNever(
        () => mockVideoEventService.searchVideos(
          any(),
          limit: any(named: 'limit'),
        ),
      );

      container.dispose();
    });

    testWidgets('updates search when URL changes', (tester) async {
      final container = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(mockNostrService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
        ],
      );

      // Build widget tree with router
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      // Navigate to search with term 'nostr'
      container
          .read(goRouterProvider)
          .go(SearchScreenPure.pathForTerm(term: 'nostr'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      // Verify initial search
      verify(
        () => mockVideoEventService.searchVideos(
          'nostr',
          limit: any(named: 'limit'),
        ),
      ).called(greaterThan(0));

      // Reset mock to clear call history
      reset(mockVideoEventService);
      when(
        () => mockVideoEventService.searchVideos(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async {});
      when(() => mockVideoEventService.searchResults).thenReturn([]);

      // Act: Navigate to search with term 'bitcoin'
      container
          .read(goRouterProvider)
          .go(SearchScreenPure.pathForTerm(term: 'bitcoin'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      // Assert: Text field should update to 'bitcoin'
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, equals('bitcoin'));

      // Assert: New search should be triggered with 'bitcoin'
      verify(
        () => mockVideoEventService.searchVideos(
          'bitcoin',
          limit: any(named: 'limit'),
        ),
      ).called(greaterThan(0));

      container.dispose();
    });
    // TODO(any): Fix and re-enable tests
  }, skip: true);
}
