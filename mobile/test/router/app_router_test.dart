// ABOUTME: Regression tests for goRouterProvider lifecycle cleanup
// ABOUTME: Verifies stale auth refreshes do not reach a disposed container

import 'dart:async';
import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/auth/nostr_connect_screen.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/screens/inbox/conversation/conversation_page.dart';
import 'package:openvine/screens/inbox/message_requests/request_preview_page.dart';
import 'package:openvine/screens/search_results/view/search_results_page.dart';
import 'package:openvine/screens/video_recorder_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_provider_overrides.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockDmRepository extends Mock implements DmRepository {}

class _MockDmReactionsRepository extends Mock
    implements DmReactionsRepository {}

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
    Future<
      ({String? capturedTag, String? capturedQuery, bool? requestFocusOnMount})
    >
    navigateAndCapture(WidgetTester tester, String location) async {
      String? capturedTag;
      String? capturedQuery;
      bool? requestFocusOnMount;

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (_, _) => const SizedBox.shrink()),
          GoRoute(
            path: HashtagScreenRouter.path,
            builder: (ctx, st) {
              capturedTag = st.pathParameters['tag'];
              return const SizedBox.shrink();
            },
          ),
          GoRoute(
            path: SearchResultsPage.emptyPath,
            builder: (ctx, st) {
              capturedQuery = '';
              requestFocusOnMount =
                  SearchResultsPage.requestFocusOnMountForRoute(st.uri);
              return const SizedBox.shrink();
            },
          ),
          GoRoute(
            path: SearchResultsPage.path,
            builder: (ctx, st) {
              capturedQuery = st.pathParameters['query'];
              requestFocusOnMount =
                  SearchResultsPage.requestFocusOnMountForRoute(st.uri);
              return const SizedBox.shrink();
            },
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      router.go(location);
      await tester.pumpAndSettle();

      return (
        capturedTag: capturedTag,
        capturedQuery: capturedQuery,
        requestFocusOnMount: requestFocusOnMount,
      );
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

    testWidgets('pathForEmptyQuery opens search without a prefilled query', (
      tester,
    ) async {
      final result = await navigateAndCapture(
        tester,
        SearchResultsPage.pathForEmptyQuery(requestFocusOnMount: true),
      );

      expect(tester.takeException(), isNull);
      expect(result.capturedQuery, isEmpty);
      expect(result.requestFocusOnMount, isTrue);
    });

    testWidgets(
      'pathForQuery with literal % round-trips through go_router decode',
      (tester) async {
        const original = '100%';
        final result = await navigateAndCapture(
          tester,
          SearchResultsPage.pathForQuery(original, requestFocusOnMount: false),
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
          SearchResultsPage.pathForQuery(original, requestFocusOnMount: false),
        );

        expect(tester.takeException(), isNull);
        expect(result.capturedQuery, equals(original));
      },
    );

    testWidgets('pathForQuery can opt a prefilled route into mount focus', (
      tester,
    ) async {
      const original = 'alice';
      final result = await navigateAndCapture(
        tester,
        SearchResultsPage.pathForQuery(original, requestFocusOnMount: true),
      );

      expect(tester.takeException(), isNull);
      expect(result.capturedQuery, equals(original));
      expect(result.requestFocusOnMount, isTrue);
    });

    testWidgets(
      'pathForQuery keeps a prefilled route unfocused when not opted in',
      (tester) async {
        const original = 'alice';
        final result = await navigateAndCapture(
          tester,
          SearchResultsPage.pathForQuery(original, requestFocusOnMount: false),
        );

        expect(tester.takeException(), isNull);
        expect(result.capturedQuery, equals(original));
        expect(result.requestFocusOnMount, isFalse);
      },
    );
  });

  // Static-source regression guard for #3413 — Crashlytics issue
  // 489d5ebc7bd571dfd29e4701e92abdf6. The round-trip tests above assert
  // the encode/decode contract holds when callers use pathForTag /
  // pathForQuery, but they use a synthetic GoRoute builder and so do not
  // exercise the production builders in lib/router/routes/search_routes.dart.
  // This guard reads the production source and fails if the hashtag or search
  // builder regions reintroduce Uri.decodeComponent — the exact regression
  // that originally caused the crash.
  group('Builder regression guard (#3413)', () {
    test('hashtag and search builders do not call Uri.decodeComponent', () {
      final source = File(
        'lib/router/routes/search_routes.dart',
      ).readAsStringSync();

      final hashtagPathOffset = source.indexOf(
        'path: HashtagScreenRouter.path',
      );
      final searchPathOffset = source.indexOf('path: SearchResultsPage.path');
      expect(
        hashtagPathOffset,
        isNonNegative,
        reason:
            'Hashtag GoRoute marker not found in search_routes.dart. '
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
      expect(
        searchRegion.contains('requestFocusOnMount:'),
        isTrue,
        reason:
            'Search-results builder must forward route-level focus intent '
            'instead of relying on widget defaults.',
      );
      expect(
        searchRegion.contains('SearchResultsPage.requestFocusOnMountForRoute('),
        isTrue,
        reason:
            'Search-results builder must derive focus from the routed URI so '
            'Explore, mentions, and deep links can express distinct intent.',
      );
    });
  });

  group('Home route builder', () {
    test('parses and normalizes the routed home index', () {
      expect(
        homeInitialIndexFromPathParameters(const {'index': '37'}),
        equals(37),
      );
      expect(
        homeInitialIndexFromPathParameters(const {'index': '-4'}),
        equals(0),
      );
      expect(
        homeInitialIndexFromPathParameters(const {'index': 'not-an-int'}),
        equals(0),
      );
      expect(homeInitialIndexFromPathParameters(const {}), equals(0));
    });
  });

  group('Offline recorder route', () {
    test(
      'unauthenticated users can navigate to recorder but not protected routes',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final sharedPreferences = await SharedPreferences.getInstance();
        final authStateController = StreamController<AuthState>.broadcast(
          sync: true,
        );
        addTearDown(authStateController.close);

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            authServiceProvider.overrideWith((ref) {
              final authService = _MockAuthService();
              when(
                () => authService.authStateStream,
              ).thenAnswer((_) => authStateController.stream);
              when(
                () => authService.authState,
              ).thenReturn(AuthState.unauthenticated);
              when(() => authService.hasExpiredOAuthSession).thenReturn(false);
              return authService;
            }),
          ],
        );
        addTearDown(container.dispose);

        final router = container.read(goRouterProvider);

        router.go(VideoRecorderScreen.path);
        await Future<void>.delayed(Duration.zero);

        expect(
          router.routeInformationProvider.value.uri.toString(),
          equals(VideoRecorderScreen.path),
        );
      },
    );
  });

  group('NIP-46 signer callbacks', () {
    test('redirect active signer callback route back to nostr connect', () {
      final authService = _MockAuthService();
      when(() => authService.nostrConnectUrl).thenReturn(
        'nostrconnect://4c4060f6d19c8cafad01952e625e9819386b7a620bc03bfc6491b797b36cde5a',
      );
      when(
        () => authService.onSignerCallbackReceived(
          relayUrl: any(named: 'relayUrl'),
        ),
      ).thenReturn(null);

      final target = signerCallbackRedirectTarget(
        Uri.parse(
          'divine://nostrconnect?x-source=aegis&relay=wss://localrelay.link:28443',
        ),
        authService,
      );

      expect(target, equals(NostrConnectScreen.path));
      verify(
        () => authService.onSignerCallbackReceived(
          relayUrl: 'wss://localrelay.link:28443',
        ),
      ).called(greaterThan(0));
    });
  });

  group('DM route extras', () {
    const currentPubkey =
        'aabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccdd';
    const otherPubkey =
        '1122334455667788112233445566778811223344556677881122334455667788';
    const conversationId =
        'ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00';

    late MockAuthService mockAuthService;
    late _MockDmRepository mockDmRepository;
    late _MockDmReactionsRepository mockDmReactionsRepository;

    setUp(() {
      resetNavigationState();
      mockAuthService = createMockAuthService();
      mockDmRepository = _MockDmRepository();
      mockDmReactionsRepository = _MockDmReactionsRepository();

      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.authState).thenReturn(AuthState.authenticated);
      when(
        () => mockAuthService.currentPublicKeyHex,
      ).thenReturn(currentPubkey);
      when(
        () => mockAuthService.authStateStream,
      ).thenAnswer((_) => const Stream<AuthState>.empty());

      when(
        () => mockDmRepository.markConversationAsRead(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockDmRepository.watchMessages(any()),
      ).thenAnswer((_) => Stream.value(const <DmMessage>[]));
      when(
        () => mockDmRepository.watchOutgoing(any()),
      ).thenAnswer((_) => Stream.value(const <OutgoingDm>[]));
      when(
        () => mockDmRepository.countMessagesInConversation(any()),
      ).thenAnswer((_) async => 0);
      when(
        () => mockDmRepository.getConversation(any()),
      ).thenAnswer((_) async => null);

      when(
        () => mockDmReactionsRepository.watchForConversation(any()),
      ).thenAnswer((_) => Stream.value(const <DmReaction>[]));
    });

    testWidgets('conversation accepts list-like dynamic extras on web', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          ...getStandardTestOverrides(mockAuthService: mockAuthService),
          currentMinorAccountReviewStatusProvider.overrideWith(
            (ref) async => MinorAccountReviewStatus.active(),
          ),
          dmRepositoryProvider.overrideWithValue(mockDmRepository),
          dmReactionsRepositoryProvider.overrideWithValue(
            mockDmReactionsRepository,
          ),
        ],
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });

      final router = container.read(goRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );

      router.go(
        ConversationPage.pathForId(conversationId),
        extra: <dynamic>[otherPubkey],
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        router.routeInformationProvider.value.uri.toString(),
        ConversationPage.pathForId(conversationId),
      );
    });

    testWidgets('request preview accepts list-like dynamic extras on web', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          ...getStandardTestOverrides(mockAuthService: mockAuthService),
          currentMinorAccountReviewStatusProvider.overrideWith(
            (ref) async => MinorAccountReviewStatus.active(),
          ),
          dmRepositoryProvider.overrideWithValue(mockDmRepository),
          dmReactionsRepositoryProvider.overrideWithValue(
            mockDmReactionsRepository,
          ),
        ],
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });

      final router = container.read(goRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );

      router.go(
        RequestPreviewPage.pathPattern.replaceFirst(':id', conversationId),
        extra: <dynamic>[otherPubkey],
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        router.routeInformationProvider.value.uri.toString(),
        RequestPreviewPage.pathPattern.replaceFirst(':id', conversationId),
      );
    });
  });
}
