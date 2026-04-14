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
import 'package:openvine/services/content_blocklist_service.dart';

class _MockNotificationRepository extends Mock
    implements NotificationRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockContentBlocklistService extends Mock
    implements ContentBlocklistService {}

/// Test actor helper.
ActorInfo _actor({
  String pubkey = 'abc123',
  String displayName = 'Alice',
}) {
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
    late _MockContentBlocklistService mockBlocklistService;

    setUp(() {
      mockNotificationRepo = _MockNotificationRepository();
      mockFollowRepo = _MockFollowRepository();
      mockBlocklistService = _MockContentBlocklistService();

      when(
        () => mockBlocklistService.shouldFilterFromFeeds(any()),
      ).thenReturn(false);
    });

    NotificationFeedBloc createBloc({
      ContentBlocklistService? contentBlocklistService,
    }) => NotificationFeedBloc(
      notificationRepository: mockNotificationRepo,
      followRepository: mockFollowRepo,
      contentBlocklistService: contentBlocklistService,
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
          when(
            () => mockNotificationRepo.getNotifications(),
          ).thenAnswer(
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
        act: (bloc) => bloc.add(
          NotificationFeedRealtimeReceived(_single(id: 'realtime')),
        ),
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
        act: (bloc) => bloc.add(
          NotificationFeedRealtimeReceived(_single(id: 'existing')),
        ),
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
    });

    group('NotificationFeedMarkAllRead', () {
      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'sets unread count to 0',
        setUp: () {
          when(
            () => mockNotificationRepo.markAllAsRead(),
          ).thenAnswer((_) async {});
        },
        build: createBloc,
        seed: () => NotificationFeedState(
          status: NotificationFeedStatus.loaded,
          notifications: [_single()],
          unreadCount: 5,
        ),
        act: (bloc) => bloc.add(NotificationFeedMarkAllRead()),
        expect: () => [
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            notifications: [_single()],
          ),
        ],
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
          when(
            () => mockFollowRepo.follow('pub123'),
          ).thenAnswer((_) async {});
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

    group('blocklist filtering', () {
      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'filters single notification from blocked user on load',
        setUp: () {
          when(
            () => mockBlocklistService.shouldFilterFromFeeds('abc123'),
          ).thenReturn(true);
          when(
            () => mockNotificationRepo.refresh(),
          ).thenAnswer(
            (_) async => NotificationPage(
              items: [_single()],
              unreadCount: 1,
            ),
          );
        },
        build: () => createBloc(contentBlocklistService: mockBlocklistService),
        act: (bloc) => bloc.add(NotificationFeedStarted()),
        expect: () => [
          NotificationFeedState(status: NotificationFeedStatus.loading),
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            unreadCount: 1,
            hasMore: false,
          ),
        ],
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'keeps non-blocked single notification on load',
        setUp: () {
          when(
            () => mockNotificationRepo.refresh(),
          ).thenAnswer(
            (_) async => NotificationPage(
              items: [_single()],
              unreadCount: 1,
            ),
          );
        },
        build: () => createBloc(contentBlocklistService: mockBlocklistService),
        act: (bloc) => bloc.add(NotificationFeedStarted()),
        expect: () => [
          NotificationFeedState(status: NotificationFeedStatus.loading),
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            notifications: [_single()],
            unreadCount: 1,
            hasMore: false,
          ),
        ],
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'filters blocked actors from grouped notification',
        setUp: () {
          when(
            () => mockBlocklistService.shouldFilterFromFeeds('blocked1'),
          ).thenReturn(true);
          when(
            () => mockNotificationRepo.refresh(),
          ).thenAnswer(
            (_) async => NotificationPage(
              items: [
                GroupedNotification(
                  id: 'g1',
                  type: NotificationKind.like,
                  actors: [
                    _actor(pubkey: 'keep1'),
                    _actor(pubkey: 'blocked1', displayName: 'Blocked'),
                    _actor(pubkey: 'keep2', displayName: 'Charlie'),
                  ],
                  totalCount: 3,
                  timestamp: DateTime(2026),
                  targetEventId: 'video1',
                ),
              ],
              unreadCount: 1,
            ),
          );
        },
        build: () => createBloc(contentBlocklistService: mockBlocklistService),
        act: (bloc) => bloc.add(NotificationFeedStarted()),
        expect: () => [
          NotificationFeedState(status: NotificationFeedStatus.loading),
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            notifications: [
              GroupedNotification(
                id: 'g1',
                type: NotificationKind.like,
                actors: [
                  _actor(pubkey: 'keep1'),
                  _actor(pubkey: 'keep2', displayName: 'Charlie'),
                ],
                totalCount: 2,
                timestamp: DateTime(2026),
                targetEventId: 'video1',
              ),
            ],
            unreadCount: 1,
            hasMore: false,
          ),
        ],
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'removes grouped notification when all actors are blocked',
        setUp: () {
          when(
            () => mockBlocklistService.shouldFilterFromFeeds('b1'),
          ).thenReturn(true);
          when(
            () => mockBlocklistService.shouldFilterFromFeeds('b2'),
          ).thenReturn(true);
          when(
            () => mockNotificationRepo.refresh(),
          ).thenAnswer(
            (_) async => NotificationPage(
              items: [
                GroupedNotification(
                  id: 'g1',
                  type: NotificationKind.like,
                  actors: [
                    _actor(pubkey: 'b1', displayName: 'Blocked1'),
                    _actor(pubkey: 'b2', displayName: 'Blocked2'),
                  ],
                  totalCount: 2,
                  timestamp: DateTime(2026),
                ),
              ],
              unreadCount: 1,
            ),
          );
        },
        build: () => createBloc(contentBlocklistService: mockBlocklistService),
        act: (bloc) => bloc.add(NotificationFeedStarted()),
        expect: () => [
          NotificationFeedState(status: NotificationFeedStatus.loading),
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            unreadCount: 1,
            hasMore: false,
          ),
        ],
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'filters blocked user from realtime notification',
        setUp: () {
          when(
            () => mockBlocklistService.shouldFilterFromFeeds('abc123'),
          ).thenReturn(true);
        },
        build: () => createBloc(contentBlocklistService: mockBlocklistService),
        seed: () => NotificationFeedState(
          status: NotificationFeedStatus.loaded,
          notifications: [_single(id: 'existing')],
          unreadCount: 1,
        ),
        act: (bloc) => bloc.add(
          NotificationFeedRealtimeReceived(
            _single(id: 'blocked-notif'),
          ),
        ),
        expect: () => <NotificationFeedState>[],
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'works without contentBlocklistService (null)',
        setUp: () {
          when(
            () => mockNotificationRepo.refresh(),
          ).thenAnswer(
            (_) async => NotificationPage(
              items: [_single()],
              unreadCount: 1,
              hasMore: true,
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(NotificationFeedStarted()),
        expect: () => [
          NotificationFeedState(status: NotificationFeedStatus.loading),
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            notifications: [_single()],
            unreadCount: 1,
          ),
        ],
      );
    });
  });
}
