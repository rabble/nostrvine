// ABOUTME: Regression tests for goRouterProvider lifecycle cleanup
// ABOUTME: Verifies stale auth refreshes do not reach a disposed container

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/screens/search_results/view/search_results_page.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

class _AuthStateBus {
  AuthState state = AuthState.unauthenticated;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(resetNavigationState);

  test(
    'disposes the router refresh listener before a late auth refresh fires',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final sharedPreferences = await SharedPreferences.getInstance();
      final authStateController = StreamController<AuthState>.broadcast(
        sync: true,
      );
      addTearDown(authStateController.close);

      final authStateBus = _AuthStateBus();

      ProviderContainer createContainer() {
        return ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            authServiceProvider.overrideWith((ref) {
              final authService = _MockAuthService();
              when(
                () => authService.authStateStream,
              ).thenAnswer((_) => authStateController.stream);
              when(
                () => authService.authState,
              ).thenAnswer((_) => authStateBus.state);
              when(() => authService.hasExpiredOAuthSession).thenReturn(false);
              return authService;
            }),
          ],
        );
      }

      final containerA = createContainer();
      final routerA = containerA.read(goRouterProvider);
      expect(routerA, isA<GoRouter>());

      containerA.dispose();

      authStateBus.state = AuthState.authenticated;
      expect(
        () => authStateController.add(AuthState.authenticated),
        returnsNormally,
      );

      authStateBus.state = AuthState.unauthenticated;
      final containerB = createContainer();
      addTearDown(containerB.dispose);

      final routerB = containerB.read(goRouterProvider);
      expect(routerB, isA<GoRouter>());
    },
  );

  // Regression tests for #3413 — Crashlytics issue
  // 489d5ebc7bd571dfd29e4701e92abdf6 ("Illegal percent encoding in URI"). The
  // hashtag/search route builders used to call Uri.decodeComponent on values
  // that go_router had already decoded once, which crashed on any input
  // containing a literal `%` after the first decode (e.g. a search for
  // "100%"). The fix is to pass state.pathParameters through unchanged.
  //
  // These tests use a minimal GoRouter so that the production builder's
  // contract — "the value reaching state.pathParameters equals the original
  // string passed to pathForTag/pathForQuery" — can be exercised without
  // pulling in the full app provider graph.
  group('Path-parameter round-trip (#3413)', () {
    Future<({String? capturedTag, String? capturedQuery})> navigateAndCapture(
      WidgetTester tester,
      String location,
    ) async {
      String? capturedTag;
      String? capturedQuery;

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: HashtagScreenRouter.path,
            builder: (ctx, st) {
              capturedTag = st.pathParameters['tag'];
              return const SizedBox.shrink();
            },
          ),
          GoRoute(
            path: SearchResultsPage.path,
            builder: (ctx, st) {
              capturedQuery = st.pathParameters['query'];
              return const SizedBox.shrink();
            },
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      router.go(location);
      await tester.pumpAndSettle();

      return (capturedTag: capturedTag, capturedQuery: capturedQuery);
    }

    testWidgets(
      'pathForTag with literal % round-trips through go_router decode',
      (tester) async {
        const original = '100%fun';
        final result = await navigateAndCapture(
          tester,
          HashtagScreenRouter.pathForTag(original),
        );

        expect(tester.takeException(), isNull);
        expect(result.capturedTag, equals(original));
      },
    );

    testWidgets(
      'pathForTag with literal `#` (encoded as `%23`) round-trips correctly',
      (tester) async {
        const original = 'c#dev';
        final result = await navigateAndCapture(
          tester,
          HashtagScreenRouter.pathForTag(original),
        );

        expect(tester.takeException(), isNull);
        expect(result.capturedTag, equals(original));
      },
    );

    testWidgets(
      'pathForQuery with literal % round-trips through go_router decode',
      (tester) async {
        const original = '100%';
        final result = await navigateAndCapture(
          tester,
          SearchResultsPage.pathForQuery(original),
        );

        expect(tester.takeException(), isNull);
        expect(result.capturedQuery, equals(original));
      },
    );

    testWidgets(
      'pathForQuery with literal % and spaces round-trips correctly',
      (tester) async {
        const original = '50% off deals';
        final result = await navigateAndCapture(
          tester,
          SearchResultsPage.pathForQuery(original),
        );

        expect(tester.takeException(), isNull);
        expect(result.capturedQuery, equals(original));
      },
    );
  });

  // Static-source regression guard for #3413 — Crashlytics issue
  // 489d5ebc7bd571dfd29e4701e92abdf6. The round-trip tests above assert
  // the encode/decode contract holds when callers use pathForTag /
  // pathForQuery, but they use a synthetic GoRoute builder and so do not
  // exercise the production builders in lib/router/app_router.dart. This
  // guard reads the production source and fails if the hashtag or search
  // builder regions reintroduce Uri.decodeComponent — the exact regression
  // that originally caused the crash.
  group('Builder regression guard (#3413)', () {
    test('hashtag and search builders do not call Uri.decodeComponent', () {
      final source = File('lib/router/app_router.dart').readAsStringSync();

      final hashtagPathOffset = source.indexOf(
        'path: HashtagScreenRouter.path',
      );
      final searchPathOffset = source.indexOf(
        'path: SearchResultsPage.path',
      );
      expect(
        hashtagPathOffset,
        isNonNegative,
        reason:
            'Hashtag GoRoute marker not found in app_router.dart. '
            'Update this regression test to match the new marker.',
      );
      expect(
        searchPathOffset,
        greaterThan(hashtagPathOffset),
        reason:
            'Search-results GoRoute marker not found after hashtag '
            'GoRoute. Update this regression test to match the new layout.',
      );

      final hashtagRegion = source.substring(
        hashtagPathOffset,
        searchPathOffset,
      );
      final nextGoRouteAfterSearch = source.indexOf(
        'GoRoute(',
        searchPathOffset,
      );
      final searchRegion = source.substring(
        searchPathOffset,
        nextGoRouteAfterSearch == -1 ? source.length : nextGoRouteAfterSearch,
      );

      const guard =
          'go_router 16.x already decodes path parameters once during '
          'route matching. Calling Uri.decodeComponent again here '
          'crashes on legitimate inputs containing a literal `%` '
          '(e.g. searching for "100%") — the original Crashlytics '
          'issue. Pass state.pathParameters[...] through unchanged.';

      expect(
        hashtagRegion.contains('Uri.decodeComponent'),
        isFalse,
        reason: 'Hashtag builder must not double-decode. $guard',
      );
      expect(
        searchRegion.contains('Uri.decodeComponent'),
        isFalse,
        reason: 'Search-results builder must not double-decode. $guard',
      );
    });
  });
}
