// ABOUTME: Unit tests for RelayNotifications provider
// ABOUTME: Tests pagination, deduplication, mark-as-read, and state management

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/relay_notifications_provider.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nip98_auth_service.dart';
import 'package:openvine/services/relay_notification_api_service.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'package:openvine/services/video_event_service.dart';

class MockRelayNotificationApiService extends Mock
    implements RelayNotificationApiService {}

class MockAuthService extends Mock implements AuthService {}

class MockUserProfileService extends Mock implements UserProfileService {}

class MockVideoEventService extends Mock implements VideoEventService {}

class MockNip98AuthService extends Mock implements Nip98AuthService {}

void main() {
  group('RelayNotifications Provider', () {
    late MockRelayNotificationApiService mockApiService;
    late MockAuthService mockAuthService;
    late MockUserProfileService mockUserProfileService;
    late MockVideoEventService mockVideoEventService;
    late MockNip98AuthService mockNip98AuthService;

    const testPubkey =
        'test_pubkey_0123456789abcdef0123456789abcdef0123456789abcdef01234567';

    setUp(() {
      mockApiService = MockRelayNotificationApiService();
      mockAuthService = MockAuthService();
      mockUserProfileService = MockUserProfileService();
      mockVideoEventService = MockVideoEventService();
      mockNip98AuthService = MockNip98AuthService();

      // Default auth service behavior - authenticated user
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.currentPublicKeyHex).thenReturn(testPubkey);

      // Default API service behavior - available
      when(() => mockApiService.isAvailable).thenReturn(true);

      // Default profile service behavior
      when(
        () => mockUserProfileService.getCachedProfile(any()),
      ).thenReturn(null);
      when(
        () => mockUserProfileService.fetchProfile(any()),
      ).thenAnswer((_) async => null);

      // Default video service behavior
      when(
        () => mockVideoEventService.getVideoEventById(any()),
      ).thenReturn(null);
    });

    RelayNotification createMockRelayNotification({
      required String id,
      String sourcePubkey = 'source_pubkey_123',
      String notificationType = 'reaction',
      bool read = false,
      int createdAtSeconds = 1700000000,
    }) {
      return RelayNotification(
        id: id,
        sourcePubkey: sourcePubkey,
        sourceEventId: 'event_$id',
        sourceKind: 7,
        notificationType: notificationType,
        createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtSeconds * 1000),
        read: read,
        referencedEventId: 'video_event_$id',
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

    /// Waits for the provider to complete loading (i.e., isInitialLoad becomes false)
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

      // Trigger the provider
      container.read(relayNotificationsProvider);

      return completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('Provider did not complete loading');
        },
      );
    }

    group('Initial Load', () {
      test('returns empty state when user is not authenticated', () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(false);
        when(() => mockAuthService.currentPublicKeyHex).thenReturn(null);

        final container = createTestContainer();

        final result = await container.read(relayNotificationsProvider.future);

        expect(result.notifications, isEmpty);
        expect(result.unreadCount, 0);
        verifyNever(
          () => mockApiService.getNotifications(
            pubkey: any(named: 'pubkey'),
            types: any(named: 'types'),
            unreadOnly: any(named: 'unreadOnly'),
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        );

        container.dispose();
      });

      test('returns empty state when API is not available', () async {
        when(() => mockApiService.isAvailable).thenReturn(false);

        final container = createTestContainer();

        final result = await container.read(relayNotificationsProvider.future);

        expect(result.notifications, isEmpty);
        expect(result.unreadCount, 0);
        verifyNever(
          () => mockApiService.getNotifications(
            pubkey: any(named: 'pubkey'),
            types: any(named: 'types'),
            unreadOnly: any(named: 'unreadOnly'),
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        );

        container.dispose();
      });

      test('loads notifications successfully', () async {
        final mockNotifications = [
          createMockRelayNotification(
            id: 'notif_1',
            createdAtSeconds: 1700000100,
          ),
          createMockRelayNotification(
            id: 'notif_2',
            createdAtSeconds: 1700000000,
          ),
        ];

        when(
          () => mockApiService.getNotifications(
            pubkey: any(named: 'pubkey'),
            types: any(named: 'types'),
            unreadOnly: any(named: 'unreadOnly'),
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer(
          (_) async => NotificationsResponse(
            notifications: mockNotifications,
            unreadCount: 5,
            nextCursor: 'cursor_abc',
            hasMore: true,
          ),
        );

        final container = createTestContainer();

        final result = await waitForLoadComplete(container);

        expect(result.notifications.length, 2);
        expect(result.unreadCount, 5);
        expect(result.hasMoreContent, isTrue);
        expect(result.isInitialLoad, isFalse);
        expect(result.error, isNull);

        verify(
          () => mockApiService.getNotifications(
            pubkey: testPubkey,
            types: any(named: 'types'),
            unreadOnly: any(named: 'unreadOnly'),
            limit: 50,
            before: any(named: 'before'),
          ),
        ).called(1);

        container.dispose();
      });

      test(
        'converts RelayNotification to NotificationModel correctly',
        () async {
          final mockNotifications = [
            createMockRelayNotification(
              id: 'notif_1',
              notificationType: 'reaction',
              read: false,
            ),
          ];

          when(
            () => mockApiService.getNotifications(
              pubkey: any(named: 'pubkey'),
              types: any(named: 'types'),
              unreadOnly: any(named: 'unreadOnly'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => NotificationsResponse(
              notifications: mockNotifications,
              unreadCount: 1,
            ),
          );

          final container = createTestContainer();

          final result = await waitForLoadComplete(container);

          expect(result.notifications.length, 1);
          final notification = result.notifications[0];
          expect(notification.id, 'notif_1');
          expect(notification.type, NotificationType.like);
          expect(notification.isRead, isFalse);

          container.dispose();
        },
      );

      test('handles API error gracefully', () async {
        when(
          () => mockApiService.getNotifications(
            pubkey: any(named: 'pubkey'),
            types: any(named: 'types'),
            unreadOnly: any(named: 'unreadOnly'),
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenThrow(Exception('Network error'));

        final container = createTestContainer();

        final result = await waitForLoadComplete(container);

        expect(result.notifications, isEmpty);
        expect(result.error, contains('Network error'));
        expect(result.isInitialLoad, isFalse);

        container.dispose();
      });
    });

    group('Pagination (loadMore)', () {
      test('loads more notifications when hasMore is true', () async {
        // Initial notifications
        final initialNotifications = [
          createMockRelayNotification(
            id: 'notif_1',
            createdAtSeconds: 1700000100,
          ),
        ];
        // Additional notifications for loadMore
        final moreNotifications = [
          createMockRelayNotification(
            id: 'notif_2',
            createdAtSeconds: 1700000000,
          ),
        ];

        var callCount = 0;
        when(
          () => mockApiService.getNotifications(
            pubkey: any(named: 'pubkey'),
            types: any(named: 'types'),
            unreadOnly: any(named: 'unreadOnly'),
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            return NotificationsResponse(
              notifications: initialNotifications,
              unreadCount: 3,
              nextCursor: 'cursor_1',
              hasMore: true,
            );
          } else {
            return NotificationsResponse(
              notifications: moreNotifications,
              unreadCount: 3,
              nextCursor: 'cursor_2',
              hasMore: false,
            );
          }
        });

        final container = createTestContainer();

        // Initial load
        await waitForLoadComplete(container);

        // Load more
        await container.read(relayNotificationsProvider.notifier).loadMore();

        // Wait a bit for state to settle
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final state = container.read(relayNotificationsProvider);
        final result = state.value!;

        expect(result.notifications.length, 2);
        expect(result.hasMoreContent, isFalse);

        container.dispose();
      });

      test('deduplicates notifications on loadMore', () async {
        var callCount = 0;
        when(
          () => mockApiService.getNotifications(
            pubkey: any(named: 'pubkey'),
            types: any(named: 'types'),
            unreadOnly: any(named: 'unreadOnly'),
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            return NotificationsResponse(
              notifications: [
                createMockRelayNotification(id: 'notif_1'),
                createMockRelayNotification(id: 'notif_2'),
              ],
              unreadCount: 2,
              nextCursor: 'cursor_1',
              hasMore: true,
            );
          } else {
            // Return a duplicate notification
            return NotificationsResponse(
              notifications: [
                createMockRelayNotification(id: 'notif_2'), // Duplicate!
                createMockRelayNotification(id: 'notif_3'),
              ],
              unreadCount: 3,
              hasMore: false,
            );
          }
        });

        final container = createTestContainer();

        await waitForLoadComplete(container);
        await container.read(relayNotificationsProvider.notifier).loadMore();

        // Wait for state to settle
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final state = container.read(relayNotificationsProvider);
        final result = state.value!;

        // Should have 3 unique notifications, not 4
        expect(result.notifications.length, 3);
        final ids = result.notifications.map((n) => n.id).toSet();
        expect(ids, {'notif_1', 'notif_2', 'notif_3'});

        container.dispose();
      });

      test('does not loadMore when hasMore is false', () async {
        when(
          () => mockApiService.getNotifications(
            pubkey: any(named: 'pubkey'),
            types: any(named: 'types'),
            unreadOnly: any(named: 'unreadOnly'),
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer(
          (_) async => NotificationsResponse(
            notifications: [createMockRelayNotification(id: 'notif_1')],
            unreadCount: 1,
            hasMore: false, // No more content!
          ),
        );

        final container = createTestContainer();

        await waitForLoadComplete(container);
        await container.read(relayNotificationsProvider.notifier).loadMore();

        // Should only have called once (initial load)
        verify(
          () => mockApiService.getNotifications(
            pubkey: any(named: 'pubkey'),
            types: any(named: 'types'),
            unreadOnly: any(named: 'unreadOnly'),
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).called(1);

        container.dispose();
      });
    });

    group('Mark As Read', () {
      test(
        'marks single notification as read with optimistic update',
        () async {
          when(
            () => mockApiService.getNotifications(
              pubkey: any(named: 'pubkey'),
              types: any(named: 'types'),
              unreadOnly: any(named: 'unreadOnly'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => NotificationsResponse(
              notifications: [
                createMockRelayNotification(id: 'notif_1', read: false),
                createMockRelayNotification(id: 'notif_2', read: false),
              ],
              unreadCount: 2,
            ),
          );

          when(
            () => mockApiService.markAsRead(
              pubkey: any(named: 'pubkey'),
              notificationIds: any(named: 'notificationIds'),
            ),
          ).thenAnswer(
            (_) async => const MarkReadResponse(success: true, markedCount: 1),
          );

          final container = createTestContainer();

          await waitForLoadComplete(container);

          // Mark first notification as read
          await container
              .read(relayNotificationsProvider.notifier)
              .markAsRead('notif_1');

          // Wait for state to settle
          await Future<void>.delayed(const Duration(milliseconds: 50));

          final state = container.read(relayNotificationsProvider);
          final result = state.value!;

          // Check optimistic update
          final notif1 = result.notifications.firstWhere(
            (n) => n.id == 'notif_1',
          );
          final notif2 = result.notifications.firstWhere(
            (n) => n.id == 'notif_2',
          );
          expect(notif1.isRead, isTrue);
          expect(notif2.isRead, isFalse);
          expect(result.unreadCount, 1);

          // Verify API was called
          verify(
            () => mockApiService.markAsRead(
              pubkey: testPubkey,
              notificationIds: ['notif_1'],
            ),
          ).called(1);

          container.dispose();
        },
      );

      test('marks all notifications as read', () async {
        when(
          () => mockApiService.getNotifications(
            pubkey: any(named: 'pubkey'),
            types: any(named: 'types'),
            unreadOnly: any(named: 'unreadOnly'),
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer(
          (_) async => NotificationsResponse(
            notifications: [
              createMockRelayNotification(id: 'notif_1', read: false),
              createMockRelayNotification(id: 'notif_2', read: false),
              createMockRelayNotification(id: 'notif_3', read: false),
            ],
            unreadCount: 3,
          ),
        );

        when(
          () => mockApiService.markAsRead(
            pubkey: any(named: 'pubkey'),
            notificationIds: any(named: 'notificationIds'),
          ),
        ).thenAnswer(
          (_) async => const MarkReadResponse(success: true, markedCount: 3),
        );

        final container = createTestContainer();

        await waitForLoadComplete(container);

        // Mark all as read
        await container
            .read(relayNotificationsProvider.notifier)
            .markAllAsRead();

        // Wait for state to settle
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final state = container.read(relayNotificationsProvider);
        final result = state.value!;

        // All should be read
        expect(result.notifications.every((n) => n.isRead), isTrue);
        expect(result.unreadCount, 0);

        // Verify API was called without specific IDs (mark all)
        verify(
          () => mockApiService.markAsRead(
            pubkey: testPubkey,
            notificationIds: null,
          ),
        ).called(1);

        container.dispose();
      });

      test(
        'handles mark as read error gracefully (keeps optimistic update)',
        () async {
          when(
            () => mockApiService.getNotifications(
              pubkey: any(named: 'pubkey'),
              types: any(named: 'types'),
              unreadOnly: any(named: 'unreadOnly'),
              limit: any(named: 'limit'),
              before: any(named: 'before'),
            ),
          ).thenAnswer(
            (_) async => NotificationsResponse(
              notifications: [
                createMockRelayNotification(id: 'notif_1', read: false),
              ],
              unreadCount: 1,
            ),
          );

          when(
            () => mockApiService.markAsRead(
              pubkey: any(named: 'pubkey'),
              notificationIds: any(named: 'notificationIds'),
            ),
          ).thenThrow(Exception('Network error'));

          final container = createTestContainer();

          await waitForLoadComplete(container);
          await container
              .read(relayNotificationsProvider.notifier)
              .markAsRead('notif_1');

          // Wait for state to settle
          await Future<void>.delayed(const Duration(milliseconds: 50));

          final state = container.read(relayNotificationsProvider);
          final result = state.value!;

          // Optimistic update should still be applied
          expect(result.notifications[0].isRead, isTrue);

          container.dispose();
        },
      );
    });

    group('Refresh', () {
      test('refresh fetches fresh data from API', () async {
        var callCount = 0;
        when(
          () => mockApiService.getNotifications(
            pubkey: any(named: 'pubkey'),
            types: any(named: 'types'),
            unreadOnly: any(named: 'unreadOnly'),
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer((_) async {
          callCount++;
          return NotificationsResponse(
            notifications: [
              createMockRelayNotification(id: 'notif_call_$callCount'),
            ],
            unreadCount: callCount,
          );
        });

        final container = createTestContainer();

        // Initial load
        await waitForLoadComplete(container);
        expect(callCount, 1);

        // Refresh fetches fresh data without invalidating state
        await container.read(relayNotificationsProvider.notifier).refresh();

        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Should have been called twice
        expect(callCount, 2);

        // State should reflect the refreshed data
        final state = container.read(relayNotificationsProvider);
        final result = state.value!;
        expect(result.notifications.length, 1);
        expect(result.notifications[0].id, 'notif_call_2');
        expect(result.unreadCount, 2);

        container.dispose();
      });

      test('refresh preserves existing data until new data arrives', () async {
        final refreshCompleter = Completer<NotificationsResponse>();
        var callCount = 0;

        when(
          () => mockApiService.getNotifications(
            pubkey: any(named: 'pubkey'),
            types: any(named: 'types'),
            unreadOnly: any(named: 'unreadOnly'),
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            return NotificationsResponse(
              notifications: [
                createMockRelayNotification(id: 'original_notif'),
              ],
              unreadCount: 1,
            );
          }
          // Second call (refresh) waits for completer
          return refreshCompleter.future;
        });

        final container = createTestContainer();

        await waitForLoadComplete(container);

        // Start refresh (will block on completer)
        final refreshFuture = container
            .read(relayNotificationsProvider.notifier)
            .refresh();

        await Future<void>.delayed(const Duration(milliseconds: 50));

        // While refresh is in-flight, existing data should still be visible
        final midState = container.read(relayNotificationsProvider);
        expect(midState.value!.notifications.length, 1);
        expect(midState.value!.notifications[0].id, 'original_notif');

        // Complete the refresh
        refreshCompleter.complete(
          NotificationsResponse(
            notifications: [createMockRelayNotification(id: 'refreshed_notif')],
            unreadCount: 0,
          ),
        );

        await refreshFuture;
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Now state should show refreshed data
        final finalState = container.read(relayNotificationsProvider);
        expect(finalState.value!.notifications.length, 1);
        expect(finalState.value!.notifications[0].id, 'refreshed_notif');

        container.dispose();
      });

      test('refresh keeps existing data on error', () async {
        var callCount = 0;
        when(
          () => mockApiService.getNotifications(
            pubkey: any(named: 'pubkey'),
            types: any(named: 'types'),
            unreadOnly: any(named: 'unreadOnly'),
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            return NotificationsResponse(
              notifications: [
                createMockRelayNotification(id: 'existing_notif'),
              ],
              unreadCount: 1,
            );
          }
          throw Exception('Network error');
        });

        final container = createTestContainer();

        await waitForLoadComplete(container);

        // Refresh should fail but keep existing data
        await container.read(relayNotificationsProvider.notifier).refresh();
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final state = container.read(relayNotificationsProvider);
        final result = state.value!;

        // Existing notification should be preserved
        expect(result.notifications.length, 1);
        expect(result.notifications[0].id, 'existing_notif');
        expect(result.error, contains('Network error'));

        container.dispose();
      });
    });

    group('Helper Providers', () {
      test('relayNotificationUnreadCount returns correct count', () async {
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
              const NotificationsResponse(notifications: [], unreadCount: 42),
        );

        final container = createTestContainer();

        // Wait for provider to load
        await waitForLoadComplete(container);

        final unreadCount = container.read(
          relayNotificationUnreadCountProvider,
        );
        expect(unreadCount, 42);

        container.dispose();
      });

      test('relayNotificationsLoading reflects loading state', () async {
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

        // After loading completes
        await waitForLoadComplete(container);
        final isLoading = container.read(relayNotificationsLoadingProvider);
        expect(isLoading, isFalse);

        container.dispose();
      });

      test('relayNotificationsByType filters correctly', () async {
        when(
          () => mockApiService.getNotifications(
            pubkey: any(named: 'pubkey'),
            types: any(named: 'types'),
            unreadOnly: any(named: 'unreadOnly'),
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer(
          (_) async => NotificationsResponse(
            notifications: [
              createMockRelayNotification(
                id: 'like_1',
                notificationType: 'reaction',
              ),
              createMockRelayNotification(
                id: 'follow_1',
                notificationType: 'follow',
              ),
              createMockRelayNotification(
                id: 'like_2',
                notificationType: 'reaction',
              ),
            ],
            unreadCount: 3,
          ),
        );

        final container = createTestContainer();

        await waitForLoadComplete(container);

        // Filter by like type
        final likes = container.read(
          relayNotificationsByTypeProvider(NotificationType.like),
        );
        expect(likes.length, 2);
        expect(likes.every((n) => n.type == NotificationType.like), isTrue);

        // Filter by follow type
        final follows = container.read(
          relayNotificationsByTypeProvider(NotificationType.follow),
        );
        expect(follows.length, 1);
        expect(follows[0].type, NotificationType.follow);

        // No filter (null) returns all
        final all = container.read(relayNotificationsByTypeProvider(null));
        expect(all.length, 3);

        container.dispose();
      });
    });

    group('NotificationFeedState', () {
      test('copyWith creates correct copy', () {
        const original = NotificationFeedState(
          notifications: [],
          unreadCount: 5,
          hasMoreContent: true,
          isLoadingMore: false,
          isInitialLoad: false,
        );

        final copied = original.copyWith(unreadCount: 10, isLoadingMore: true);

        expect(copied.unreadCount, 10);
        expect(copied.isLoadingMore, isTrue);
        expect(copied.hasMoreContent, isTrue); // Unchanged
        expect(copied.isInitialLoad, isFalse); // Unchanged
      });

      test('empty state has correct defaults', () {
        const empty = NotificationFeedState.empty;

        expect(empty.notifications, isEmpty);
        expect(empty.unreadCount, 0);
        expect(empty.hasMoreContent, isFalse);
        expect(empty.isLoadingMore, isFalse);
        expect(empty.isInitialLoad, isTrue);
        expect(empty.error, isNull);
      });
    });
  });
}
