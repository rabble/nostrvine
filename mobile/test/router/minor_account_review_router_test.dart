import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/router/providers/route_normalization_provider.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/inbox/conversation/conversation_page.dart';
import 'package:openvine/screens/minor_account_review_parent_contact_screen.dart';
import 'package:openvine/screens/minor_account_review_screen.dart';
import 'package:openvine/screens/minor_account_review_under13_support_screen.dart';
import 'package:openvine/screens/settings/support_center_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/bug_report_service.dart';

import '../helpers/test_provider_overrides.dart';

/// Authenticated identity is known but the signer-backed Nostr client has
/// not finished initializing — the not-ready window the router must
/// fail-closed through. Replaces the pre-refactor
/// `isNostrReadyProvider.overrideWith((ref) => false)`.
class _NotReadyNostrSession extends NostrSession {
  @override
  NostrSessionReadiness build() =>
      const NostrSessionReadiness.identityKnown(pubkey: 'user-pubkey');
}

void main() {
  group('Minor account review router gating', () {
    late MockAuthService mockAuthService;

    setUp(() {
      resetNavigationState();
      mockAuthService = createMockAuthService();
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.authState).thenReturn(AuthState.authenticated);
      when(() => mockAuthService.currentPublicKeyHex).thenReturn('user-pubkey');
      when(
        () => mockAuthService.authStateStream,
      ).thenAnswer((_) => const Stream<AuthState>.empty());
    });

    Future<void> pumpRouter(
      WidgetTester tester,
      ProviderContainer container, {
      bool activateRouteNormalizer = false,
    }) async {
      if (activateRouteNormalizer) {
        container.read(routeNormalizationProvider);
      }
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    void registerContainerTearDown(
      WidgetTester tester,
      ProviderContainer container,
    ) {
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      });
    }

    MinorAccountReviewStatus restrictedStatus({
      MinorReviewCaseState state =
          MinorReviewCaseState.restrictedPendingUserResponse,
      SuspectedAgeBand ageBand = SuspectedAgeBand.age13To15,
      MinorReviewResolutionType resolution =
          MinorReviewResolutionType.parentVideoOrEmail,
      String? moderationConversationId,
    }) {
      return MinorAccountReviewStatus(
        restrictionStatus: AccountRestrictionStatus.restrictedMinorReview,
        currentCase: MinorReviewCase(
          id: 'case-router',
          state: state,
          suspectedAgeBand: ageBand,
          allowedResolution: resolution,
          instructions: const MinorReviewInstructions(
            title: 'Account review required',
            body: 'We need parental consent information.',
          ),
          supportEmail: 'support@divine.video',
          moderationConversationPubkey: 'moderation-pubkey',
          moderationConversationId: moderationConversationId,
        ),
      );
    }

    testWidgets('redirects restricted accounts to account review', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          ...getStandardTestOverrides(mockAuthService: mockAuthService),
          nostrSessionProvider.overrideWith(_NotReadyNostrSession.new),
          currentMinorAccountReviewStatusProvider.overrideWith(
            (ref) async => restrictedStatus(),
          ),
        ],
      );
      registerContainerTearDown(tester, container);
      await container.read(currentMinorAccountReviewStatusProvider.future);
      await pumpRouter(tester, container);

      final router = container.read(goRouterProvider);
      router.go(VideoFeedPage.pathForIndex(0));
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.toString(),
        MinorAccountReviewScreen.path,
      );
    });

    testWidgets('allows parent contact route while restricted', (tester) async {
      final container = ProviderContainer(
        overrides: [
          ...getStandardTestOverrides(mockAuthService: mockAuthService),
          nostrSessionProvider.overrideWith(_NotReadyNostrSession.new),
          currentMinorAccountReviewStatusProvider.overrideWith(
            (ref) async => restrictedStatus(),
          ),
        ],
      );
      registerContainerTearDown(tester, container);
      await container.read(currentMinorAccountReviewStatusProvider.future);
      await pumpRouter(tester, container, activateRouteNormalizer: true);

      final router = container.read(goRouterProvider);
      router.go(MinorAccountReviewParentContactScreen.path);
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.toString(),
        MinorAccountReviewParentContactScreen.path,
      );
    });

    testWidgets('redirects under-13 cases away from parent contact', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          ...getStandardTestOverrides(mockAuthService: mockAuthService),
          nostrSessionProvider.overrideWith(_NotReadyNostrSession.new),
          currentMinorAccountReviewStatusProvider.overrideWith(
            (ref) async => restrictedStatus(
              state: MinorReviewCaseState.restrictedPendingSupportEmail,
              ageBand: SuspectedAgeBand.under13,
              resolution: MinorReviewResolutionType.supportEmailOnly,
            ),
          ),
        ],
      );
      registerContainerTearDown(tester, container);
      await container.read(currentMinorAccountReviewStatusProvider.future);
      await pumpRouter(tester, container, activateRouteNormalizer: true);

      final router = container.read(goRouterProvider);
      router.go(MinorAccountReviewParentContactScreen.path);
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.toString(),
        MinorAccountReviewUnder13SupportScreen.path,
      );
    });

    testWidgets('parent contact back button falls back to review route', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          ...getStandardTestOverrides(mockAuthService: mockAuthService),
          nostrSessionProvider.overrideWith(_NotReadyNostrSession.new),
          currentMinorAccountReviewStatusProvider.overrideWith(
            (ref) async => restrictedStatus(),
          ),
        ],
      );
      registerContainerTearDown(tester, container);
      await container.read(currentMinorAccountReviewStatusProvider.future);
      await pumpRouter(tester, container);

      final router = container.read(goRouterProvider);
      router.go(MinorAccountReviewParentContactScreen.path);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DiVineAppBarIconButton));
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.toString(),
        MinorAccountReviewScreen.path,
      );
    });

    testWidgets('allows support center route while restricted', (tester) async {
      final container = ProviderContainer(
        overrides: [
          ...getStandardTestOverrides(mockAuthService: mockAuthService),
          bugReportServiceProvider.overrideWith((ref) => BugReportService()),
          nostrSessionProvider.overrideWith(_NotReadyNostrSession.new),
          currentMinorAccountReviewStatusProvider.overrideWith(
            (ref) async => restrictedStatus(),
          ),
        ],
      );
      registerContainerTearDown(tester, container);
      await container.read(currentMinorAccountReviewStatusProvider.future);
      await pumpRouter(tester, container);

      final router = container.read(goRouterProvider);
      router.go(SupportCenterScreen.path);
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.toString(),
        SupportCenterScreen.path,
      );
    });

    testWidgets('allows under-13 support route while restricted', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          ...getStandardTestOverrides(mockAuthService: mockAuthService),
          nostrSessionProvider.overrideWith(_NotReadyNostrSession.new),
          currentMinorAccountReviewStatusProvider.overrideWith(
            (ref) async => restrictedStatus(
              state: MinorReviewCaseState.restrictedPendingSupportEmail,
              ageBand: SuspectedAgeBand.under13,
              resolution: MinorReviewResolutionType.supportEmailOnly,
            ),
          ),
        ],
      );
      registerContainerTearDown(tester, container);
      await container.read(currentMinorAccountReviewStatusProvider.future);
      await pumpRouter(tester, container);

      final router = container.read(goRouterProvider);
      router.go(MinorAccountReviewUnder13SupportScreen.path);
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.toString(),
        MinorAccountReviewUnder13SupportScreen.path,
      );
    });

    testWidgets('under-13 support back button falls back to review route', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          ...getStandardTestOverrides(mockAuthService: mockAuthService),
          nostrSessionProvider.overrideWith(_NotReadyNostrSession.new),
          currentMinorAccountReviewStatusProvider.overrideWith(
            (ref) async => restrictedStatus(
              state: MinorReviewCaseState.restrictedPendingSupportEmail,
              ageBand: SuspectedAgeBand.under13,
              resolution: MinorReviewResolutionType.supportEmailOnly,
            ),
          ),
        ],
      );
      registerContainerTearDown(tester, container);
      await container.read(currentMinorAccountReviewStatusProvider.future);
      await pumpRouter(tester, container);

      final router = container.read(goRouterProvider);
      router.go(MinorAccountReviewUnder13SupportScreen.path);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DiVineAppBarIconButton));
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.toString(),
        MinorAccountReviewScreen.path,
      );
    });

    testWidgets('allows only the case-specific moderation conversation', (
      tester,
    ) async {
      final allowedConversationId = ConversationPage.pathForId('mod-conv-123');
      final container = ProviderContainer(
        overrides: [
          ...getStandardTestOverrides(mockAuthService: mockAuthService),
          nostrSessionProvider.overrideWith(_NotReadyNostrSession.new),
          currentMinorAccountReviewStatusProvider.overrideWith(
            (ref) async =>
                restrictedStatus(moderationConversationId: 'mod-conv-123'),
          ),
        ],
      );
      registerContainerTearDown(tester, container);
      await container.read(currentMinorAccountReviewStatusProvider.future);
      await pumpRouter(tester, container);

      final router = container.read(goRouterProvider);
      router.go(allowedConversationId);

      expect(
        router.routeInformationProvider.value.uri.toString(),
        allowedConversationId,
      );
    });

    testWidgets('redirects non-moderation conversations while restricted', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          ...getStandardTestOverrides(mockAuthService: mockAuthService),
          nostrSessionProvider.overrideWith(_NotReadyNostrSession.new),
          currentMinorAccountReviewStatusProvider.overrideWith(
            (ref) async =>
                restrictedStatus(moderationConversationId: 'mod-conv-123'),
          ),
        ],
      );
      registerContainerTearDown(tester, container);
      await container.read(currentMinorAccountReviewStatusProvider.future);
      await pumpRouter(tester, container);

      final router = container.read(goRouterProvider);
      router.go(ConversationPage.pathForId('other-conversation'));
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.toString(),
        MinorAccountReviewScreen.path,
      );
    });

    testWidgets('shows loading gate while review status is unresolved', (
      tester,
    ) async {
      final completer = Completer<MinorAccountReviewStatus>();
      final container = ProviderContainer(
        overrides: [
          ...getStandardTestOverrides(mockAuthService: mockAuthService),
          nostrSessionProvider.overrideWith(_NotReadyNostrSession.new),
          currentMinorAccountReviewStatusProvider.overrideWith(
            (ref) => completer.future,
          ),
        ],
      );
      registerContainerTearDown(tester, container);
      await pumpRouter(tester, container);

      final routeUri = container
          .read(goRouterProvider)
          .routeInformationProvider
          .value
          .uri;
      expect(routeUri.path, MinorAccountReviewLoadingScreen.path);
    });

    testWidgets(
      'does not bounce to the loading gate during a background refetch',
      (tester) async {
        // Regression: the review status is a FutureProvider that (in prod)
        // depends on currentAuthStateProvider, which invalidates itself on
        // every authStateStream event. A re-run puts the provider into
        // AsyncLoading while retaining its previous value. The router must
        // NOT treat that transient refetch as a cold load and bounce to the
        // loading screen — that redirect is a navigation that tears down the
        // video feed (VideoStopNavigatorObserver disposes all controllers on
        // push), which manifested as videos stopping while swiping the feed.
        //
        // SupportCenterScreen stands in for any non-review authenticated
        // route: the loading-bounce decision is independent of the
        // destination, and it avoids rendering the heavy feed AppShell.
        var loadCount = 0;
        final pendingRefetch = Completer<MinorAccountReviewStatus>();
        final container = ProviderContainer(
          overrides: [
            ...getStandardTestOverrides(mockAuthService: mockAuthService),
            bugReportServiceProvider.overrideWith((ref) => BugReportService()),
            nostrSessionProvider.overrideWith(_NotReadyNostrSession.new),
            currentMinorAccountReviewStatusProvider.overrideWith((ref) {
              loadCount++;
              // First load resolves with an unrestricted status; any later
              // re-run hangs to emulate an in-flight background refetch.
              return loadCount == 1
                  ? Future<MinorAccountReviewStatus>.value(
                      MinorAccountReviewStatus.active(),
                    )
                  : pendingRefetch.future;
            }),
          ],
        );
        registerContainerTearDown(tester, container);
        await container.read(currentMinorAccountReviewStatusProvider.future);
        await pumpRouter(tester, container);

        final router = container.read(goRouterProvider);
        router.go(SupportCenterScreen.path);
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.toString(),
          SupportCenterScreen.path,
        );

        // Trigger a background refetch: the provider re-runs and enters the
        // loading-with-previous-value state (isLoading == true while
        // hasValue == true).
        container.invalidate(currentMinorAccountReviewStatusProvider);
        await tester.pumpAndSettle();
        expect(
          container.read(currentMinorAccountReviewStatusProvider).isLoading,
          isTrue,
        );
        expect(
          container.read(currentMinorAccountReviewStatusProvider).hasValue,
          isTrue,
        );

        // Re-evaluate the redirect while the refetch is in flight (a real
        // navigation, e.g. a swipe-driven page change): it must keep the
        // current route instead of bouncing to the loading screen.
        router.go(SupportCenterScreen.path);
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.toString(),
          SupportCenterScreen.path,
        );
      },
    );

    testWidgets(
      'keeps restricted routing during a background refetch',
      (tester) async {
        var loadCount = 0;
        final pendingRefetch = Completer<MinorAccountReviewStatus>();
        final container = ProviderContainer(
          overrides: [
            ...getStandardTestOverrides(mockAuthService: mockAuthService),
            nostrSessionProvider.overrideWith(_NotReadyNostrSession.new),
            currentMinorAccountReviewStatusProvider.overrideWith((ref) {
              loadCount++;
              return loadCount == 1
                  ? Future<MinorAccountReviewStatus>.value(restrictedStatus())
                  : pendingRefetch.future;
            }),
          ],
        );
        registerContainerTearDown(tester, container);
        await container.read(currentMinorAccountReviewStatusProvider.future);
        await pumpRouter(tester, container);

        final router = container.read(goRouterProvider);
        expect(
          router.routeInformationProvider.value.uri.toString(),
          MinorAccountReviewScreen.path,
        );

        container.invalidate(currentMinorAccountReviewStatusProvider);
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.toString(),
          MinorAccountReviewScreen.path,
        );
        expect(
          container.read(currentMinorAccountReviewStatusProvider).isLoading,
          isTrue,
        );
        expect(
          container.read(currentMinorAccountReviewStatusProvider).hasValue,
          isTrue,
        );

        router.go(MinorAccountReviewScreen.path);
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.toString(),
          MinorAccountReviewScreen.path,
        );

        router.go(VideoFeedPage.pathForIndex(0));
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.toString(),
          MinorAccountReviewScreen.path,
        );
      },
    );

    test(
      'returns authenticated users from welcome review loading to home when active',
      () {
        expect(
          minorAccountReviewReturnLocationForTest(
            Uri(
              path: MinorAccountReviewLoadingScreen.path,
              queryParameters: {'from': '/welcome'},
            ),
          ),
          VideoFeedPage.pathForIndex(0),
        );
      },
    );
  });
}
