// ABOUTME: Tests for NotificationFeedBloc — covers initial load, pagination,
// ABOUTME: refresh, push, realtime, mark-read, and follow-back events.

// ignore_for_file: prefer_const_constructors

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/notifications/bloc/notification_feed_bloc.dart';

class _MockNotificationRepository extends Mock
    implements NotificationRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

/// Test actor helper.
ActorInfo _actor({String pubkey = 'abc123', String displayName = 'Alice'}) {
  return ActorInfo(pubkey: pubkey, displayName: displayName);
}

/// Test single notification helper.
SingleNotification _single({
  String id = 'n1',
  NotificationKind type = NotificationKind.like,
  String pubkey = 'abc123',
  String displayName = 'Alice',
  bool isRead = false,
  String? targetEventId,
}) {
  return SingleNotification(
    id: id,
    type: type,
    actor: _actor(pubkey: pubkey, displayName: displayName),
    timestamp: DateTime(2026),
    isRead: isRead,
    targetEventId: targetEventId,
  );
}

/// Test grouped notification helper.
GroupedNotification _grouped({
  String id = 'group_like_video1',
  String? targetEventId = 'video1',
  int totalCount = 3,
  bool isRead = false,
}) {
  return GroupedNotification(
    id: id,
    type: NotificationKind.like,
    actors: [
      _actor(),
      _actor(pubkey: 'def456', displayName: 'Bob'),
    ],
    totalCount: totalCount,
    timestamp: DateTime(2026),
    isRead: isRead,
    targetEventId: targetEventId,
  );
}

