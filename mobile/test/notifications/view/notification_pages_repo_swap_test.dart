// ABOUTME: Regression tests for the BlocProvider repo-swap pattern in
// ABOUTME: NotificationsPage + InboxNotificationsPage — verifies that the
// ABOUTME: NotificationFeedBloc is recreated when its Riverpod-provided
// ABOUTME: repositories rebuild (auth flip / sign-out / account switch), so
// ABOUTME: any mark-on-leave wrapper inside the subtree can never fire
// ABOUTME: against the new user's repository while the old user was
// ABOUTME: actually viewing.
//
// Mirrors `conversation_page_repo_swap_test.dart` and the four canonical
// pooled-feed sites referenced in `.claude/rules/state_management.md`.
// The production sites are
// `mobile/lib/notifications/view/notifications_page.dart` and
// `mobile/lib/notifications/view/inbox_notifications_page.dart`, each
// carrying `BlocProvider<NotificationFeedBloc>(key: ValueKey(
// notificationRepository, followRepository), …)`. Without the key,
// the BlocProvider element persists across rebuilds and the bloc stays
// bound to stale repositories — meanwhile `MarkAllReadOnDispose`
// further down the subtree updates its `widget.repository` to whatever
// the rebuilt widget tree captured (the new user's repository). When
// the user later leaves the page, `dispose()` fires `markAllAsRead()`
// against the new user's account, silently consuming notifications
// they never saw.

// ignore_for_file: prefer_const_constructors

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/blocs/invite_status/invite_status_cubit.dart';
import 'package:openvine/notifications/bloc/notification_feed_bloc.dart';
import 'package:openvine/notifications/providers/notification_repository_provider.dart';
import 'package:openvine/notifications/view/inbox_notifications_page.dart';
import 'package:openvine/notifications/view/notifications_page.dart';
import 'package:openvine/notifications/view/notifications_view.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockNotificationRepository extends Mock
    implements NotificationRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockInviteStatusCubit extends MockCubit<InviteStatusState>
    implements InviteStatusCubit {}

/// Toggle a `StateProvider<int>` to force `notificationRepositoryProvider`
/// to rebuild and return a different mock — mirrors what happens in
/// production when auth flips (the real provider rebuilds through the
/// `profileRepositoryProvider`/`authServiceProvider` chain in
/// `notification_repository_provider.dart`).
final _notificationRepoSwap = StateProvider<int>((ref) => 0);

