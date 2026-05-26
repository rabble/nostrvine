// ABOUTME: Widget tests for InboxNotificationsPage — verifies that opening
// ABOUTME: the inbox refreshes once without implicitly mutating read state.

// ignore_for_file: prefer_const_constructors

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:invite_api_client/invite_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/blocs/invite_status/invite_status_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/notifications/providers/notification_repository_provider.dart';
import 'package:openvine/notifications/view/inbox_notifications_page.dart';
import 'package:openvine/notifications/view/notifications_view.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockNotificationRepository extends Mock
    implements NotificationRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockInviteStatusCubit extends MockCubit<InviteStatusState>
    implements InviteStatusCubit {}

void main() {
  group(InboxNotificationsPage, () {
    late _MockNotificationRepository mockNotificationRepo;
    late _MockFollowRepository mockFollowRepo;
    late _MockInviteStatusCubit mockInviteCubit;

    setUp(() {
      mockNotificationRepo = _MockNotificationRepository();
      mockFollowRepo = _MockFollowRepository();
      mockInviteCubit = _MockInviteStatusCubit();

      when(
        () => mockNotificationRepo.watchSnapshot(),
      ).thenAnswer((_) => const Stream<NotificationPage>.empty());
      when(
        () => mockNotificationRepo.refresh(),
      ).thenAnswer((_) async => NotificationPage.empty);
      when(
        () => mockNotificationRepo.markAllAsRead(),
      ).thenAnswer((_) async {});
      when(() => mockFollowRepo.isFollowing(any())).thenReturn(false);
      when(() => mockInviteCubit.state).thenReturn(InviteStatusState());
      when(mockInviteCubit.load).thenAnswer((_) async {});
    });

    Widget buildSubject() {
      return testMaterialApp(
        mockFollowRepository: mockFollowRepo,
        additionalOverrides: [
          notificationRepositoryProvider.overrideWithValue(
            mockNotificationRepo,
          ),
        ],
        home: BlocProvider<InviteStatusCubit>.value(
          value: mockInviteCubit,
          child: Scaffold(body: const InboxNotificationsPage()),
        ),
      );
    }

    testWidgets('opens the bloc via NotificationFeedStarted on first build', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      verify(() => mockNotificationRepo.refresh()).called(1);
      verifyNever(() => mockNotificationRepo.markAllAsRead());
    });

    testWidgets(
      'does not mark notifications read when the inbox page is unmounted',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();
        verifyNever(() => mockNotificationRepo.markAllAsRead());

        // Leaving the inbox (toggling to the Messages segment so the
        // notifications KeyedSubtree is swapped out, or leaving the inbox tab
        // so the ShellRoute unmounts the subtree) must NOT auto-zero unread
        // state. Read transitions are deliberate only. See #4729.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();

        verifyNever(() => mockNotificationRepo.markAllAsRead());
      },
    );

    testWidgets(
      'does not fan out refresh or mark-read across the five filter tabs',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        // Swipe through the four non-default tabs. Each visit mounts a
        // fresh NotificationsView; the contract is that none of them
        // triggers another refresh or implicit mark-all-read.
        for (var i = 1; i < 5; i++) {
          await tester.tap(find.byType(Tab).at(i));
          await tester.pumpAndSettle();
        }

        // Exactly one refresh and no implicit markAllAsRead across the
        // whole inbox-open lifecycle, even after all five filter views
        // have mounted.
        verify(() => mockNotificationRepo.refresh()).called(1);
        verifyNever(() => mockNotificationRepo.markAllAsRead());
        // Confirm all five filter views actually mounted — guards
        // against the test silently passing because TabBarView never
        // built the off-default children.
        expect(find.byType(NotificationsView), findsWidgets);
      },
    );

    group('invite banner', () {
      // Restores show/hide coverage that the deleted
      // notifications_screen_test.dart asserted before #3567 removed
      // the legacy screen. The banner is gated on
      // InviteStatusState.hasAvailableInvites (true when remaining > 0).
      final l10n = lookupAppLocalizations(const Locale('en'));

      testWidgets('renders the invite card when invites are available', (
        tester,
      ) async {
        when(() => mockInviteCubit.state).thenReturn(
          const InviteStatusState(
            status: InviteStatusLoadingStatus.loaded,
            inviteStatus: InviteStatus(
              canInvite: true,
              remaining: 2,
              total: 2,
              codes: [
                InviteCode(code: 'AB23-EF7K', claimed: false),
                InviteCode(code: 'HN4P-QR56', claimed: false),
              ],
            ),
          ),
        );

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(find.text(l10n.notificationsInvitePlural(2)), findsOneWidget);
      });

      testWidgets(
        'renders the singular label when exactly one invite is left',
        (
          tester,
        ) async {
          when(() => mockInviteCubit.state).thenReturn(
            const InviteStatusState(
              status: InviteStatusLoadingStatus.loaded,
              inviteStatus: InviteStatus(
                canInvite: true,
                remaining: 1,
                total: 2,
                codes: [InviteCode(code: 'AB23-EF7K', claimed: false)],
              ),
            ),
          );

          await tester.pumpWidget(buildSubject());
          await tester.pumpAndSettle();

          expect(find.text(l10n.notificationsInviteSingular), findsOneWidget);
        },
      );

      testWidgets('hides the invite card when no invites are available', (
        tester,
      ) async {
        // Default state from setUp() already has no invites, but be
        // explicit to pin the intent.
        when(() => mockInviteCubit.state).thenReturn(
          const InviteStatusState(
            status: InviteStatusLoadingStatus.loaded,
            inviteStatus: InviteStatus(
              canInvite: false,
              remaining: 0,
              total: 0,
              codes: [],
            ),
          ),
        );

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(find.text(l10n.notificationsInviteSingular), findsNothing);
        expect(find.text(l10n.notificationsInvitePlural(2)), findsNothing);
      });
    });
  });
}