void main() {
  group(NotificationFeedBloc, () {
    late _MockNotificationRepository mockNotificationRepo;
    late _MockFollowRepository mockFollowRepo;

    setUpAll(() {
      registerFallbackValue(_single());
    });

    setUp(() {
      mockNotificationRepo = _MockNotificationRepository();
      mockFollowRepo = _MockFollowRepository();

      when(
        () => mockNotificationRepo.filterRealtimeNotification(any()),
      ).thenAnswer(
        (invocation) =>
            invocation.positionalArguments.first as NotificationItem,
      );
    });

    NotificationFeedBloc createBloc() => NotificationFeedBloc(
      notificationRepository: mockNotificationRepo,
      followRepository: mockFollowRepo,
    );

    group('NotificationFeedStarted', () {
      final page = NotificationPage(
        items: [_single()],
        unreadCount: 1,
        hasMore: true,
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'emits [loading, loaded] on success',
        setUp: () {
          when(
            () => mockNotificationRepo.refresh(),
          ).thenAnswer((_) async => page);
        },
        build: createBloc,
        act: (bloc) => bloc.add(NotificationFeedStarted()),
        expect: () => [
          NotificationFeedState(status: NotificationFeedStatus.loading),
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            notifications: page.items,
            unreadCount: 1,
          ),
        ],
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'emits [loading, failure] on error',
        setUp: () {
          when(
            () => mockNotificationRepo.refresh(),
          ).thenThrow(Exception('network error'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(NotificationFeedStarted()),
        expect: () => [
          NotificationFeedState(status: NotificationFeedStatus.loading),
          NotificationFeedState(status: NotificationFeedStatus.failure),
        ],
        errors: () => [isA<Exception>()],
      );
    });

    group('NotificationFeedLoadMore', () {
      final existingItem = _single();
      final newItem = _single(id: 'n2', displayName: 'Bob', pubkey: 'def456');

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'appends new items and deduplicates',
        setUp: () {
          when(() => mockNotificationRepo.getNotifications()).thenAnswer(
            (_) async => NotificationPage(
              items: [existingItem, newItem],
              unreadCount: 2,
            ),
          );
        },
        build: createBloc,
        seed: () => NotificationFeedState(
          status: NotificationFeedStatus.loaded,
          notifications: [existingItem],
        ),
        act: (bloc) => bloc.add(NotificationFeedLoadMore()),
        expect: () => [
          // isLoadingMore = true
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            notifications: [existingItem],
            isLoadingMore: true,
          ),
          // Appended — n1 deduped, only n2 added
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            notifications: [existingItem, newItem],
            hasMore: false,
          ),
        ],
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'skips when hasMore is false',
        build: createBloc,
        seed: () => NotificationFeedState(
          status: NotificationFeedStatus.loaded,
          hasMore: false,
        ),
        act: (bloc) => bloc.add(NotificationFeedLoadMore()),
        expect: () => <NotificationFeedState>[],
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'skips when already loading more',
        build: createBloc,
        seed: () => NotificationFeedState(
          status: NotificationFeedStatus.loaded,
          isLoadingMore: true,
        ),
        act: (bloc) => bloc.add(NotificationFeedLoadMore()),
        expect: () => <NotificationFeedState>[],
      );
    });

    group('NotificationFeedRefreshed', () {
      final page = NotificationPage(
        items: [_single(id: 'refreshed')],
        unreadCount: 0,
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'replaces all notifications on refresh',
        setUp: () {
          when(
            () => mockNotificationRepo.refresh(),
          ).thenAnswer((_) async => page);
        },
        build: createBloc,
        seed: () => NotificationFeedState(
          status: NotificationFeedStatus.loaded,
          notifications: [_single(id: 'old')],
        ),
        act: (bloc) => bloc.add(NotificationFeedRefreshed()),
        expect: () => [
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            notifications: page.items,
            hasMore: false,
          ),
        ],
      );
    });

    group('NotificationFeedPushReceived', () {
      final page = NotificationPage(
        items: [_single(id: 'pushed')],
        unreadCount: 3,
        hasMore: true,
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'triggers refresh on push received',
        setUp: () {
          when(
            () => mockNotificationRepo.refresh(),
          ).thenAnswer((_) async => page);
        },
        build: createBloc,
        seed: () => NotificationFeedState(
          status: NotificationFeedStatus.loaded,
          notifications: [_single(id: 'old')],
        ),
        act: (bloc) => bloc.add(NotificationFeedPushReceived()),
        expect: () => [
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            notifications: page.items,
            unreadCount: 3,
          ),
        ],
      );
    });

    group('NotificationFeedRealtimeReceived', () {
      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'inserts at top and increments unread count',
        build: createBloc,
        seed: () => NotificationFeedState(
          status: NotificationFeedStatus.loaded,
          notifications: [_single(id: 'existing')],
          unreadCount: 1,
        ),
        act: (bloc) =>
            bloc.add(NotificationFeedRealtimeReceived(_single(id: 'realtime'))),
        expect: () => [
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            notifications: [
              _single(id: 'realtime'),
              _single(id: 'existing'),
            ],
            unreadCount: 2,
          ),
        ],
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'deduplicates by ID — skips if already present',
        build: createBloc,
        seed: () => NotificationFeedState(
          status: NotificationFeedStatus.loaded,
          notifications: [_single(id: 'existing')],
          unreadCount: 1,
        ),
        act: (bloc) =>
            bloc.add(NotificationFeedRealtimeReceived(_single(id: 'existing'))),
        expect: () => <NotificationFeedState>[],
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'deduplicates by targetEventId — skips if grouped notification '
        'already covers that video',
        build: createBloc,
        seed: () => NotificationFeedState(
          status: NotificationFeedStatus.loaded,
          notifications: [_grouped()],
          unreadCount: 1,
        ),
        act: (bloc) => bloc.add(
          NotificationFeedRealtimeReceived(
            _single(id: 'new-like', targetEventId: 'video1'),
          ),
        ),
        expect: () => <NotificationFeedState>[],
      );
    });

    group('NotificationFeedItemTapped', () {
      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'marks notification as read locally and decrements unread',
        setUp: () {
          when(
            () => mockNotificationRepo.markAsRead(any()),
          ).thenAnswer((_) async {});
        },
        build: createBloc,
        seed: () => NotificationFeedState(
          status: NotificationFeedStatus.loaded,
          notifications: [_single()],
          unreadCount: 1,
        ),
        act: (bloc) => bloc.add(NotificationFeedItemTapped('n1')),
        expect: () => [
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            notifications: [_single(isRead: true)],
          ),
        ],
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'marks a tapped grouped notification as read and decrements unread',
        setUp: () {
          when(
            () => mockNotificationRepo.markAsRead(any()),
          ).thenAnswer((_) async {});
        },
        build: createBloc,
        seed: () => NotificationFeedState(
          status: NotificationFeedStatus.loaded,
          notifications: [_grouped()],
          unreadCount: 1,
        ),
        act: (bloc) =>
            bloc.add(NotificationFeedItemTapped('group_like_video1')),
        expect: () => [
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            notifications: [_grouped(isRead: true)],
          ),
        ],
      );
    });

    group('NotificationFeedMarkAllRead', () {
      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'flips isRead on every notification and zeros unread count',
        setUp: () {
          when(
            () => mockNotificationRepo.markAllAsRead(),
          ).thenAnswer((_) async {});
        },
        build: createBloc,
        seed: () => NotificationFeedState(
          status: NotificationFeedStatus.loaded,
          notifications: [_single(), _grouped()],
          unreadCount: 5,
        ),
        act: (bloc) => bloc.add(NotificationFeedMarkAllRead()),
        expect: () => [
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            notifications: [_single(isRead: true), _grouped(isRead: true)],
          ),
        ],
        verify: (bloc) {
          // Derived badge reflects the flipped list immediately.
          expect(bloc.state.unreadBadgeCount, 0);
        },
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'is a no-op when everything is already read and the count is zero',
        setUp: () {
          when(
            () => mockNotificationRepo.markAllAsRead(),
          ).thenAnswer((_) async {});
        },
        build: createBloc,
        seed: () => NotificationFeedState(
          status: NotificationFeedStatus.loaded,
          notifications: [_single(isRead: true)],
          // ignore: avoid_redundant_argument_values
          unreadCount: 0,
        ),
        act: (bloc) => bloc.add(NotificationFeedMarkAllRead()),
        expect: () => <NotificationFeedState>[],
        verify: (_) {
          verify(() => mockNotificationRepo.markAllAsRead()).called(1);
        },
      );
    });

    group('NotificationFeedFollowBack', () {
      final followNotif = _single(
        id: 'follow1',
        type: NotificationKind.follow,
        pubkey: 'pub123',
        displayName: 'Charlie',
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'updates isFollowingBack on matching follow notification',
        setUp: () {
          when(() => mockFollowRepo.follow('pub123')).thenAnswer((_) async {});
        },
        build: createBloc,
        seed: () => NotificationFeedState(
          status: NotificationFeedStatus.loaded,
          notifications: [followNotif],
        ),
        act: (bloc) => bloc.add(NotificationFeedFollowBack('pub123')),
        expect: () => [
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            notifications: [followNotif.copyWith(isFollowingBack: true)],
          ),
        ],
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'emits error when follow fails',
        setUp: () {
          when(
            () => mockFollowRepo.follow('pub123'),
          ).thenThrow(Exception('follow failed'));
        },
        build: createBloc,
        seed: () => NotificationFeedState(
          status: NotificationFeedStatus.loaded,
          notifications: [followNotif],
        ),
        act: (bloc) => bloc.add(NotificationFeedFollowBack('pub123')),
        expect: () => <NotificationFeedState>[],
        errors: () => [isA<Exception>()],
      );
    });

    group('unreadBadgeCount', () {
      test('derives from the consolidated unread list, not the server-reported '
          'unreadCount inflated by Kind 3 republishes', () {
        // Repository already consolidated 5 raw follow rows from 2 distinct
        // pubkeys down to 2 visible items, but the server still reports
        // unreadCount: 5 (funnelcake#234). The badge must follow the list.
        final state = NotificationFeedState(
          status: NotificationFeedStatus.loaded,
          notifications: [
            _single(
              id: 'follow_a',
              type: NotificationKind.follow,
              pubkey: 'follower_a',
            ),
            _single(
              id: 'follow_b',
              type: NotificationKind.follow,
              pubkey: 'follower_b',
            ),
          ],
          unreadCount: 5,
        );

        expect(state.unreadBadgeCount, 2);
      });

      test('drops to 0 when notifications list is empty even if server reports '
          'unread items', () {
        const state = NotificationFeedState(
          status: NotificationFeedStatus.loaded,
          unreadCount: 42,
        );

        expect(state.unreadBadgeCount, 0);
      });

      test('excludes already-read notifications', () {
        final state = NotificationFeedState(
          status: NotificationFeedStatus.loaded,
          notifications: [
            _single(id: 'unread_1'),
            _single(id: 'unread_2', pubkey: 'def'),
            _single(id: 'read_1', pubkey: 'ghi', isRead: true),
          ],
          unreadCount: 3,
        );

        expect(state.unreadBadgeCount, 2);
      });

      test('counts unread grouped notifications alongside singles', () {
        final state = NotificationFeedState(
          status: NotificationFeedStatus.loaded,
          notifications: [
            _single(),
            _grouped(),
            _grouped(id: 'group2', targetEventId: 'video2', isRead: true),
          ],
        );

        // Two unread (one single + one grouped), one read group excluded.
        expect(state.unreadBadgeCount, 2);
      });
    });

    group('realtime blocklist filtering', () {
      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'skips realtime notification when repository filter returns null',
        setUp: () {
          when(
            () => mockNotificationRepo.filterRealtimeNotification(any()),
          ).thenReturn(null);
        },
        build: createBloc,
        seed: () => NotificationFeedState(
          status: NotificationFeedStatus.loaded,
          notifications: [_single(id: 'existing')],
          unreadCount: 1,
        ),
        act: (bloc) => bloc.add(
          NotificationFeedRealtimeReceived(_single(id: 'blocked-notif')),
        ),
        expect: () => <NotificationFeedState>[],
      );
    });
  });
}