void main() {
  late _MockNotificationRepository mockRepoA;
  late _MockNotificationRepository mockRepoB;
  late _MockFollowRepository mockFollowRepo;
  late _MockInviteStatusCubit mockInviteCubit;

  setUp(() {
    mockRepoA = _MockNotificationRepository();
    mockRepoB = _MockNotificationRepository();
    mockFollowRepo = _MockFollowRepository();
    mockInviteCubit = _MockInviteStatusCubit();

    for (final repo in [mockRepoA, mockRepoB]) {
      when(
        repo.watchSnapshot,
      ).thenAnswer((_) => const Stream<NotificationPage>.empty());
      when(repo.refresh).thenAnswer((_) async => NotificationPage.empty);
      when(repo.markAllAsRead).thenAnswer((_) async {});
    }
    when(() => mockFollowRepo.isFollowing(any())).thenReturn(false);
    when(() => mockInviteCubit.state).thenReturn(InviteStatusState());
    when(mockInviteCubit.load).thenAnswer((_) async {});
  });

  group('NotificationsPage — BlocProvider repo-swap', () {
    Widget buildSubject() {
      return testMaterialApp(
        mockFollowRepository: mockFollowRepo,
        additionalOverrides: [
          notificationRepositoryProvider.overrideWith((ref) {
            final v = ref.watch(_notificationRepoSwap);
            return v == 0 ? mockRepoA : mockRepoB;
          }),
        ],
        home: const NotificationsPage(),
      );
    }

    testWidgets(
      'recreates NotificationFeedBloc when notificationRepositoryProvider '
      'rebuilds with a new repository instance',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        // Capture the bloc that was created when the page first built.
        final viewContextBefore = tester.element(
          find.byType(NotificationsView),
        );
        final blocA = BlocProvider.of<NotificationFeedBloc>(viewContextBefore);
        expect(blocA.isClosed, isFalse, reason: 'initial bloc should be alive');
        verify(() => mockRepoA.refresh()).called(1);
        verifyNever(() => mockRepoB.refresh());

        // Flip the toggle. notificationRepositoryProvider rebuilds,
        // NotificationsPage's ref.watch fires, the ValueKey on the
        // BlocProvider changes, the old element is torn down and a new
        // bloc is constructed wrapping mockRepoB.
        final providerScope = ProviderScope.containerOf(
          tester.element(find.byType(NotificationsPage)),
        );
        providerScope.read(_notificationRepoSwap.notifier).state = 1;
        await tester.pumpAndSettle();

        final viewContextAfter = tester.element(find.byType(NotificationsView));
        final blocB = BlocProvider.of<NotificationFeedBloc>(viewContextAfter);

        expect(
          blocB,
          isNot(same(blocA)),
          reason:
              'BlocProvider must create a new NotificationFeedBloc when '
              'notificationRepository identity flips. Without the '
              'ValueKey on the BlocProvider, the bloc would keep using '
              'the stale repository, while MarkAllReadOnDispose further '
              'down the subtree would update its widget.repository to '
              'the new user — causing mark-all-read on the wrong user '
              'when the user later leaves the page.',
        );
        verify(() => mockRepoB.refresh()).called(1);
      },
    );

    testWidgets('preserves the same NotificationFeedBloc when the repository '
        'identity does not change across rebuilds', (tester) async {
      await tester.pumpWidget(
        testMaterialApp(
          mockFollowRepository: mockFollowRepo,
          additionalOverrides: [
            notificationRepositoryProvider.overrideWith((ref) {
              ref.watch(_notificationRepoSwap);
              return mockRepoA; // identity stays the same
            }),
          ],
          home: const NotificationsPage(),
        ),
      );
      await tester.pumpAndSettle();

      final blocA = BlocProvider.of<NotificationFeedBloc>(
        tester.element(find.byType(NotificationsView)),
      );

      final providerScope = ProviderScope.containerOf(
        tester.element(find.byType(NotificationsPage)),
      );
      providerScope.read(_notificationRepoSwap.notifier).state = 1;
      await tester.pumpAndSettle();

      final blocAfter = BlocProvider.of<NotificationFeedBloc>(
        tester.element(find.byType(NotificationsView)),
      );

      expect(
        blocAfter,
        same(blocA),
        reason:
            'Identical repository identity should keep the same bloc '
            '— the ValueKey prevents unnecessary churn on rebuilds.',
      );
      // Refresh should fire exactly once — the same bloc handled both
      // pump cycles and NotificationFeedStarted is dispatched once.
      verify(() => mockRepoA.refresh()).called(1);
    });
  });

  group('InboxNotificationsPage — BlocProvider repo-swap', () {
    Widget buildSubject() {
      return testMaterialApp(
        mockFollowRepository: mockFollowRepo,
        additionalOverrides: [
          notificationRepositoryProvider.overrideWith((ref) {
            final v = ref.watch(_notificationRepoSwap);
            return v == 0 ? mockRepoA : mockRepoB;
          }),
        ],
        home: BlocProvider<InviteStatusCubit>.value(
          value: mockInviteCubit,
          child: Scaffold(body: const InboxNotificationsPage()),
        ),
      );
    }

    testWidgets(
      'recreates NotificationFeedBloc when notificationRepositoryProvider '
      'rebuilds with a new repository instance',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        final viewContextBefore = tester.element(
          find.byType(NotificationsView).first,
        );
        final blocA = BlocProvider.of<NotificationFeedBloc>(viewContextBefore);
        expect(blocA.isClosed, isFalse);
        verify(() => mockRepoA.refresh()).called(1);
        verifyNever(() => mockRepoB.refresh());

        final providerScope = ProviderScope.containerOf(
          tester.element(find.byType(InboxNotificationsPage)),
        );
        providerScope.read(_notificationRepoSwap.notifier).state = 1;
        await tester.pumpAndSettle();

        final viewContextAfter = tester.element(
          find.byType(NotificationsView).first,
        );
        final blocB = BlocProvider.of<NotificationFeedBloc>(viewContextAfter);

        expect(
          blocB,
          isNot(same(blocA)),
          reason:
              'The inbox-wrapped notifications page also needs the '
              'ValueKey contract — the upstream KeyedSubtree in '
              'inbox_view.dart provides one layer of protection today, '
              'but if that wrapper is restructured the BlocProvider key '
              'is what keeps the bloc/repository identity coupled.',
        );
        verify(() => mockRepoB.refresh()).called(1);
      },
    );
  });
}
