// ABOUTME: Unit tests for RelayNotifications.insertFromWebSocket()
// ABOUTME: Tests deduplication, sort order, and unread count management

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/notification_model.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/relay_notifications_provider.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nip98_auth_service.dart';
import 'package:openvine/services/relay_notification_api_service.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'package:openvine/services/video_event_service.dart';

class _MockRelayNotificationApiService extends Mock
    implements RelayNotificationApiService {}

class _MockAuthService extends Mock implements AuthService {}

class _MockUserProfileService extends Mock implements UserProfileService {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockNip98AuthService extends Mock implements Nip98AuthService {}

void main() {
  group('RelayNotifications insertFromWebSocket', () {
    late _MockRelayNotificationApiService mockApiService;
    late _MockAuthService mockAuthService;
    late _MockUserProfileService mockUserProfileService;
    late _MockVideoEventService mockVideoEventService;
    late _MockNip98AuthService mockNip98AuthService;

    const testPubkey =
        'test_pubkey_0123456789abcdef0123456789abcdef0123456789abcdef01234567';

    setUp(() {
      mockApiService = _MockRelayNotificationApiService();
      mockAuthService = _MockAuthService();
      mockUserProfileService = _MockUserProfileService();
      mockVideoEventService = _MockVideoEventService();
      mockNip98AuthService = _MockNip98AuthService();

      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.currentPublicKeyHex).thenReturn(testPubkey);
      when(() => mockApiService.isAvailable).thenReturn(true);
      when(
        () => mockUserProfileService.getCachedProfile(any()),
      ).thenReturn(null);
      when(
        () => mockUserProfileService.fetchProfile(any()),
      ).thenAnswer((_) async => null);
      when(
        () => mockVideoEventService.getVideoEventById(any()),
      ).thenReturn(null);
    });

    NotificationModel createNotification({
      required String id,
      String actorPubkey =
          'actor_0123456789abcdef0123456789abcdef0123456789abcdef0123456789ab',
      NotificationType type = NotificationType.like,
      bool isRead = false,
      DateTime? timestamp,
    }) {
      return NotificationModel(
        id: id,
        type: type,
        actorPubkey: actorPubkey,
        message: 'Test notification $id',
        timestamp: timestamp ?? DateTime(2024, 1, 15, 12),
        isRead: isRead,
      );
    }

    ProviderContainer createTestContainer() {
      return ProviderContainer(
        overrides: [
          relayNotificationApiServiceProvider.overrideWithValue(mockApiService),
          authServiceProvider.overrideWithValue(mockAuthService),
          userProfileServiceProvider.overrideWithValue(mockUserProfileService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          nip98AuthServiceProvider.overrideWithValue(mockNip98AuthService),
        ],
      );
    }

    Future<NotificationFeedState> waitForLoadComplete(
      ProviderContainer container,
    ) async {
      final completer = Completer<NotificationFeedState>();

      container.listen<AsyncValue<NotificationFeedState>>(
        relayNotificationsProvider,
        (previous, next) {
          next.whenData((state) {
            if (!state.isInitialLoad && !completer.isCompleted) {
              completer.complete(state);
            }
          });
        },
        fireImmediately: true,
      );

      container.read(relayNotificationsProvider);

      return completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Provider did not complete loading');
        },
      );
    }

    test('inserts notification into state', () async {
      when(
        () => mockApiService.getNotifications(
          pubkey: any(named: 'pubkey'),
          types: any(named: 'types'),
          unreadOnly: any(named: 'unreadOnly'),
          limit: any(named: 'limit'),
          before: any(named: 'before'),
        ),
      ).thenAnswer(
        (_) async =>
            const NotificationsResponse(notifications: [], unreadCount: 0),
      );

      final container = createTestContainer();

      await waitForLoadComplete(container);

      final notification = createNotification(id: 'ws_notif_1');
      await container
          .read(relayNotificationsProvider.notifier)
          .insertFromWebSocket(notification);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(relayNotificationsProvider);
      final result = state.value!;

      expect(result.notifications.length, equals(1));
      expect(result.notifications[0].id, equals('ws_notif_1'));

      container.dispose();
    });

    test('deduplicates - same ID not inserted twice', () async {
      when(
        () => mockApiService.getNotifications(
          pubkey: any(named: 'pubkey'),
          types: any(named: 'types'),
          unreadOnly: any(named: 'unreadOnly'),
          limit: any(named: 'limit'),
          before: any(named: 'before'),
        ),
      ).thenAnswer(
        (_) async =>
            const NotificationsResponse(notifications: [], unreadCount: 0),
      );

      final container = createTestContainer();

      await waitForLoadComplete(container);

      final notification = createNotification(id: 'ws_notif_dup');
      await container
          .read(relayNotificationsProvider.notifier)
          .insertFromWebSocket(notification);
      await container
          .read(relayNotificationsProvider.notifier)
          .insertFromWebSocket(notification);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(relayNotificationsProvider);
      final result = state.value!;

      expect(result.notifications.length, equals(1));

      container.dispose();
    });

    test('maintains sort order by timestamp (newest first)', () async {
      when(
        () => mockApiService.getNotifications(
          pubkey: any(named: 'pubkey'),
          types: any(named: 'types'),
          unreadOnly: any(named: 'unreadOnly'),
          limit: any(named: 'limit'),
          before: any(named: 'before'),
        ),
      ).thenAnswer(
        (_) async =>
            const NotificationsResponse(notifications: [], unreadCount: 0),
      );

      final container = createTestContainer();

      await waitForLoadComplete(container);

      final older = createNotification(
        id: 'ws_old',
        timestamp: DateTime(2024, 1, 10),
      );
      final newer = createNotification(
        id: 'ws_new',
        timestamp: DateTime(2024, 1, 20),
      );

      // Insert older first, then newer
      await container
          .read(relayNotificationsProvider.notifier)
          .insertFromWebSocket(older);
      await container
          .read(relayNotificationsProvider.notifier)
          .insertFromWebSocket(newer);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(relayNotificationsProvider);
      final result = state.value!;

      expect(result.notifications.length, equals(2));
      // Newest should be first
      expect(result.notifications[0].id, equals('ws_new'));
      expect(result.notifications[1].id, equals('ws_old'));

      container.dispose();
    });

    test('increments unread count for unread notifications', () async {
      when(
        () => mockApiService.getNotifications(
          pubkey: any(named: 'pubkey'),
          types: any(named: 'types'),
          unreadOnly: any(named: 'unreadOnly'),
          limit: any(named: 'limit'),
          before: any(named: 'before'),
        ),
      ).thenAnswer(
        (_) async =>
            const NotificationsResponse(notifications: [], unreadCount: 0),
      );

      final container = createTestContainer();

      await waitForLoadComplete(container);

      final unreadNotification = createNotification(id: 'ws_unread_1');

      await container
          .read(relayNotificationsProvider.notifier)
          .insertFromWebSocket(unreadNotification);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(relayNotificationsProvider);
      final result = state.value!;

      expect(result.unreadCount, equals(1));

      container.dispose();
    });

    test('does not increment unread count for read notifications', () async {
      when(
        () => mockApiService.getNotifications(
          pubkey: any(named: 'pubkey'),
          types: any(named: 'types'),
          unreadOnly: any(named: 'unreadOnly'),
          limit: any(named: 'limit'),
          before: any(named: 'before'),
        ),
      ).thenAnswer(
        (_) async =>
            const NotificationsResponse(notifications: [], unreadCount: 0),
      );

      final container = createTestContainer();

      await waitForLoadComplete(container);

      final readNotification = createNotification(
        id: 'ws_read_1',
        isRead: true,
      );

      await container
          .read(relayNotificationsProvider.notifier)
          .insertFromWebSocket(readNotification);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(relayNotificationsProvider);
      final result = state.value!;

      expect(result.unreadCount, equals(0));

      container.dispose();
    });
  });
}
