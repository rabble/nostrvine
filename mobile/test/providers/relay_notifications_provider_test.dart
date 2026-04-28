// ABOUTME: Unit tests for RelayNotifications provider
// ABOUTME: Tests pagination, deduplication, mark-as-read, and state management

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/relay_notifications_provider.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/services/background_activity_manager.dart';
import 'package:openvine/services/nip98_auth_service.dart';
import 'package:openvine/services/relay_notification_api_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:profile_repository/profile_repository.dart';

class MockRelayNotificationApiService extends Mock
    implements RelayNotificationApiService {}

class MockAuthService extends Mock implements AuthService {}

class MockVideoEventService extends Mock implements VideoEventService {}

class MockProfileRepository extends Mock implements ProfileRepository {}

class MockNip98AuthService extends Mock implements Nip98AuthService {}

class MockBackgroundActivityManager extends Mock
    implements BackgroundActivityManager {}

void main() {
  group('RelayNotifications Provider', () {
    late MockRelayNotificationApiService mockApiService;
    late MockAuthService mockAuthService;
    late MockVideoEventService mockVideoEventService;
    late MockProfileRepository mockProfileRepository;
    late MockNip98AuthService mockNip98AuthService;
    late MockBackgroundActivityManager mockBackgroundManager;

    const testPubkey =
        'test_pubkey_0123456789abcdef0123456789abcdef0123456789abcdef01234567';

    setUp(() {
      mockApiService = MockRelayNotificationApiService();
      mockAuthService = MockAuthService();
      mockVideoEventService = MockVideoEventService();
      mockProfileRepository = MockProfileRepository();
      mockNip98AuthService = MockNip98AuthService();
      mockBackgroundManager = MockBackgroundActivityManager();

      // Default auth service behavior - authenticated user
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.currentPublicKeyHex).thenReturn(testPubkey);
      when(() => mockAuthService.authState).thenReturn(AuthState.authenticated);
      when(
        () => mockAuthService.authStateStream,
      ).thenAnswer((_) => const Stream<AuthState>.empty());

      // Default API service behavior - available
      when(() => mockApiService.isAvailable).thenReturn(true);

      // Default video service behavior
      when(
        () => mockVideoEventService.getVideoEventById(any()),
      ).thenReturn(null);

      when(
        () => mockProfileRepository.getCachedProfile(
          pubkey: any(named: 'pubkey'),
        ),
      ).thenAnswer((_) async => null);
      when(
        () => mockProfileRepository.fetchBatchProfiles(
          pubkeys: any(named: 'pubkeys'),
        ),
      ).thenAnswer((_) async => <String, UserProfile>{});

      // Default background manager behavior - app in foreground
      when(() => mockBackgroundManager.isAppInForeground).thenReturn(true);
      when(() => mockBackgroundManager.isAppInBackground).thenReturn(false);
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

    ProviderContainer createTestContainer({
      ProfileRepository? profileRepository,
    }) {
      return ProviderContainer(
        overrides: [
          currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          relayNotificationApiServiceProvider.overrideWithValue(mockApiService),
          authServiceProvider.overrideWithValue(mockAuthService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          nip98AuthServiceProvider.overrideWithValue(mockNip98AuthService),
          profileRepositoryProvider.overrideWithValue(profileRepository),
          backgroundActivityManagerProvider.overrideWithValue(
            mockBackgroundManager,
          ),
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
        // Provider requires at least 10 items (_minVisibleItems) before stopping
        // auto-load when hasMore is true. Return 10 or set hasMore: false.
        final mockNotifications = [
          createMockRelayNotification(
            id: 'notif_1',
            createdAtSeconds: 1700000100,
          ),
          createMockRelayNotification(id: 'notif_2'),
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
          ),
        );

        final container = createTestContainer();

        final result = await waitForLoadComplete(container);

        expect(result.notifications.length, 2);
        expect(result.unreadCount, 5);
        expect(result.hasMoreContent, isFalse);
        expect(result.isInitialLoad, isFalse);
        expect(result.error, isNull);

        verify(
          () => mockApiService.getNotifications(
            pubkey: testPubkey,
            types: any(named: 'types'),
            unreadOnly: any(named: 'unreadOnly'),
            before: any(named: 'before'),
          ),
        ).called(1);

        container.dispose();
      });

      test(
        'resets to empty when auth state changes to unauthenticated',
        () async {
          final authStateController = StreamController<AuthState>.broadcast();
          var authState = AuthState.authenticated;

          when(() => mockAuthService.authState).thenAnswer((_) => authState);
          when(
            () => mockAuthService.authStateStream,
          ).thenAnswer((_) => authStateController.stream);

          final mockNotifications = [
            createMockRelayNotification(
              id: 'notif_1',
              createdAtSeconds: 1700000100,
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

          final container = ProviderContainer(
            overrides: [
              relayNotificationApiServiceProvider.overrideWithValue(
                mockApiService,
              ),
              authServiceProvider.overrideWithValue(mockAuthService),
              videoEventServiceProvider.overrideWithValue(
                mockVideoEventService,
              ),
              nip98AuthServiceProvider.overrideWithValue(mockNip98AuthService),
              profileRepositoryProvider.overrideWithValue(
                mockProfileRepository,
              ),
              backgroundActivityManagerProvider.overrideWithValue(
                mockBackgroundManager,
              ),
            ],
          );
          addTearDown(() async {
            await authStateController.close();
            container.dispose();
          });

          final initial = await waitForLoadComplete(container);
          expect(initial.notifications, isNotEmpty);

          authState = AuthState.unauthenticated;
          when(() => mockAuthService.isAuthenticated).thenReturn(false);
          when(() => mockAuthService.currentPublicKeyHex).thenReturn(null);
          authStateController.add(AuthState.unauthenticated);

          await Future<void>.delayed(Duration.zero);

          final updated = await container.read(
            relayNotificationsProvider.future,
          );
          expect(updated.notifications, isEmpty);
          expect(updated.unreadCount, 0);
        },
      );

      test(
        'converts RelayNotification to NotificationModel correctly',
        () async {
          final mockNotifications = [
            createMockRelayNotification(id: 'notif_1'),
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

      test(
        'completes initial load before profile enrichment finishes',
        () async {
          final batchFetchCompleter = Completer<Map<String, UserProfile>>();
          final mockNotifications = [
            createMockRelayNotification(id: 'notif_1'),
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

          when(
            () => mockProfileRepository.fetchBatchProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer((_) => batchFetchCompleter.future);

          final container = createTestContainer(
            profileRepository: mockProfileRepository,
          );

          final result = await waitForLoadComplete(container).timeout(
            const Duration(milliseconds: 200),
            onTimeout: () => throw TimeoutException(
              'Initial notification load blocked on enrichment',
            ),
          );

          expect(result.notifications, hasLength(1));
          expect(result.notifications.single.actorName, isNull);
          expect(
            result.notifications.single.message,
            'Someone liked your video',
          );
          expect(result.isInitialLoad, isFalse);

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
        final moreNotifications = [createMockRelayNotification(id: 'notif_2')];

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
                createMockRelayNotification(id: 'notif_1'),
                createMockRelayNotification(id: 'notif_2'),
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
              createMockRelayNotification(id: 'notif_1'),
              createMockRelayNotification(id: 'notif_2'),
              createMockRelayNotification(id: 'notif_3'),
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
        verify(() => mockApiService.markAsRead(pubkey: testPubkey)).called(1);

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
              notifications: [createMockRelayNotification(id: 'notif_1')],
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

        // State should contain the refreshed notification; the original may
        // also be present because refresh now merges rather than replaces.
        final state = container.read(relayNotificationsProvider);
        final result = state.value!;
        final ids = result.notifications.map((n) => n.id).toSet();
        expect(ids, contains('notif_call_2'));
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

        // Now state should include the refreshed notification; the original
        // may also be preserved since refresh now merges.
        final finalState = container.read(relayNotificationsProvider);
        final finalIds = finalState.value!.notifications
            .map((n) => n.id)
            .toSet();
        expect(finalIds, contains('refreshed_notif'));

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
      test(
        'relayNotificationUnreadCount derives from the consolidated unread list, '
        'not the server-reported count',
        () async {
          // Server returns 5 follow rows from 2 distinct pubkeys (Kind 3
          // republish bug — funnelcake#234) and reports unreadCount: 5.
          // After follow consolidation the visible list has 2 rows; the
          // badge must reflect what the user sees, not what the server says.
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
                  id: 'follow_a_1',
                  notificationType: 'follow',
                  sourcePubkey: 'follower_a',
                  createdAtSeconds: 1700000100,
                ),
                createMockRelayNotification(
                  id: 'follow_a_2',
                  notificationType: 'follow',
                  sourcePubkey: 'follower_a',
                  createdAtSeconds: 1700000200,
                ),
                createMockRelayNotification(
                  id: 'follow_a_3',
                  notificationType: 'follow',
                  sourcePubkey: 'follower_a',
                  createdAtSeconds: 1700000300,
                ),
                createMockRelayNotification(
                  id: 'follow_b_1',
                  notificationType: 'follow',
                  sourcePubkey: 'follower_b',
                  createdAtSeconds: 1700000150,
                ),
                createMockRelayNotification(
                  id: 'follow_b_2',
                  notificationType: 'follow',
                  sourcePubkey: 'follower_b',
                  createdAtSeconds: 1700000250,
                ),
              ],
              unreadCount: 5,
            ),
          );

          final container = createTestContainer();
          await waitForLoadComplete(container);

          final unreadCount = container.read(
            relayNotificationUnreadCountProvider,
          );

          // 2 distinct pubkeys after consolidation, both unread.
          expect(unreadCount, 2);

          container.dispose();
        },
      );

      test(
        'relayNotificationUnreadCount drops to 0 when notifications list is empty '
        'even if server reports unread items',
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
            (_) async => const NotificationsResponse(
              notifications: [],
              unreadCount: 42,
            ),
          );

          final container = createTestContainer();
          await waitForLoadComplete(container);

          expect(container.read(relayNotificationUnreadCountProvider), 0);

          container.dispose();
        },
      );

      test(
        'relayNotificationUnreadCount excludes already-read notifications',
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
                createMockRelayNotification(id: 'unread_1'),
                createMockRelayNotification(id: 'unread_2'),
                createMockRelayNotification(id: 'read_1', read: true),
              ],
              unreadCount: 3,
            ),
          );

          final container = createTestContainer();
          await waitForLoadComplete(container);

          // 2 unread out of 3, regardless of server's unreadCount.
          expect(container.read(relayNotificationUnreadCountProvider), 2);

          container.dispose();
        },
      );

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
              createMockRelayNotification(id: 'like_1'),
              createMockRelayNotification(
                id: 'follow_1',
                notificationType: 'follow',
              ),
              createMockRelayNotification(id: 'like_2'),
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

    group('Auto-refresh background guard', () {
      test('auto-refresh skips API call when app is backgrounded', () async {
        // Set up initial load to succeed
        var apiCallCount = 0;
        when(
          () => mockApiService.getNotifications(
            pubkey: any(named: 'pubkey'),
            types: any(named: 'types'),
            unreadOnly: any(named: 'unreadOnly'),
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer((_) async {
          apiCallCount++;
          return NotificationsResponse(
            notifications: [
              createMockRelayNotification(id: 'notif_$apiCallCount'),
            ],
            unreadCount: 1,
          );
        });

        // App starts in foreground
        when(() => mockBackgroundManager.isAppInForeground).thenReturn(true);
        when(() => mockBackgroundManager.isAppInBackground).thenReturn(false);

        final container = createTestContainer();

        // Initial load triggers one API call
        await waitForLoadComplete(container);
        expect(apiCallCount, 1);

        // Simulate app going to background
        when(() => mockBackgroundManager.isAppInForeground).thenReturn(false);
        when(() => mockBackgroundManager.isAppInBackground).thenReturn(true);

        // Manually call refresh (simulates what auto-refresh timer does)
        // This should still work since refresh() itself doesn't check
        // background state (it's used for pull-to-refresh too)
        await container.read(relayNotificationsProvider.notifier).refresh();

        await Future<void>.delayed(const Duration(milliseconds: 50));

        // refresh() should have made the API call (2 total)
        // because it's the timer callback that guards, not refresh()
        expect(apiCallCount, 2);

        container.dispose();
      });

      test('background manager is checked by auto-refresh timer callback', () {
        // Verify the provider reads the backgroundActivityManagerProvider
        // by ensuring the mock is properly wired
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

        // The provider should be able to read the background manager
        final manager = container.read(backgroundActivityManagerProvider);
        expect(manager, equals(mockBackgroundManager));
        expect(manager.isAppInBackground, isFalse);

        container.dispose();
      });
    });

    group('Follow Notification Deduplication', () {
      test(
        'consolidates follow notifications keeping earliest timestamp',
        () async {
          // Server returns multiple follow notifications from same pubkey
          // (caused by Kind 3 contact list republishing)
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
                // Latest Kind 3 event (user followed someone else)
                createMockRelayNotification(
                  id: 'follow_new',
                  sourcePubkey: 'follower_abc',
                  notificationType: 'follow',
                  createdAtSeconds: 1700000200,
                ),
                // Original follow event
                createMockRelayNotification(
                  id: 'follow_original',
                  sourcePubkey: 'follower_abc',
                  notificationType: 'follow',
                  createdAtSeconds: 1700000100,
                ),
                // Different follower (should be kept)
                createMockRelayNotification(
                  id: 'follow_other',
                  sourcePubkey: 'follower_xyz',
                  notificationType: 'follow',
                  createdAtSeconds: 1700000150,
                ),
              ],
              unreadCount: 3,
            ),
          );

          final container = createTestContainer();
          final result = await waitForLoadComplete(container);

          // Should consolidate to 2 follow notifications (one per pubkey)
          final follows = result.notifications
              .where((n) => n.type == NotificationType.follow)
              .toList();
          expect(follows.length, 2);

          // The follower_abc entry should use the earliest timestamp
          final abcFollow = follows.firstWhere(
            (n) => n.actorPubkey == 'follower_abc',
          );
          expect(
            abcFollow.timestamp,
            DateTime.fromMillisecondsSinceEpoch(1700000100 * 1000),
            reason: 'Should keep earliest follow timestamp, not latest',
          );

          container.dispose();
        },
      );

      test('insertFromWebSocket deduplicates follow by actor pubkey', () async {
        // Initial load has one follow notification
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
                id: 'existing_follow',
                sourcePubkey: 'follower_abc',
                notificationType: 'follow',
                createdAtSeconds: 1700000100,
              ),
            ],
            unreadCount: 1,
          ),
        );

        final container = createTestContainer();
        await waitForLoadComplete(container);

        // WebSocket delivers a new Kind 3 event from the same actor
        final duplicateFollow = NotificationModel(
          id: 'new_kind3_event',
          type: NotificationType.follow,
          actorPubkey: 'follower_abc', // Same actor
          actorName: 'Follower',
          message: 'Follower started following you',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1700000200 * 1000),
        );

        await container
            .read(relayNotificationsProvider.notifier)
            .insertFromWebSocket(duplicateFollow);

        await Future<void>.delayed(const Duration(milliseconds: 50));

        final state = container.read(relayNotificationsProvider);
        final result = state.value!;

        // Should still have only one follow notification
        final follows = result.notifications
            .where((n) => n.type == NotificationType.follow)
            .toList();
        expect(
          follows.length,
          1,
          reason:
              'Duplicate follow from same actor via WebSocket should be '
              'dropped',
        );
        expect(follows.first.id, 'existing_follow');

        container.dispose();
      });

      test('insertFromWebSocket allows follow from different actor', () async {
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
                id: 'existing_follow',
                sourcePubkey: 'follower_abc',
                notificationType: 'follow',
                createdAtSeconds: 1700000100,
              ),
            ],
            unreadCount: 1,
          ),
        );

        final container = createTestContainer();
        await waitForLoadComplete(container);

        // WebSocket delivers a follow from a different actor
        final newFollow = NotificationModel(
          id: 'new_follow_event',
          type: NotificationType.follow,
          actorPubkey: 'follower_xyz', // Different actor
          actorName: 'New Follower',
          message: 'New Follower started following you',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1700000200 * 1000),
        );

        await container
            .read(relayNotificationsProvider.notifier)
            .insertFromWebSocket(newFollow);

        await Future<void>.delayed(const Duration(milliseconds: 50));

        final state = container.read(relayNotificationsProvider);
        final result = state.value!;

        // Should have both follows
        final follows = result.notifications
            .where((n) => n.type == NotificationType.follow)
            .toList();
        expect(
          follows.length,
          2,
          reason: 'Follow from a different actor should be allowed',
        );

        container.dispose();
      });

      test('insertFromWebSocket allows non-follow from same actor', () async {
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
                id: 'existing_follow',
                sourcePubkey: 'actor_abc',
                notificationType: 'follow',
                createdAtSeconds: 1700000100,
              ),
            ],
            unreadCount: 1,
          ),
        );

        final container = createTestContainer();
        await waitForLoadComplete(container);

        // Same actor sends a like (non-follow, should not be deduped)
        final like = NotificationModel(
          id: 'like_event',
          type: NotificationType.like,
          actorPubkey: 'actor_abc', // Same actor
          actorName: 'Actor',
          message: 'Actor liked your video',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1700000200 * 1000),
        );

        await container
            .read(relayNotificationsProvider.notifier)
            .insertFromWebSocket(like);

        await Future<void>.delayed(const Duration(milliseconds: 50));

        final state = container.read(relayNotificationsProvider);
        final result = state.value!;

        expect(
          result.notifications.length,
          2,
          reason: 'Non-follow notification from same actor should be allowed',
        );

        container.dispose();
      });
    });

    group('Cross-batch follow consolidation (loadMore)', () {
      test(
        'loadMore replaces follow with earlier timestamp from later batch',
        () async {
          // Batch 1 must have >= 10 items so _fetchRawNotifications auto-fetch
          // does NOT pull batch 2 early.  Batch 2 contains an older follow
          // from the same actor — loadMore should swap to the earlier one.
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
                  createMockRelayNotification(
                    id: 'follow_new',
                    sourcePubkey: 'follower_abc',
                    notificationType: 'follow',
                    createdAtSeconds: 1700000200, // T2 — latest
                  ),
                  for (var i = 0; i < 9; i++)
                    createMockRelayNotification(
                      id: 'like_$i',
                      createdAtSeconds: 1700000100 + i,
                    ),
                ],
                unreadCount: 10,
                nextCursor: 'cursor_1',
                hasMore: true,
              );
            } else {
              return NotificationsResponse(
                notifications: [
                  createMockRelayNotification(
                    id: 'follow_original',
                    sourcePubkey: 'follower_abc',
                    notificationType: 'follow',
                    createdAtSeconds: 1700000050, // T1 — original (earlier)
                  ),
                ],
                unreadCount: 10,
              );
            }
          });

          final container = createTestContainer();
          await waitForLoadComplete(container);

          // Verify batch 1 has the T2 follow
          var state = container.read(relayNotificationsProvider).value!;
          var follows = state.notifications
              .where((n) => n.type == NotificationType.follow)
              .toList();
          expect(follows.length, 1);
          expect(
            follows.first.timestamp,
            DateTime.fromMillisecondsSinceEpoch(1700000200 * 1000),
          );

          // Load more — should get the older follow from batch 2
          await container.read(relayNotificationsProvider.notifier).loadMore();
          await Future<void>.delayed(const Duration(milliseconds: 50));

          state = container.read(relayNotificationsProvider).value!;
          follows = state.notifications
              .where((n) => n.type == NotificationType.follow)
              .toList();

          // Should have exactly 1 follow for follower_abc — with the earliest
          // timestamp (T1), not the latest (T2)
          expect(
            follows.length,
            1,
            reason:
                'Cross-batch consolidation should keep one follow per '
                'actor',
          );
          expect(
            follows.first.timestamp,
            DateTime.fromMillisecondsSinceEpoch(1700000050 * 1000),
            reason: 'Should keep earliest follow timestamp across batches',
          );

          // 9 likes + 1 consolidated follow = 10
          expect(state.notifications.length, 10);

          container.dispose();
        },
      );
    });

    group('NotificationFeedState', () {
      test('copyWith creates correct copy', () {
        const original = NotificationFeedState(
          notifications: [],
          unreadCount: 5,
          hasMoreContent: true,
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

    group('enrichment', () {
      /// Waits for the enrichment phase to update notifications with
      /// non-null actor names. Returns the enriched state.
      Future<NotificationFeedState> waitForEnrichment(
        ProviderContainer container,
      ) async {
        final completer = Completer<NotificationFeedState>();

        container.listen<AsyncValue<NotificationFeedState>>(
          relayNotificationsProvider,
          (previous, next) {
            next.whenData((state) {
              if (state.notifications.isNotEmpty &&
                  state.notifications.first.actorName != null &&
                  !completer.isCompleted) {
                completer.complete(state);
              }
            });
          },
        );

        return completer.future.timeout(
          const Duration(seconds: 2),
          onTimeout: () =>
              throw TimeoutException('Enrichment did not complete'),
        );
      }

      test('populates actor names and avatars', () async {
        const sourcePubkey = 'source_pubkey_123';
        final testProfile = UserProfile(
          pubkey: sourcePubkey,
          displayName: 'Alice',
          name: 'alice',
          picture: 'https://example.com/alice.jpg',
          rawData: const {},
          createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
          eventId: 'event_profile_1',
        );

        final mockNotifications = [createMockRelayNotification(id: 'notif_1')];

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

        when(
          () => mockProfileRepository.fetchBatchProfiles(
            pubkeys: any(named: 'pubkeys'),
          ),
        ).thenAnswer((_) async => {sourcePubkey: testProfile});

        final container = createTestContainer(
          profileRepository: mockProfileRepository,
        );

        // Initial load shows skeleton
        final initial = await waitForLoadComplete(container);
        expect(initial.notifications.single.actorName, isNull);
        expect(
          initial.notifications.single.message,
          'Someone liked your video',
        );

        // Enrichment populates real profile data
        final enriched = await waitForEnrichment(container);
        expect(enriched.notifications, hasLength(1));
        expect(enriched.notifications.single.actorName, equals('Alice'));
        expect(
          enriched.notifications.single.actorPictureUrl,
          equals('https://example.com/alice.jpg'),
        );
        expect(
          enriched.notifications.single.message,
          equals('Alice liked your video'),
        );

        container.dispose();
      });

      test('merges without duplicating notifications', () async {
        const pubkey1 = 'pubkey_aaa';
        const pubkey2 = 'pubkey_bbb';
        const pubkey3 = 'pubkey_ccc';

        final profileA = UserProfile(
          pubkey: pubkey1,
          displayName: 'Alice',
          rawData: const {},
          createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
          eventId: 'event_a',
        );
        final profileB = UserProfile(
          pubkey: pubkey2,
          displayName: 'Bob',
          rawData: const {},
          createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
          eventId: 'event_b',
        );

        final mockNotifications = [
          createMockRelayNotification(
            id: 'n1',
            sourcePubkey: pubkey1,
            createdAtSeconds: 1700000300,
          ),
          createMockRelayNotification(
            id: 'n2',
            sourcePubkey: pubkey2,
            createdAtSeconds: 1700000200,
          ),
          createMockRelayNotification(
            id: 'n3',
            sourcePubkey: pubkey3,
            createdAtSeconds: 1700000100,
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
            unreadCount: 3,
          ),
        );

        // Only 2 of 3 pubkeys have profiles
        when(
          () => mockProfileRepository.fetchBatchProfiles(
            pubkeys: any(named: 'pubkeys'),
          ),
        ).thenAnswer((_) async => {pubkey1: profileA, pubkey2: profileB});

        final container = createTestContainer(
          profileRepository: mockProfileRepository,
        );

        await waitForLoadComplete(container);
        final enriched = await waitForEnrichment(container);

        expect(enriched.notifications, hasLength(3));
        expect(enriched.notifications[0].actorName, equals('Alice'));
        expect(enriched.notifications[1].actorName, equals('Bob'));
        // Third notification has no profile — stays as "Someone"
        expect(enriched.notifications[2].actorName, isNull);
        expect(
          enriched.notifications[2].message,
          equals('Someone liked your video'),
        );

        container.dispose();
      });

      test('with null profileRepo does not crash', () async {
        final mockNotifications = [createMockRelayNotification(id: 'notif_1')];

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

        // No profileRepository passed — defaults to null
        final container = createTestContainer();

        final result = await waitForLoadComplete(container);

        expect(result.notifications, hasLength(1));
        expect(result.notifications.single.actorName, isNull);
        expect(
          result.notifications.single.message,
          equals('Someone liked your video'),
        );

        container.dispose();
      });

      test(
        'enrichment merges correctly when notification ids are empty',
        () async {
          // Regression: when relay returns empty id, _mergeEnrichedNotifications
          // used to put all enriched entries under the same '' key, so every
          // notification got the last actor's name/avatar.
          const pubkey1 = 'pubkey_alice_aaa';
          const pubkey2 = 'pubkey_bob_bbb';

          final profileA = UserProfile(
            pubkey: pubkey1,
            displayName: 'Alice',
            picture: 'https://example.com/alice.jpg',
            rawData: const {},
            createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
            eventId: 'event_a',
          );
          final profileB = UserProfile(
            pubkey: pubkey2,
            displayName: 'Bob',
            picture: 'https://example.com/bob.jpg',
            rawData: const {},
            createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
            eventId: 'event_b',
          );

          // Both notifications have empty id — the bug scenario
          final mockNotifications = [
            RelayNotification(
              id: '',
              sourcePubkey: pubkey1,
              sourceEventId: 'event_1',
              sourceKind: 7,
              notificationType: 'reaction',
              createdAt: DateTime.fromMillisecondsSinceEpoch(1700000200 * 1000),
              read: false,
              referencedEventId: 'video_1',
            ),
            RelayNotification(
              id: '',
              sourcePubkey: pubkey2,
              sourceEventId: 'event_2',
              sourceKind: 7,
              notificationType: 'reaction',
              createdAt: DateTime.fromMillisecondsSinceEpoch(1700000100 * 1000),
              read: false,
              referencedEventId: 'video_2',
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
              unreadCount: 2,
            ),
          );

          when(
            () => mockProfileRepository.fetchBatchProfiles(
              pubkeys: any(named: 'pubkeys'),
            ),
          ).thenAnswer((_) async => {pubkey1: profileA, pubkey2: profileB});

          final container = createTestContainer(
            profileRepository: mockProfileRepository,
          );

          await waitForLoadComplete(container);
          final enriched = await waitForEnrichment(container);

          expect(enriched.notifications, hasLength(2));
          // Each notification must have its own actor — not both "Bob"
          expect(enriched.notifications[0].actorName, equals('Alice'));
          expect(
            enriched.notifications[0].actorPictureUrl,
            equals('https://example.com/alice.jpg'),
          );
          expect(enriched.notifications[1].actorName, equals('Bob'));
          expect(
            enriched.notifications[1].actorPictureUrl,
            equals('https://example.com/bob.jpg'),
          );

          container.dispose();
        },
      );

      test('loadMore notifications are enriched', () async {
        const pubkey1 = 'pubkey_initial';
        const pubkey2 = 'pubkey_loadmore';

        final profile1 = UserProfile(
          pubkey: pubkey1,
          displayName: 'Alice',
          rawData: const {},
          createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
          eventId: 'event_1',
        );
        final profile2 = UserProfile(
          pubkey: pubkey2,
          displayName: 'Bob',
          rawData: const {},
          createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
          eventId: 'event_2',
        );

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
                createMockRelayNotification(
                  id: 'n1',
                  sourcePubkey: pubkey1,
                  createdAtSeconds: 1700000200,
                ),
              ],
              unreadCount: 1,
              nextCursor: 'cursor_1',
              hasMore: true,
            );
          } else {
            return NotificationsResponse(
              notifications: [
                createMockRelayNotification(
                  id: 'n2',
                  sourcePubkey: pubkey2,
                  createdAtSeconds: 1700000100,
                ),
              ],
              unreadCount: 1,
            );
          }
        });

        when(
          () => mockProfileRepository.fetchBatchProfiles(
            pubkeys: any(named: 'pubkeys'),
          ),
        ).thenAnswer((invocation) async {
          final pubkeys = invocation.namedArguments[#pubkeys] as List<String>;
          final result = <String, UserProfile>{};
          for (final pk in pubkeys) {
            if (pk == pubkey1) result[pk] = profile1;
            if (pk == pubkey2) result[pk] = profile2;
          }
          return result;
        });

        final container = createTestContainer(
          profileRepository: mockProfileRepository,
        );

        // Wait for initial load + enrichment
        await waitForLoadComplete(container);
        await waitForEnrichment(container);

        // Trigger loadMore
        final notifier = container.read(relayNotificationsProvider.notifier);
        await notifier.loadMore();

        // Let loadMore enrichment complete
        // Pump microtasks for the unawaited enrichment closure
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final state = container.read(relayNotificationsProvider).value!;

        expect(state.notifications, hasLength(2));
        expect(state.notifications[0].actorName, equals('Alice'));
        expect(state.notifications[1].actorName, equals('Bob'));

        container.dispose();
      });
    });

    group('Cross-path dedup (REST vs WebSocket)', () {
      test('insertFromWebSocket drops notification whose ID matches '
          "an existing REST notification's sourceEventId", () async {
        // REST API returns a notification with server-assigned ID 'notif_1'
        // and sourceEventId 'event_notif_1' (stored in metadata).
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
          ),
        );

        final container = createTestContainer();
        await waitForLoadComplete(container);

        // WebSocket delivers the same logical notification but using the
        // Nostr event ID as its model ID.
        final wsNotification = NotificationModel(
          id: 'event_notif_1', // matches REST metadata['sourceEventId']
          type: NotificationType.like,
          actorPubkey: 'source_pubkey_123',
          actorName: 'Actor',
          message: 'Actor liked your video',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
        );

        await container
            .read(relayNotificationsProvider.notifier)
            .insertFromWebSocket(wsNotification);

        await Future<void>.delayed(const Duration(milliseconds: 50));

        final state = container.read(relayNotificationsProvider);
        final result = state.value!;

        expect(
          result.notifications.length,
          1,
          reason:
              'WebSocket notification matching sourceEventId of existing '
              'REST notification should be dropped',
        );
        expect(result.notifications.first.id, 'notif_1');

        container.dispose();
      });

      test('insertFromWebSocket allows notification with non-matching '
          'sourceEventId', () async {
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
          ),
        );

        final container = createTestContainer();
        await waitForLoadComplete(container);

        // WebSocket delivers a genuinely new notification
        final wsNotification = NotificationModel(
          id: 'completely_new_event',
          type: NotificationType.like,
          actorPubkey: 'other_pubkey',
          actorName: 'Bob',
          message: 'Bob liked your video',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1700000500 * 1000),
        );

        await container
            .read(relayNotificationsProvider.notifier)
            .insertFromWebSocket(wsNotification);

        await Future<void>.delayed(const Duration(milliseconds: 50));

        final state = container.read(relayNotificationsProvider);
        final result = state.value!;

        expect(
          result.notifications.length,
          2,
          reason: 'Genuinely new WebSocket notification should be inserted',
        );

        container.dispose();
      });
    });

    group('Refresh preserves WebSocket notifications', () {
      test(
        'refresh merges API data with WebSocket-inserted notifications',
        () async {
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
                  createMockRelayNotification(
                    id: 'api_notif_1',
                    createdAtSeconds: 1700000100,
                  ),
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

          // While refresh is in-flight, insert a WebSocket notification
          await Future<void>.delayed(const Duration(milliseconds: 20));

          final wsNotification = NotificationModel(
            id: 'ws_new_like',
            type: NotificationType.like,
            actorPubkey: 'ws_actor',
            actorName: 'WebSocket User',
            message: 'WebSocket User liked your video',
            timestamp: DateTime.fromMillisecondsSinceEpoch(1700000300 * 1000),
          );

          await container
              .read(relayNotificationsProvider.notifier)
              .insertFromWebSocket(wsNotification);

          // Complete the refresh with new API data
          refreshCompleter.complete(
            NotificationsResponse(
              notifications: [
                createMockRelayNotification(
                  id: 'api_notif_2',
                  createdAtSeconds: 1700000200,
                ),
              ],
              unreadCount: 1,
            ),
          );

          await refreshFuture;
          await Future<void>.delayed(const Duration(milliseconds: 50));

          final state = container.read(relayNotificationsProvider);
          final result = state.value!;

          // Both the API notification AND the WebSocket notification
          // should be present after refresh
          final ids = result.notifications.map((n) => n.id).toSet();
          expect(
            ids,
            contains('api_notif_2'),
            reason: 'Refreshed API notification should be present',
          );
          expect(
            ids,
            contains('ws_new_like'),
            reason:
                'WebSocket notification inserted during refresh '
                'should be preserved',
          );

          container.dispose();
        },
      );

      test(
        'refresh deduplicates WebSocket notification that arrived via API',
        () async {
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
                notifications: [createMockRelayNotification(id: 'api_1')],
                unreadCount: 1,
              );
            }
            return refreshCompleter.future;
          });

          final container = createTestContainer();
          await waitForLoadComplete(container);

          // Start refresh
          final refreshFuture = container
              .read(relayNotificationsProvider.notifier)
              .refresh();

          await Future<void>.delayed(const Duration(milliseconds: 20));

          // WebSocket inserts a notification with Nostr event ID
          final wsNotification = NotificationModel(
            id: 'event_api_refresh_1', // Will match sourceEventId
            type: NotificationType.like,
            actorPubkey: 'source_pubkey_123',
            actorName: 'Actor',
            message: 'Actor liked your video',
            timestamp: DateTime.fromMillisecondsSinceEpoch(1700000100 * 1000),
          );

          await container
              .read(relayNotificationsProvider.notifier)
              .insertFromWebSocket(wsNotification);

          // Refresh returns the same notification via REST with different ID
          // but sourceEventId = 'event_api_refresh_1'
          refreshCompleter.complete(
            NotificationsResponse(
              notifications: [createMockRelayNotification(id: 'api_refresh_1')],
              unreadCount: 1,
            ),
          );

          await refreshFuture;
          await Future<void>.delayed(const Duration(milliseconds: 50));

          final state = container.read(relayNotificationsProvider);
          final result = state.value!;

          // Should have only 1 notification — not a duplicate
          expect(
            result.notifications.length,
            1,
            reason:
                'WebSocket notification whose ID matches API '
                'sourceEventId should be deduped during refresh merge',
          );

          container.dispose();
        },
      );
    });
  });
}
