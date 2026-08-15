// ABOUTME: Widget tests for InboxNotificationsPage — verifies that opening
// ABOUTME: the inbox marks notifications seen once (advances the read
// ABOUTME: watermark, #4708) and that each tab opens its own filtered feed.

// ignore_for_file: prefer_const_constructors

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:invite_api_client/invite_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/blocs/invite_availability/invite_availability_cubit.dart';
import 'package:openvine/blocs/invite_status/invite_status_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/notifications/providers/notification_repository_provider.dart';
import 'package:openvine/notifications/view/inbox_notifications_page.dart';

import '../../helpers/invite_availability_harness.dart';
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
        () => mockNotificationRepo.watchSnapshot(filter: any(named: 'filter')),
      ).thenAnswer((_) => const Stream<NotificationPage>.empty());
      when(
        () => mockNotificationRepo.refreshFeed(any()),
      ).thenAnswer((_) async => NotificationPage.empty);
      when(() => mockNotificationRepo.markAllAsRead()).thenAnswer((_) async {});
      when(() => mockFollowRepo.isFollowing(any())).thenReturn(false);
      when(() => mockInviteCubit.state).thenReturn(InviteStatusState());
      when(mockInviteCubit.load).thenAnswer((_) async {});
    });

    Widget buildSubject({
      bool reduceMotion = false,
      InviteAvailabilityCubit? availabilityCubit,
    }) {
      return testMaterialApp(
        mockFollowRepository: mockFollowRepo,
        additionalOverrides: [
          notificationRepositoryProvider.overrideWithValue(
            mockNotificationRepo,
          ),
        ],
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reduceMotion),
            child: MultiBlocProvider(
              providers: [
                if (availabilityCubit != null)
                  BlocProvider<InviteAvailabilityCubit>.value(
                    value: availabilityCubit,
                  ),
                BlocProvider<InviteStatusCubit>.value(value: mockInviteCubit),
              ],
              child: Scaffold(body: const InboxNotificationsPage()),
            ),
          ),
        ),
      );
    }

    testWidgets('opens the bloc via NotificationFeedStarted on first build', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Opening the inbox refreshes and marks notifications seen (advances the
      // server read watermark) so the badge reflects "new since last seen"
      // (#4708).
      verify(() => mockNotificationRepo.refreshFeed(null)).called(1);
      verify(() => mockNotificationRepo.markAllAsRead()).called(1);
    });

    testWidgets(
      'marks seen on open but not again when the inbox page is unmounted',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();
        // Marked seen exactly once on open.
        verify(() => mockNotificationRepo.markAllAsRead()).called(1);
        clearInteractions(mockNotificationRepo);

        // Leaving the inbox (toggling to the Messages segment so the
        // notifications KeyedSubtree is swapped out, or leaving the inbox tab
        // so the ShellRoute unmounts the subtree) must NOT mark read again on
        // *leave* — #4758 removed the old mark-on-dispose. #4708 added
        // mark-on-open, and pull-to-refresh can also mark while the
        // notifications surface is deliberately open.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();

        verifyNever(() => mockNotificationRepo.markAllAsRead());
      },
    );

    testWidgets(
      'opens each tab against its own server-filtered feed and marks seen '
      'only on the All tab',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        // Tab order is load-bearing: each index must open the feed its label
        // promises, or a transposed entry silently shows e.g. reposts under
        // Comments.
        const tabFilters = <NotificationKind>[
          NotificationKind.like,
          NotificationKind.comment,
          NotificationKind.follow,
          NotificationKind.repost,
        ];

        verify(() => mockNotificationRepo.refreshFeed(null)).called(1);

        for (var i = 0; i < tabFilters.length; i++) {
          await tester.tap(find.byType(Tab).at(i + 1));
          await tester.pumpAndSettle();

          // Asserted per tap, not as a set at the end — a set assertion
          // passes even when two tabs are swapped.
          verify(
            () => mockNotificationRepo.refreshFeed(tabFilters[i]),
          ).called(1);
        }

        // The seen watermark advances for the unfiltered feed (#4708) —
        // never once per filter tab.
        verify(() => mockNotificationRepo.markAllAsRead()).called(1);
      },
    );

    testWidgets('keeps visited tab blocs alive across tab switches', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      verify(() => mockNotificationRepo.refreshFeed(null)).called(1);
      verify(() => mockNotificationRepo.markAllAsRead()).called(1);
      clearInteractions(mockNotificationRepo);

      await tester.tap(find.byType(Tab).at(1));
      await tester.pumpAndSettle();

      verify(
        () => mockNotificationRepo.refreshFeed(NotificationKind.like),
      ).called(1);
      verifyNever(() => mockNotificationRepo.markAllAsRead());
      clearInteractions(mockNotificationRepo);

      await tester.tap(find.byType(Tab).at(0));
      await tester.pumpAndSettle();

      verifyNever(() => mockNotificationRepo.refreshFeed(null));
      verifyNever(() => mockNotificationRepo.markAllAsRead());
    });

    group('reduced motion', () {
      TabController controller(WidgetTester tester) =>
          tester.widget<TabBar>(find.byType(TabBar)).controller!;

      testWidgets('switches tabs without sliding the indicator or the page', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject(reduceMotion: true));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(Tab).at(3));
        await tester.pump();

        // The controller's animation drives both the indicator slide and the
        // TabBarView page offset, so landing on the target in the first frame
        // is the whole transition resolving instantly.
        expect(controller(tester).animation!.value, equals(3.0));
        expect(controller(tester).indexIsChanging, isFalse);
      });

      testWidgets('still animates when reduced motion is off', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.tap(find.byType(Tab).at(3));
        await tester.pump();

        expect(controller(tester).animation!.value, lessThan(3.0));
        await tester.pumpAndSettle();
        expect(controller(tester).animation!.value, equals(3.0));
      });

      testWidgets('keeps the open tab when the setting is toggled', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();
        await tester.tap(find.byType(Tab).at(2));
        await tester.pumpAndSettle();

        // The controller is rebuilt to pick up the new duration; the tab the
        // user was reading must survive that swap.
        await tester.pumpWidget(buildSubject(reduceMotion: true));
        await tester.pumpAndSettle();

        expect(controller(tester).index, equals(2));
        expect(controller(tester).animationDuration, equals(Duration.zero));
      });
    });

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
        (tester) async {
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

      testWidgets('hides the invite card when signup invites are disabled', (
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
        final availabilityCubit = seededInviteAvailabilityCubit(
          serverMode: OnboardingMode.open,
        );
        addTearDown(availabilityCubit.close);

        await tester.pumpWidget(
          buildSubject(availabilityCubit: availabilityCubit),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.notificationsInvitePlural(2)), findsNothing);
      });

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
