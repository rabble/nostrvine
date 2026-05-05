// ABOUTME: Tests for NotificationFeedBloc — covers initial load, pagination,
// ABOUTME: refresh, push, realtime enrichment + group merge, mark-read, and
// ABOUTME: follow-back events.

// ignore_for_file: prefer_const_constructors

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/notifications/bloc/notification_feed_bloc.dart';

class _MockNotificationRepository extends Mock
    implements NotificationRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _FakeRelayNotification extends Fake implements RelayNotification {}

const _alicePubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _bobPubkey =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _videoEventId =
    '1111111111111111111111111111111111111111111111111111111111111111';

ActorInfo _actor({
  String pubkey = _alicePubkey,
  String displayName = 'Alice',
}) {
  return ActorInfo(pubkey: pubkey, displayName: displayName);
}

VideoNotification _videoNotif({
  String id = 'v1',
  NotificationKind type = NotificationKind.like,
  List<ActorInfo>? actors,
  int totalCount = 1,
  String videoEventId = _videoEventId,
  bool isRead = false,
  DateTime? timestamp,
}) {
  return VideoNotification(
    id: id,
    type: type,
    videoEventId: videoEventId,
    actors: actors ?? [_actor()],
    totalCount: totalCount,
    timestamp: timestamp ?? DateTime(2026),
    isRead: isRead,
  );
}

ActorNotification _actorNotif({
  String id = 'a1',
  NotificationKind type = NotificationKind.follow,
  String pubkey = _alicePubkey,
  String displayName = 'Alice',
  bool isFollowingBack = false,
  bool isRead = false,
}) {
  return ActorNotification(
    id: id,
    type: type,
    actor: _actor(pubkey: pubkey, displayName: displayName),
    timestamp: DateTime(2026),
    isFollowingBack: isFollowingBack,
    isRead: isRead,
  );
}

