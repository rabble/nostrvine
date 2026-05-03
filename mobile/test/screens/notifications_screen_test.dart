// ABOUTME: Widget tests for NotificationsScreen covering list rendering and tab filtering
// ABOUTME: Tests empty state, notification sorting, tab filtering, and mark as read

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/invite_status/invite_status_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/invite_models.dart';
import 'package:openvine/providers/relay_notifications_provider.dart';
import 'package:openvine/screens/notifications_screen.dart';
import 'package:openvine/widgets/notification_list_item.dart';

class _MockInviteStatusCubit extends MockCubit<InviteStatusState>
    implements InviteStatusCubit {}

/// Mock notifier that returns test notifications
class _MockRelayNotifications extends RelayNotifications {
  final List<NotificationModel> _notifications;
  final bool _hasMoreContent;
  final bool _isLoadingMore;
  final bool _isRefreshing;
  final List<String> markedAsReadIds = [];
  bool markAllAsReadCalled = false;
  int loadMoreCalls = 0;

  _MockRelayNotifications(
    this._notifications, {
    bool hasMoreContent = false,
    bool isLoadingMore = false,
    bool isRefreshing = false,
  }) : _hasMoreContent = hasMoreContent,
       _isLoadingMore = isLoadingMore,
       _isRefreshing = isRefreshing;

  @override
  Future<NotificationFeedState> build() async {
    return NotificationFeedState(
      notifications: _notifications,
      hasMoreContent: _hasMoreContent,
      isLoadingMore: _isLoadingMore,
      isRefreshing: _isRefreshing,
      isInitialLoad: false,
      lastUpdated: DateTime.now(),
    );
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    markedAsReadIds.add(notificationId);
  }

  @override
  Future<void> markAllAsRead() async {
    markAllAsReadCalled = true;
  }

  @override
  Future<void> loadMore() async {
    loadMoreCalls++;
  }

  @override
  Future<void> refresh() async {}
}

/// Mock notifier that returns empty list
class _MockEmptyRelayNotifications extends RelayNotifications {
  bool markAllAsReadCalled = false;
  int loadMoreCalls = 0;

  @override
  Future<NotificationFeedState> build() async {
    return NotificationFeedState(
      notifications: const [],
      isInitialLoad: false,
      lastUpdated: DateTime.now(),
    );
  }

  @override
  Future<void> markAsRead(String notificationId) async {}

  @override
  Future<void> markAllAsRead() async {
    markAllAsReadCalled = true;
  }

  @override
  Future<void> loadMore() async {
    loadMoreCalls++;
  }

  @override
  Future<void> refresh() async {}
}

