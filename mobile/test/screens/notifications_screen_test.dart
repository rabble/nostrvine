// ABOUTME: Widget tests for NotificationsScreen covering list rendering and tab filtering
// ABOUTME: Tests empty state, notification sorting, tab filtering, and mark as read

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/notification_model.dart';
import 'package:openvine/providers/relay_notifications_provider.dart';
import 'package:openvine/screens/notifications_screen.dart';
import 'package:openvine/widgets/notification_list_item.dart';

/// Mock notifier that returns test notifications
class _MockRelayNotifications extends RelayNotifications {
  final List<NotificationModel> _notifications;
  final List<String> markedAsReadIds = [];

  _MockRelayNotifications(this._notifications);

  @override
  Future<NotificationFeedState> build() async {
    return NotificationFeedState(
      notifications: _notifications,
      isInitialLoad: false,
      lastUpdated: DateTime.now(),
    );
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    markedAsReadIds.add(notificationId);
  }

  @override
  Future<void> markAllAsRead() async {}

  @override
  Future<void> loadMore() async {}

  @override
  Future<void> refresh() async {}
}

/// Mock notifier that returns empty list
class _MockEmptyRelayNotifications extends RelayNotifications {
  @override
  Future<NotificationFeedState> build() async {
    return NotificationFeedState(
      notifications: [],
      isInitialLoad: false,
      lastUpdated: DateTime.now(),
    );
  }

  @override
  Future<void> markAsRead(String notificationId) async {}

  @override
  Future<void> markAllAsRead() async {}

  @override
  Future<void> loadMore() async {}

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
  Widget buildScreenWidget(RelayNotifications Function() notifierFactory) {
    return ProviderScope(
      overrides: [relayNotificationsProvider.overrideWith(notifierFactory)],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: const Scaffold(body: NotificationsScreen()),
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
            metadata: {'comment': 'Great!'},
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
            metadata: {'comment': 'Awesome!'},
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
            metadata: {'comment': 'Cool!'},
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
            message: 'Welcome to diVine!',
            timestamp: now.subtract(const Duration(minutes: 1)),
            isRead: false,
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
  });
}