RelayNotification _rawRelay({String id = 'realtime'}) {
  return RelayNotification(
    id: id,
    sourcePubkey: _alicePubkey,
    sourceEventId: 'src_$id',
    sourceKind: 7,
    notificationType: 'reaction',
    createdAt: DateTime(2026),
    read: false,
    referencedEventId: _videoEventId,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeRelayNotification());
  });

  group(NotificationFeedBloc, () {
    late _MockNotificationRepository mockNotificationRepo;
    late _MockFollowRepository mockFollowRepo;

    setUp(() {
      mockNotificationRepo = _MockNotificationRepository();
      mockFollowRepo = _MockFollowRepository();
    });

    NotificationFeedBloc createBloc() => NotificationFeedBloc(
      notificationRepository: mockNotificationRepo,
      followRepository: mockFollowRepo,
    );

    group('NotificationFeedStarted', () {
      final page = NotificationPage(
        items: [_videoNotif()],
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
      final existingItem = _videoNotif();
      final newItem = _videoNotif(
        id: 'v2',
        videoEventId:
            '2222222222222222222222222222222222222222222222222222222222222222',
      );

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
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            notifications: [existingItem],
            isLoadingMore: true,
          ),
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
        items: [_videoNotif(id: 'refreshed')],
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
          notifications: [_videoNotif(id: 'old')],
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
        items: [_videoNotif(id: 'pushed')],
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
          notifications: [_videoNotif(id: 'old')],
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
        'inserts enriched VideoNotification at top when no matching group',
        setUp: () {
          when(
            () => mockNotificationRepo.enrichOne(any()),
          ).thenAnswer((_) async => _videoNotif(id: 'realtime'));
        },
        build: createBloc,
        seed: () => NotificationFeedState(
          status: NotificationFeedStatus.loaded,
          notifications: [_actorNotif(id: 'existing')],
        ),
        act: (bloc) => bloc.add(
          NotificationFeedRealtimeReceived(_rawRelay()),
        ),
        expect: () => [
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            notifications: [
              _videoNotif(id: 'realtime'),
              _actorNotif(id: 'existing'),
            ],
            unreadCount: 1,
          ),
        ],
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'merges actor into existing matching VideoNotification group',
        setUp: () {
          when(
            () => mockNotificationRepo.enrichOne(any()),
          ).thenAnswer(
            (_) async => _videoNotif(
              id: 'newest',
              actors: [_actor(pubkey: _bobPubkey, displayName: 'Bob')],
              timestamp: DateTime(2026, 5, 4, 13),
            ),
          );
        },
        build: createBloc,
        seed: () => NotificationFeedState(
          status: NotificationFeedStatus.loaded,
          notifications: [_videoNotif(id: 'existing')],
        ),
        act: (bloc) => bloc.add(
          NotificationFeedRealtimeReceived(_rawRelay()),
        ),
        verify: (_) {},
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'does NOT emit when enrichOne returns null',
        setUp: () {
          when(
            () => mockNotificationRepo.enrichOne(any()),
          ).thenAnswer((_) async => null);
        },
        build: createBloc,
        seed: () => NotificationFeedState(
          status: NotificationFeedStatus.loaded,
        ),
        act: (bloc) => bloc.add(
          NotificationFeedRealtimeReceived(_rawRelay()),
        ),
        expect: () => <NotificationFeedState>[],
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'deduplicates by ID — skips if enriched.id already present',
        setUp: () {
          when(
            () => mockNotificationRepo.enrichOne(any()),
          ).thenAnswer((_) async => _videoNotif(id: 'existing'));
        },
        build: createBloc,
        seed: () => NotificationFeedState(
          status: NotificationFeedStatus.loaded,
          notifications: [_videoNotif(id: 'existing')],
          unreadCount: 1,
        ),
        act: (bloc) => bloc.add(
          NotificationFeedRealtimeReceived(_rawRelay()),
        ),
        expect: () => <NotificationFeedState>[],
      );

      test(
        'merges into existing video group: actors length 2, totalCount 2',
        () async {
          when(
            () => mockNotificationRepo.enrichOne(any()),
          ).thenAnswer(
            (_) async => _videoNotif(
              id: 'newest',
              actors: [_actor(pubkey: _bobPubkey, displayName: 'Bob')],
              timestamp: DateTime(2026, 5, 4, 13),
            ),
          );

          final bloc = createBloc();
          bloc.emit(
            NotificationFeedState(
              status: NotificationFeedStatus.loaded,
              notifications: [_videoNotif(id: 'existing')],
            ),
          );

          bloc.add(NotificationFeedRealtimeReceived(_rawRelay()));
          await Future<void>.delayed(Duration.zero);

          final merged = bloc.state.notifications.single as VideoNotification;
          expect(merged.actors, hasLength(2));
          expect(merged.actors.first.pubkey, equals(_bobPubkey));
          expect(merged.totalCount, equals(2));
          expect(merged.isRead, isFalse);
          expect(bloc.state.unreadCount, equals(1));

          await bloc.close();
        },
      );
    });

    group('NotificationFeedItemTapped', () {
      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'marks $VideoNotification as read locally and decrements unread',
        setUp: () {
          when(
            () => mockNotificationRepo.markAsRead(any()),
          ).thenAnswer((_) async {});
        },
        build: createBloc,
        seed: () => NotificationFeedState(
          status: NotificationFeedStatus.loaded,
          notifications: [_videoNotif()],
          unreadCount: 1,
        ),
        act: (bloc) => bloc.add(NotificationFeedItemTapped('v1')),
        expect: () => [
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            notifications: [_videoNotif(isRead: true)],
          ),
        ],
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'marks $ActorNotification as read locally and decrements unread',
        setUp: () {
          when(
            () => mockNotificationRepo.markAsRead(any()),
          ).thenAnswer((_) async {});
        },
        build: createBloc,
        seed: () => NotificationFeedState(
          status: NotificationFeedStatus.loaded,
          notifications: [_actorNotif()],
          unreadCount: 1,
        ),
        act: (bloc) => bloc.add(NotificationFeedItemTapped('a1')),
        expect: () => [
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            notifications: [_actorNotif(isRead: true)],
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
          notifications: [_videoNotif()],
          unreadCount: 5,
        ),
        act: (bloc) => bloc.add(NotificationFeedMarkAllRead()),
        expect: () => [
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            notifications: [_videoNotif()],
          ),
        ],
      );
    });

    group('NotificationFeedFollowBack', () {
      final followNotif = _actorNotif(
        id: 'follow1',
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
  });
}
