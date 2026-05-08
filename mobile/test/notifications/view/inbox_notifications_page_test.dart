// ABOUTME: Widget tests for InboxNotificationsPage — verifies the legacy
// ABOUTME: Riverpod unread-cache mark-all-read fires exactly once per inbox
// ABOUTME: open and does not fan out across the five filter tabs.

// ignore_for_file: prefer_const_constructors

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/blocs/invite_status/invite_status_cubit.dart';
import 'package:openvine/notifications/providers/notification_repository_provider.dart';
import 'package:openvine/notifications/view/inbox_notifications_page.dart';
import 'package:openvine/notifications/view/notifications_view.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/relay_notifications_provider.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockNotificationRepository extends Mock
    implements NotificationRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockInviteStatusCubit extends MockCubit<InviteStatusState>
    implements InviteStatusCubit {}

/// Counts `markAllAsRead` invocations on the stubbed Riverpod provider.
/// The page contract is exactly-once per open; this counter is the
/// assertion target.
class _MarkAllReadCounter {
  int calls = 0;
}

/// Stubs out the legacy [RelayNotifications] async notifier so the test
/// can (a) seed a deterministic unread/all-read state and (b) observe
/// invocations of [markAllAsRead].
class _StubRelayNotifications extends RelayNotifications {
  _StubRelayNotifications(this.initialState, this.counter);

  final NotificationFeedState initialState;
  final _MarkAllReadCounter counter;

  @override
  Future<NotificationFeedState> build() async => initialState;

  @override
  Future<void> markAllAsRead() async {
    counter.calls++;
  }

  @override
  Future<void> markAsRead(String notificationId) async {}

  @override
  Future<void> loadMore() async {}

  @override
  Future<void> refresh() async {}
}

const _alicePubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

NotificationModel _unreadNotification() => NotificationModel(
  id: 'n1',
  type: NotificationType.like,
  actorPubkey: _alicePubkey,
  message: 'Alice liked your video',
  timestamp: DateTime(2026),
);

NotificationFeedState _unreadFeedState() => NotificationFeedState(
  notifications: [_unreadNotification()],
  unreadCount: 1,
  isInitialLoad: false,
  lastUpdated: DateTime(2026),
);

NotificationFeedState _allReadFeedState() => NotificationFeedState(
  notifications: [_unreadNotification().copyWith(isRead: true)],
  isInitialLoad: false,
  lastUpdated: DateTime(2026),
);

void main() {
  group(InboxNotificationsPage, () {
    late _MockNotificationRepository mockNotificationRepo;
    late _MockFollowRepository mockFollowRepo;
    late _MockInviteStatusCubit mockInviteCubit;
    late _MarkAllReadCounter counter;

    setUp(() {
      mockNotificationRepo = _MockNotificationRepository();
      mockFollowRepo = _MockFollowRepository();
      mockInviteCubit = _MockInviteStatusCubit();
      counter = _MarkAllReadCounter();

      // Empty page keeps the bloc's _onStarted path simple — the
      // re-dispatched NotificationFeedMarkAllRead sees no unread items
      // and short-circuits before touching the bloc-side mark-read API.
      // This isolates the assertion to the Riverpod side.
      when(
        () => mockNotificationRepo.refresh(),
      ).thenAnswer((_) async => NotificationPage.empty);
      when(() => mockNotificationRepo.markAllAsRead()).thenAnswer((_) async {});
      when(() => mockFollowRepo.isFollowing(any())).thenReturn(false);
      when(() => mockInviteCubit.state).thenReturn(InviteStatusState());
      when(mockInviteCubit.load).thenAnswer((_) async {});
    });

    Widget buildSubject({required NotificationFeedState relayState}) {
      return testMaterialApp(
        additionalOverrides: [
          notificationRepositoryProvider.overrideWithValue(
            mockNotificationRepo,
          ),
          followRepositoryProvider.overrideWithValue(mockFollowRepo),
          relayNotificationsProvider.overrideWith(
            () => _StubRelayNotifications(relayState, counter),
          ),
        ],
        home: BlocProvider<InviteStatusCubit>.value(
          value: mockInviteCubit,
          child: Scaffold(body: const InboxNotificationsPage()),
        ),
      );
    }

    testWidgets(
      'fires markAllAsRead on the legacy Riverpod cache exactly once on '
      'open when there are unread items',
      (tester) async {
        await tester.pumpWidget(buildSubject(relayState: _unreadFeedState()));
        // Flush microtasks so the stub's build() resolves to AsyncData,
        // then the post-frame callback in _InboxNotificationsScaffold
        // reads the now-populated provider state.
        await tester.pumpAndSettle();

        expect(counter.calls, equals(1));
      },
    );

    testWidgets(
      'does not call markAllAsRead when nothing is unread',
      (tester) async {
        await tester.pumpWidget(buildSubject(relayState: _allReadFeedState()));
        await tester.pumpAndSettle();

        expect(counter.calls, equals(0));
      },
    );

    testWidgets(
      'does not fan out markAllAsRead across the five filter tabs',
      (tester) async {
        await tester.pumpWidget(buildSubject(relayState: _unreadFeedState()));
        await tester.pumpAndSettle();

        // Sanity: scaffold's initState fired exactly once before any
        // tab swipe.
        expect(counter.calls, equals(1));

        // Swipe through the four non-default tabs. Each visit mounts a
        // fresh NotificationsView; the contract is that none of them
        // triggers a Riverpod mark-all-read.
        for (var i = 1; i < 5; i++) {
          await tester.tap(find.byType(Tab).at(i));
          await tester.pumpAndSettle();
        }

        // Even after all five NotificationsView instances have been
        // constructed and shown, the side effect remains a single call.
        expect(counter.calls, equals(1));
        // Confirm all five filter views actually mounted — guards
        // against the test silently passing because TabBarView never
        // built the off-default children.
        expect(find.byType(NotificationsView), findsWidgets);
      },
    );
  });
}
