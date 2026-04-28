import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/minor_account_review_parent_contact_screen.dart';
import 'package:openvine/screens/minor_account_review_screen.dart';
import 'package:openvine/services/auth_service.dart';

import '../helpers/test_provider_overrides.dart';

void main() {
  group('Minor account review router gating', () {
    late MockAuthService mockAuthService;

    setUp(() {
      resetNavigationState();
      mockAuthService = createMockAuthService();
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.authState).thenReturn(AuthState.authenticated);
      when(
        () => mockAuthService.authStateStream,
      ).thenAnswer((_) => const Stream<AuthState>.empty());
    });

    testWidgets('redirects restricted accounts to account review', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          ...getStandardTestOverrides(mockAuthService: mockAuthService),
          currentMinorAccountReviewStatusProvider.overrideWith((ref) async {
            return const MinorAccountReviewStatus(
              restrictionStatus:
                  AccountRestrictionStatus.restrictedMinorReview,
              currentCase: MinorReviewCase(
                id: 'case-router',
                state: MinorReviewCaseState.restrictedPendingUserResponse,
                suspectedAgeBand: SuspectedAgeBand.age13To15,
                allowedResolution:
                    MinorReviewResolutionType.parentVideoOrEmail,
                instructions: MinorReviewInstructions(
                  title: 'Account review required',
                  body: 'We need parental consent information.',
                ),
                supportEmail: 'support@divine.video',
              ),
            );
          }),
        ],
      );
      addTearDown(container.dispose);
      await container.read(currentMinorAccountReviewStatusProvider.future);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );
      await tester.pumpAndSettle();

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
          currentMinorAccountReviewStatusProvider.overrideWith((ref) async {
            return const MinorAccountReviewStatus(
              restrictionStatus:
                  AccountRestrictionStatus.restrictedMinorReview,
              currentCase: MinorReviewCase(
                id: 'case-router',
                state: MinorReviewCaseState.restrictedPendingUserResponse,
                suspectedAgeBand: SuspectedAgeBand.age13To15,
                allowedResolution:
                    MinorReviewResolutionType.parentVideoOrEmail,
                instructions: MinorReviewInstructions(
                  title: 'Account review required',
                  body: 'We need parental consent information.',
                ),
                supportEmail: 'support@divine.video',
              ),
            );
          }),
        ],
      );
      addTearDown(container.dispose);
      await container.read(currentMinorAccountReviewStatusProvider.future);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final router = container.read(goRouterProvider);
      router.go(MinorAccountReviewParentContactScreen.path);
      await tester.pumpAndSettle();

      expect(
        router.routeInformationProvider.value.uri.toString(),
        MinorAccountReviewParentContactScreen.path,
      );
    });
  });
}
