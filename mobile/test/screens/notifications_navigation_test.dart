// ABOUTME: Test for notifications screen navigation to videos and profiles
// ABOUTME: Ensures tapping notifications navigates to correct video or profile

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/relay_notifications_provider.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/notifications_screen.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/screens/pure/explore_video_screen_pure.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/notification_list_item.dart';

// Mock VideoEvents without timers
class _MockVideoEventsNoTimers extends VideoEvents {
  @override
  Stream<List<VideoEvent>> build() async* {
    yield [];
  }
}

/// Mock notifier that tracks markAsRead calls
class _MockRelayNotifications extends RelayNotifications {
  final List<String> markedAsReadIds = [];

  final List<NotificationModel> _notifications;

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
}

void main() {
  Widget shell(ProviderContainer c) => UncontrolledProviderScope(
    container: c,
    child: MaterialApp.router(routerConfig: c.read(goRouterProvider)),
  );

  String currentLocation(ProviderContainer c) {
    final router = c.read(goRouterProvider);
    return router.routeInformationProvider.value.uri.toString();
  }

  group('NotificationsScreen Navigation', () {
    late _MockRelayNotifications mockNotifier;
    late List<NotificationModel> testNotifications;

    setUp(() {
      testNotifications = [
        NotificationModel(
          id: 'notif1',
          type: NotificationType.like,
          actorPubkey: 'user123abcdef',
          actorName: 'Test User',
          message: 'liked your video',
          timestamp: DateTime.now(),
          targetEventId: 'video123',
        ),
        NotificationModel(
          id: 'notif2',
          type: NotificationType.follow,
          actorPubkey: 'user456abcdef',
          actorName: 'Another User',
          message: 'started following you',
          timestamp: DateTime.now(),
        ),
      ];

      mockNotifier = _MockRelayNotifications(testNotifications);
    });

    testWidgets(
      'tapping notification with video shows error when video not found',
      (WidgetTester tester) async {
        final c = ProviderContainer(
          overrides: [
            relayNotificationsProvider.overrideWith(() => mockNotifier),
            videoEventsProvider.overrideWith(_MockVideoEventsNoTimers.new),
          ],
        );
        addTearDown(c.dispose);

        await tester.pumpWidget(shell(c));

        // Navigate to notifications
        c.read(goRouterProvider).go(NotificationsScreen.pathForIndex(0));
        await tester.pump();
        await tester.pump();

        await tester.pumpAndSettle();

        // Act: Tap on first notification (with video ID that doesn't exist)
        final firstNotification = find.byType(NotificationListItem).first;
        await tester.tap(firstNotification);
        await tester.pump();
        await tester.pump();

        // Assert: Should show "Video not found" snackbar instead of navigating
        expect(find.text('Video not found'), findsOneWidget);
        expect(find.byType(ExploreVideoScreenPure), findsNothing);

        // Verify markAsRead was called
        expect(mockNotifier.markedAsReadIds, contains('notif1'));
      },
    );

    testWidgets('tapping notification without video navigates to profile', (
      WidgetTester tester,
    ) async {
      final user456Npub = NostrKeyUtils.encodePubKey('user456abcdef');

      final c = ProviderContainer(
        overrides: [
          relayNotificationsProvider.overrideWith(() => mockNotifier),
          videoEventsProvider.overrideWith(_MockVideoEventsNoTimers.new),
        ],
      );
      addTearDown(c.dispose);

      await tester.pumpWidget(shell(c));

      // Navigate to notifications
      c.read(goRouterProvider).go(NotificationsScreen.pathForIndex(0));
      await tester.pump();
      await tester.pump();

      await tester.pumpAndSettle();

      // Act: Tap on second notification (follow, no video)
      final secondNotification = find.byType(NotificationListItem).at(1);
      await tester.tap(secondNotification);

      // Pump frames to allow navigation and ProfileScreen initialization
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // Assert: Should navigate to profile screen
      expect(
        currentLocation(c),
        contains(ProfileScreenRouter.pathForNpub(user456Npub)),
      );

      // Verify markAsRead was called
      expect(mockNotifier.markedAsReadIds, contains('notif2'));
    });
    // TODO(any): Fix and re-enable this test
  }, skip: true);
}
