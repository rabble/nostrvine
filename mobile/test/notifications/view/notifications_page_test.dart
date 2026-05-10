// ABOUTME: Tests for NotificationsPage — verifies route constants, BLoC
// ABOUTME: setup, and that the legacy Riverpod unread cache is cleared on
// ABOUTME: open via _syncRelayNotificationsRead.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/notifications/providers/notification_repository_provider.dart';
import 'package:openvine/notifications/view/notifications_page.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/relay_notifications_provider.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockNotificationRepository extends Mock
    implements NotificationRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MarkAllReadCounter {
  int calls = 0;
}

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
  group(NotificationsPage, () {
    group('route constants', () {
      test('routeName is notifications', () {
        expect(NotificationsPage.routeName, equals('notifications'));
      });

      test('path is /notifications', () {
        expect(NotificationsPage.path, equals('/notifications'));
      });

      test('pathWithIndex includes :index parameter', () {
        expect(
          NotificationsPage.pathWithIndex,
          equals('/notifications/:index'),
        );
      });

      test('pathForIndex with null returns base path', () {
        expect(NotificationsPage.pathForIndex(), equals('/notifications'));
      });

      test('pathForIndex with index returns indexed path', () {
        expect(NotificationsPage.pathForIndex(0), equals('/notifications/0'));
      });

      test('pathForIndex with non-zero index returns correct path', () {
        expect(NotificationsPage.pathForIndex(42), equals('/notifications/42'));
      });
    });

    group('Riverpod unread-cache sync on open', () {
      late _MockNotificationRepository mockNotificationRepo;
      late _MockFollowRepository mockFollowRepo;
      late _MarkAllReadCounter counter;

      setUp(() {
        mockNotificationRepo = _MockNotificationRepository();
        mockFollowRepo = _MockFollowRepository();
        counter = _MarkAllReadCounter();

        when(
          () => mockNotificationRepo.refresh(),
        ).thenAnswer((_) async => NotificationPage.empty);
        when(
          () => mockNotificationRepo.markAllAsRead(),
        ).thenAnswer((_) async {});
        when(() => mockFollowRepo.isFollowing(any())).thenReturn(false);
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
          home: const NotificationsPage(),
        );
      }

      testWidgets(
        'fires markAllAsRead exactly once on open when there are unread '
        'items',
        (tester) async {
          await tester.pumpWidget(buildSubject(relayState: _unreadFeedState()));
          await tester.pumpAndSettle();

          expect(counter.calls, equals(1));
        },
      );

      testWidgets(
        'does not call markAllAsRead when nothing is unread',
        (tester) async {
          await tester.pumpWidget(
            buildSubject(relayState: _allReadFeedState()),
          );
          await tester.pumpAndSettle();

          expect(counter.calls, equals(0));
        },
      );
    });
  });
}