void main() {
  // Full 64-char test pubkeys
  const pubkeyAlice =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const pubkeyBob =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const pubkeyCharlie =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
  const eventId1 =
      'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';

  /// Build the NotificationsScreen directly in a ProviderScope
  Widget buildScreenWidget(
    RelayNotifications Function() notifierFactory, {
    InviteStatusState inviteStatusState = const InviteStatusState(),
    _MockInviteStatusCubit? inviteCubit,
  }) {
    final mockInviteCubit = inviteCubit ?? _MockInviteStatusCubit();
    when(() => mockInviteCubit.state).thenReturn(inviteStatusState);
    when(mockInviteCubit.load).thenAnswer((_) async {});
    return ProviderScope(
      overrides: [relayNotificationsProvider.overrideWith(notifierFactory)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData.dark(),
        home: BlocProvider<InviteStatusCubit>.value(
          value: mockInviteCubit,
          child: const Scaffold(
            body: NotificationsScreen(skipInitialBootstrapForTesting: true),
          ),
        ),
      ),
    );
  }

  group(NotificationsScreen, () {
    group('notification list rendering', () {
      testWidgets('renders notifications sorted by time (newest first)', (
        WidgetTester tester,
      ) async {
        final now = DateTime.now();
        // Provide notifications pre-sorted newest-first (as API returns them).
        // The "All" tab returns them in state order via the provider.
        final notifications = [
          NotificationModel(
            id: 'notif-newest',
            type: NotificationType.follow,
            actorPubkey: pubkeyBob,
            actorName: 'Bob',
            message: 'Bob started following you',
            timestamp: now.subtract(const Duration(minutes: 5)),
          ),
          NotificationModel(
            id: 'notif-middle',
            type: NotificationType.comment,
            actorPubkey: pubkeyCharlie,
            actorName: 'Charlie',
            message: 'Charlie commented on your video',
            timestamp: now.subtract(const Duration(hours: 1)),
            metadata: const {'comment': 'Great!'},
          ),
          NotificationModel(
            id: 'notif-oldest',
            type: NotificationType.like,
            actorPubkey: pubkeyAlice,
            actorName: 'Alice',
            message: 'Alice liked your video',
            timestamp: now.subtract(const Duration(hours: 2)),
          ),
        ];

        final mockNotifier = _MockRelayNotifications(notifications);
        await tester.pumpWidget(buildScreenWidget(() => mockNotifier));
        await tester.pumpAndSettle();

        // Should render notification list items
        expect(find.byType(NotificationListItem), findsWidgets);

        // Notifications displayed in order (newest first as provided)
        final items = tester
            .widgetList<NotificationListItem>(find.byType(NotificationListItem))
            .toList();
        expect(items.length, equals(3));
        expect(items[0].notification.id, equals('notif-newest'));
        expect(items[1].notification.id, equals('notif-middle'));
        expect(items[2].notification.id, equals('notif-oldest'));
      });
    });

    group('tab filtering', () {
      testWidgets('tapping Likes tab shows only like notifications', (
        WidgetTester tester,
      ) async {
        final now = DateTime.now();
        final notifications = [
          NotificationModel(
            id: 'like-1',
            type: NotificationType.like,
            actorPubkey: pubkeyAlice,
            actorName: 'Alice',
            message: 'Alice liked your video',
            timestamp: now.subtract(const Duration(minutes: 1)),
          ),
          NotificationModel(
            id: 'follow-1',
            type: NotificationType.follow,
            actorPubkey: pubkeyBob,
            actorName: 'Bob',
            message: 'Bob started following you',
            timestamp: now.subtract(const Duration(minutes: 2)),
          ),
          NotificationModel(
            id: 'comment-1',
            type: NotificationType.comment,
            actorPubkey: pubkeyCharlie,
            actorName: 'Charlie',
            message: 'Charlie commented on your video',
            timestamp: now.subtract(const Duration(minutes: 3)),
            metadata: const {'comment': 'Awesome!'},
          ),
        ];

        final mockNotifier = _MockRelayNotifications(notifications);
        await tester.pumpWidget(buildScreenWidget(() => mockNotifier));
        await tester.pumpAndSettle();

        // Initially "All" tab shows all notifications
        expect(find.byType(NotificationListItem), findsNWidgets(3));

        // Tap on "Likes" tab
        await tester.tap(find.text('Likes'));
        await tester.pumpAndSettle();

        // Should only show like notifications
        final items = tester
            .widgetList<NotificationListItem>(find.byType(NotificationListItem))
            .toList();
        expect(items.length, equals(1));
        expect(items[0].notification.type, equals(NotificationType.like));
      });

      testWidgets('tapping Comments tab shows only comment notifications', (
        WidgetTester tester,
      ) async {
        final now = DateTime.now();
        final notifications = [
          NotificationModel(
            id: 'like-1',
            type: NotificationType.like,
            actorPubkey: pubkeyAlice,
            actorName: 'Alice',
            message: 'Alice liked your video',
            timestamp: now.subtract(const Duration(minutes: 1)),
          ),
          NotificationModel(
            id: 'comment-1',
            type: NotificationType.comment,
            actorPubkey: pubkeyBob,
            actorName: 'Bob',
            message: 'Bob commented on your video',
            timestamp: now.subtract(const Duration(minutes: 2)),
            metadata: const {'comment': 'Cool!'},
          ),
        ];

        final mockNotifier = _MockRelayNotifications(notifications);
        await tester.pumpWidget(buildScreenWidget(() => mockNotifier));
        await tester.pumpAndSettle();

        // Tap on "Comments" tab
        await tester.tap(find.text('Comments'));
        await tester.pumpAndSettle();

        final items = tester
            .widgetList<NotificationListItem>(find.byType(NotificationListItem))
            .toList();
        expect(items.length, equals(1));
        expect(items[0].notification.type, equals(NotificationType.comment));
      });

      testWidgets('tapping Follows tab shows only follow notifications', (
        WidgetTester tester,
      ) async {
        final now = DateTime.now();
        final notifications = [
          NotificationModel(
            id: 'like-1',
            type: NotificationType.like,
            actorPubkey: pubkeyAlice,
            actorName: 'Alice',
            message: 'Alice liked your video',
            timestamp: now.subtract(const Duration(minutes: 1)),
          ),
          NotificationModel(
            id: 'follow-1',
            type: NotificationType.follow,
            actorPubkey: pubkeyBob,
            actorName: 'Bob',
            message: 'Bob started following you',
            timestamp: now.subtract(const Duration(minutes: 2)),
          ),
        ];

        final mockNotifier = _MockRelayNotifications(notifications);
        await tester.pumpWidget(buildScreenWidget(() => mockNotifier));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Follows'));
        await tester.pumpAndSettle();

        final items = tester
            .widgetList<NotificationListItem>(find.byType(NotificationListItem))
            .toList();
        expect(items.length, equals(1));
        expect(items[0].notification.type, equals(NotificationType.follow));
      });

      testWidgets('tapping Reposts tab shows only repost notifications', (
        WidgetTester tester,
      ) async {
        final now = DateTime.now();
        final notifications = [
          NotificationModel(
            id: 'like-1',
            type: NotificationType.like,
            actorPubkey: pubkeyAlice,
            actorName: 'Alice',
            message: 'Alice liked your video',
            timestamp: now.subtract(const Duration(minutes: 1)),
          ),
          NotificationModel(
            id: 'repost-1',
            type: NotificationType.repost,
            actorPubkey: pubkeyBob,
            actorName: 'Bob',
            message: 'Bob reposted your video',
            timestamp: now.subtract(const Duration(minutes: 2)),
            targetEventId: eventId1,
          ),
        ];

        final mockNotifier = _MockRelayNotifications(notifications);
        await tester.pumpWidget(buildScreenWidget(() => mockNotifier));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Reposts'));
        await tester.pumpAndSettle();

        final items = tester
            .widgetList<NotificationListItem>(find.byType(NotificationListItem))
            .toList();
        expect(items.length, equals(1));
        expect(items[0].notification.type, equals(NotificationType.repost));
      });
    });

    group('empty state', () {
      testWidgets('shows empty state when no notifications', (
        WidgetTester tester,
      ) async {
        final mockNotifier = _MockEmptyRelayNotifications();
        await tester.pumpWidget(buildScreenWidget(() => mockNotifier));
        await tester.pumpAndSettle();

        expect(find.text('No notifications yet'), findsOneWidget);
        expect(find.byType(NotificationListItem), findsNothing);
      });

      testWidgets('hides invite card when remaining is zero', (
        WidgetTester tester,
      ) async {
        final mockNotifier = _MockEmptyRelayNotifications();
        await tester.pumpWidget(
          buildScreenWidget(
            () => mockNotifier,
            inviteStatusState: const InviteStatusState(
              status: InviteStatusLoadingStatus.loaded,
              inviteStatus: InviteStatus(
                canInvite: true,
                remaining: 0,
                total: 2,
                codes: [
                  InviteCode(code: 'AB23-EF7K', claimed: false),
                  InviteCode(code: 'HN4P-QR56', claimed: false),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('You have 2 invites to share with friends!'),
          findsNothing,
        );
      });

      testWidgets('shows invite card when invite capacity is available', (
        WidgetTester tester,
      ) async {
        final mockNotifier = _MockEmptyRelayNotifications();
        await tester.pumpWidget(
          buildScreenWidget(
            () => mockNotifier,
            inviteStatusState: const InviteStatusState(
              status: InviteStatusLoadingStatus.loaded,
              inviteStatus: InviteStatus(
                canInvite: true,
                remaining: 5,
                total: 5,
                codes: [],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('You have 5 invites to share with friends!'),
          findsOneWidget,
        );
        expect(find.text('No notifications yet'), findsNothing);
        expect(find.byType(NotificationListItem), findsNothing);
      });

      testWidgets(
        'shows filtered empty state when tab has no matching notifications',
        (WidgetTester tester) async {
          final now = DateTime.now();
          // Only like notifications, no follows
          final notifications = [
            NotificationModel(
              id: 'like-1',
              type: NotificationType.like,
              actorPubkey: pubkeyAlice,
              actorName: 'Alice',
              message: 'Alice liked your video',
              timestamp: now.subtract(const Duration(minutes: 1)),
            ),
          ];

          final mockNotifier = _MockRelayNotifications(notifications);
          await tester.pumpWidget(buildScreenWidget(() => mockNotifier));
          await tester.pumpAndSettle();

          // Tap on "Follows" tab - should be empty
          await tester.tap(find.text('Follows'));
          await tester.pumpAndSettle();

          expect(find.text('No follow notifications'), findsOneWidget);
          expect(find.byType(NotificationListItem), findsNothing);
        },
      );
    });

    group('mark as read', () {
      testWidgets('calls markAllAsRead when screen is opened', (
        WidgetTester tester,
      ) async {
        final now = DateTime.now();
        final notifications = [
          NotificationModel(
            id: 'notif-unread',
            type: NotificationType.like,
            actorPubkey: pubkeyAlice,
            actorName: 'Alice',
            message: 'Alice liked your video',
            timestamp: now.subtract(const Duration(minutes: 1)),
          ),
        ];

        final mockNotifier = _MockRelayNotifications(notifications);
        await tester.pumpWidget(buildScreenWidget(() => mockNotifier));
        await tester.pumpAndSettle();

        expect(mockNotifier.markAllAsReadCalled, isTrue);
      });

      testWidgets('calls markAsRead on notifier when notification tapped', (
        WidgetTester tester,
      ) async {
        final now = DateTime.now();
        // Use system notification type to avoid navigation (which needs GoRouter)
        final notifications = [
          NotificationModel(
            id: 'notif-to-read',
            type: NotificationType.system,
            actorPubkey: pubkeyAlice,
            message: 'Welcome to Divine!',
            timestamp: now.subtract(const Duration(minutes: 1)),
          ),
        ];

        final mockNotifier = _MockRelayNotifications(notifications);
        await tester.pumpWidget(buildScreenWidget(() => mockNotifier));
        await tester.pumpAndSettle();

        // Tap the notification
        await tester.tap(find.byType(NotificationListItem));
        await tester.pump();
        await tester.pump();

        // Verify markAsRead was called with the correct notification ID
        expect(mockNotifier.markedAsReadIds, contains('notif-to-read'));
      });
    });

    group('tab bar', () {
      testWidgets('renders all 5 tab labels', (WidgetTester tester) async {
        final mockNotifier = _MockEmptyRelayNotifications();
        await tester.pumpWidget(buildScreenWidget(() => mockNotifier));
        await tester.pumpAndSettle();

        expect(find.text('All'), findsOneWidget);
        expect(find.text('Likes'), findsOneWidget);
        expect(find.text('Comments'), findsOneWidget);
        expect(find.text('Follows'), findsOneWidget);
        expect(find.text('Reposts'), findsOneWidget);
      });
    });

    group('refresh', () {
      testWidgets('pull to refresh also reloads invite status', (
        WidgetTester tester,
      ) async {
        final mockNotifier = _MockEmptyRelayNotifications();
        final mockInviteCubit = _MockInviteStatusCubit();
        when(() => mockInviteCubit.state).thenReturn(
          const InviteStatusState(),
        );
        when(mockInviteCubit.load).thenAnswer((_) async {});

        await tester.pumpWidget(
          buildScreenWidget(
            () => mockNotifier,
            inviteCubit: mockInviteCubit,
          ),
        );
        await tester.pumpAndSettle();

        await tester.drag(
          find
              .descendant(
                of: find.byType(RefreshIndicator),
                matching: find.byType(Scrollable),
              )
              .first,
          const Offset(0, 500),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();

        verify(mockInviteCubit.load).called(1);
      });
    });
  });
}
