// ABOUTME: Tests for NotificationFeedBloc — the bloc is now a thin
// ABOUTME: projection of NotificationRepository.watchSnapshot(); event
// ABOUTME: handlers forward to the repository. Per-row state / unread
// ABOUTME: rollback semantics are tested at the repository layer.

// ignore_for_file: prefer_const_constructors, avoid_redundant_argument_values

import 'dart:async';

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

void main() {
  group(NotificationFeedBloc, () {
    late _MockNotificationRepository mockNotificationRepo;
    late _MockFollowRepository mockFollowRepo;
    late StreamController<NotificationPage> snapshotController;

    setUp(() {
      mockNotificationRepo = _MockNotificationRepository();
      mockFollowRepo = _MockFollowRepository();
      snapshotController = StreamController<NotificationPage>.broadcast();

      when(() => mockFollowRepo.isFollowing(any())).thenReturn(false);
      when(
        () => mockNotificationRepo.watchSnapshot(),
      ).thenAnswer((_) => snapshotController.stream);
      when(() => mockNotificationRepo.refresh()).thenAnswer(
        (_) async => NotificationPage.empty,
      );
      when(() => mockNotificationRepo.getNotifications()).thenAnswer(
        (_) async => NotificationPage.empty,
      );
      when(
        () => mockNotificationRepo.markAsRead(any()),
      ).thenAnswer((_) async {});
      when(() => mockNotificationRepo.markAllAsRead()).thenAnswer((_) async {});
    });

    tearDown(() async {
      await snapshotController.close();
    });

    NotificationFeedBloc createBloc() => NotificationFeedBloc(
      notificationRepository: mockNotificationRepo,
      followRepository: mockFollowRepo,
    );

    group('snapshot projection', () {
      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'projects watchSnapshot emissions into state',
        build: createBloc,
        act: (_) async {
          snapshotController.add(
            NotificationPage(
              items: [_videoNotif()],
              unreadCount: 1,
              hasMore: true,
            ),
          );
          await Future<void>.delayed(Duration.zero);
        },
        expect: () => [
          NotificationFeedState(
            notifications: [_videoNotif()],
            unreadCount: 1,
            hasMore: true,
          ),
        ],
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'overrides isFollowingBack from FollowRepository on each emission',
        setUp: () {
          when(() => mockFollowRepo.isFollowing(_alicePubkey)).thenReturn(true);
        },
        build: createBloc,
        act: (_) async {
          snapshotController.add(
            NotificationPage(
              items: [_actorNotif()],
              unreadCount: 1,
            ),
          );
          await Future<void>.delayed(Duration.zero);
        },
        expect: () => [
          NotificationFeedState(
            notifications: [_actorNotif(isFollowingBack: true)],
            unreadCount: 1,
            hasMore: false,
          ),
        ],
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'leaves non-follow ActorNotifications untouched',
        setUp: () {
          when(() => mockFollowRepo.isFollowing(any())).thenReturn(true);
        },
        build: createBloc,
        act: (_) async {
          snapshotController.add(
            NotificationPage(
              items: [_actorNotif(type: NotificationKind.mention)],
              unreadCount: 1,
            ),
          );
          await Future<void>.delayed(Duration.zero);
        },
        expect: () => [
          NotificationFeedState(
            notifications: [_actorNotif(type: NotificationKind.mention)],
            unreadCount: 1,
            hasMore: false,
          ),
        ],
      );
    });

    group('NotificationFeedStarted', () {
      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'emits loading then loaded; calls refresh then markAllAsRead',
        build: createBloc,
        act: (bloc) => bloc.add(NotificationFeedStarted()),
        expect: () => [
          NotificationFeedState(status: NotificationFeedStatus.loading),
          NotificationFeedState(status: NotificationFeedStatus.loaded),
        ],
        verify: (_) {
          verifyInOrder([
            () => mockNotificationRepo.refresh(),
            () => mockNotificationRepo.markAllAsRead(),
          ]);
        },
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'emits failure when refresh throws',
        setUp: () {
          when(
            () => mockNotificationRepo.refresh(),
          ).thenThrow(Exception('boom'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(NotificationFeedStarted()),
        expect: () => [
          NotificationFeedState(status: NotificationFeedStatus.loading),
          NotificationFeedState(status: NotificationFeedStatus.failure),
        ],
        errors: () => [isA<Exception>()],
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'stays loaded when refresh succeeds but markAllAsRead throws',
        setUp: () {
          when(
            () => mockNotificationRepo.markAllAsRead(),
          ).thenThrow(Exception('mark-all-failed'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(NotificationFeedStarted()),
        expect: () => [
          NotificationFeedState(status: NotificationFeedStatus.loading),
          NotificationFeedState(status: NotificationFeedStatus.loaded),
        ],
        errors: () => [isA<Exception>()],
        verify: (_) {
          verifyInOrder([
            () => mockNotificationRepo.refresh(),
            () => mockNotificationRepo.markAllAsRead(),
          ]);
        },
      );
    });

    group('NotificationFeedLoadMore', () {
      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'no-op when hasMore is false',
        build: createBloc,
        seed: () => NotificationFeedState(
          status: NotificationFeedStatus.loaded,
          hasMore: false,
        ),
        act: (bloc) => bloc.add(NotificationFeedLoadMore()),
        expect: () => <NotificationFeedState>[],
        verify: (_) {
          verifyNever(() => mockNotificationRepo.getNotifications());
        },
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'flips isLoadingMore on/off and forwards to getNotifications',
        build: createBloc,
        seed: () => NotificationFeedState(
          status: NotificationFeedStatus.loaded,
          hasMore: true,
        ),
        act: (bloc) => bloc.add(NotificationFeedLoadMore()),
        expect: () => [
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            hasMore: true,
            isLoadingMore: true,
          ),
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            hasMore: true,
          ),
        ],
        verify: (_) {
          verify(() => mockNotificationRepo.getNotifications()).called(1);
        },
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'recovers isLoadingMore on getNotifications failure',
        setUp: () {
          when(
            () => mockNotificationRepo.getNotifications(),
          ).thenThrow(Exception('boom'));
        },
        build: createBloc,
        seed: () => NotificationFeedState(
          status: NotificationFeedStatus.loaded,
          hasMore: true,
        ),
        act: (bloc) => bloc.add(NotificationFeedLoadMore()),
        expect: () => [
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            hasMore: true,
            isLoadingMore: true,
          ),
          NotificationFeedState(
            status: NotificationFeedStatus.loaded,
            hasMore: true,
          ),
        ],
        errors: () => [isA<Exception>()],
      );
    });

    group('NotificationFeedRefreshed', () {
      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'calls refresh and emits loaded',
        build: createBloc,
        seed: () => NotificationFeedState(
          status: NotificationFeedStatus.failure,
        ),
        act: (bloc) => bloc.add(NotificationFeedRefreshed()),
        expect: () => [
          NotificationFeedState(status: NotificationFeedStatus.loaded),
        ],
        verify: (_) {
          verify(() => mockNotificationRepo.refresh()).called(1);
        },
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'emits failure when refresh throws',
        setUp: () {
          when(
            () => mockNotificationRepo.refresh(),
          ).thenThrow(Exception('boom'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(NotificationFeedRefreshed()),
        expect: () => [
          NotificationFeedState(status: NotificationFeedStatus.failure),
        ],
        errors: () => [isA<Exception>()],
      );
    });

    group('NotificationFeedItemTapped', () {
      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'forwards to repository.markAsRead',
        build: createBloc,
        act: (bloc) => bloc.add(NotificationFeedItemTapped('v1')),
        verify: (_) {
          verify(() => mockNotificationRepo.markAsRead(['v1'])).called(1);
        },
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'forwards repository errors via addError',
        setUp: () {
          when(
            () => mockNotificationRepo.markAsRead(any()),
          ).thenThrow(Exception('boom'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(NotificationFeedItemTapped('v1')),
        errors: () => [isA<Exception>()],
      );
    });

    group('NotificationFeedMarkAllRead', () {
      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'forwards to repository.markAllAsRead',
        build: createBloc,
        act: (bloc) => bloc.add(NotificationFeedMarkAllRead()),
        verify: (_) {
          verify(() => mockNotificationRepo.markAllAsRead()).called(1);
        },
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'forwards repository errors via addError',
        setUp: () {
          when(
            () => mockNotificationRepo.markAllAsRead(),
          ).thenThrow(Exception('boom'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(NotificationFeedMarkAllRead()),
        errors: () => [isA<Exception>()],
      );
    });

    group('NotificationFeedFollowBack', () {
      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'follows the user and re-derives follow state on existing items',
        setUp: () {
          when(
            () => mockFollowRepo.follow(_bobPubkey),
          ).thenAnswer((_) async {});
          when(() => mockFollowRepo.isFollowing(_bobPubkey)).thenReturn(true);
        },
        build: createBloc,
        seed: () => NotificationFeedState(
          notifications: [
            _actorNotif(id: 'f1', pubkey: _bobPubkey, displayName: 'Bob'),
          ],
        ),
        act: (bloc) => bloc.add(NotificationFeedFollowBack(_bobPubkey)),
        expect: () => [
          NotificationFeedState(
            notifications: [
              _actorNotif(
                id: 'f1',
                pubkey: _bobPubkey,
                displayName: 'Bob',
                isFollowingBack: true,
              ),
            ],
          ),
        ],
      );

      blocTest<NotificationFeedBloc, NotificationFeedState>(
        'forwards follow errors via addError',
        setUp: () {
          when(
            () => mockFollowRepo.follow(_bobPubkey),
          ).thenThrow(Exception('boom'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(NotificationFeedFollowBack(_bobPubkey)),
        errors: () => [isA<Exception>()],
      );
    });
  });
}
