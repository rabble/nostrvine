// ABOUTME: Pins the contract that acceptRealtime applies the blockFilter to
// ABOUTME: WebSocket arrivals so blocked actors never reach the snapshot.

import 'package:db_client/db_client.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:test/test.dart';

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockNotificationsDao extends Mock implements NotificationsDao {}

void main() {
  late _MockFunnelcakeApiClient funnelcakeApiClient;
  late _MockProfileRepository profileRepository;
  late _MockNotificationsDao notificationsDao;

  const userPubkey = 'user1234567890abcdef';
  const blockedPubkey = 'blocked_actor_pub';
  const allowedPubkey = 'allowed_actor_pub';

  setUpAll(() {
    registerFallbackValue(<NotificationCacheRow>[]);
  });

  setUp(() {
    funnelcakeApiClient = _MockFunnelcakeApiClient();
    profileRepository = _MockProfileRepository();
    notificationsDao = _MockNotificationsDao();
    when(
      () => funnelcakeApiClient.getVideoStats(any()),
    ).thenThrow(const FunnelcakeException('no stats'));
    when(
      () => notificationsDao.getAllNotifications(limit: any(named: 'limit')),
    ).thenAnswer((_) async => <NotificationRow>[]);
    when(() => notificationsDao.replaceAll(any())).thenAnswer((_) async {});
  });

  /// Default helper — like notification from [sourcePubkey].
  RelayNotification makeNotification({
    String id = 'n1',
    String sourcePubkey = allowedPubkey,
    String sourceEventId = 'evt1',
    int sourceKind = 7,
    String notificationType = 'reaction',
    String? referencedEventId = 'video_default',
    bool isReferencedVideo = true,
    String? content,
  }) {
    return RelayNotification(
      id: id,
      sourcePubkey: sourcePubkey,
      sourceEventId: sourceEventId,
      sourceKind: sourceKind,
      notificationType: notificationType,
      createdAt: DateTime(2025),
      read: false,
      referencedEventId: referencedEventId,
      content: content,
      isReferencedVideo: isReferencedVideo,
    );
  }

  void stubProfiles(Map<String, UserProfile> profiles) {
    when(
      () =>
          profileRepository.fetchBatchProfiles(pubkeys: any(named: 'pubkeys')),
    ).thenAnswer((_) async => profiles);
  }

  UserProfile makeProfile(String pubkey, {String? displayName}) {
    return UserProfile(
      pubkey: pubkey,
      rawData: const {},
      createdAt: DateTime(2024),
      eventId: 'evt_$pubkey',
      displayName: displayName,
    );
  }

  NotificationRepository buildRepository({
    required BlockedNotificationFilter blockFilter,
  }) {
    return NotificationRepository(
      funnelcakeApiClient: funnelcakeApiClient,
      profileRepository: profileRepository,
      notificationsDao: notificationsDao,
      userPubkey: userPubkey,
      blockFilter: blockFilter,
      hydrateOnStart: false,
    );
  }

  group('NotificationRepository acceptRealtime + blockFilter', () {
    test('drops a video-anchored notification from a blocked actor', () async {
      final repository = buildRepository(
        blockFilter: (pubkey) => pubkey == blockedPubkey,
      );
      stubProfiles({
        blockedPubkey: makeProfile(blockedPubkey, displayName: 'Blocked'),
      });

      await repository.acceptRealtime(
        makeNotification(sourcePubkey: blockedPubkey),
      );

      final snapshot = await repository.watchSnapshot().first;
      expect(snapshot.items, isEmpty);
      expect(await repository.watchUnreadCount().first, equals(0));
    });

    test(
      'drops a comment notification from a blocked actor',
      () async {
        final repository = buildRepository(
          blockFilter: (pubkey) => pubkey == blockedPubkey,
        );
        stubProfiles({
          blockedPubkey: makeProfile(blockedPubkey, displayName: 'Blocked'),
        });

        await repository.acceptRealtime(
          makeNotification(
            sourcePubkey: blockedPubkey,
            notificationType: 'comment',
            sourceKind: 1,
            content: 'spam comment',
          ),
        );

        final snapshot = await repository.watchSnapshot().first;
        expect(snapshot.items, isEmpty);
      },
    );

    test(
      'drops an actor-anchored follow notification from a blocked actor',
      () async {
        final repository = buildRepository(
          blockFilter: (pubkey) => pubkey == blockedPubkey,
        );
        stubProfiles({
          blockedPubkey: makeProfile(blockedPubkey, displayName: 'Blocked'),
        });

        await repository.acceptRealtime(
          makeNotification(
            sourcePubkey: blockedPubkey,
            notificationType: 'follow',
            sourceKind: 3,
            referencedEventId: null,
            isReferencedVideo: false,
          ),
        );

        final snapshot = await repository.watchSnapshot().first;
        expect(snapshot.items, isEmpty);
      },
    );

    test('keeps a realtime notification from a non-blocked actor', () async {
      final repository = buildRepository(
        blockFilter: (pubkey) => pubkey == blockedPubkey,
      );
      stubProfiles({
        allowedPubkey: makeProfile(allowedPubkey, displayName: 'Allowed'),
      });

      await repository.acceptRealtime(makeNotification());

      final snapshot = await repository.watchSnapshot().first;
      expect(snapshot.items, hasLength(1));
      expect(await repository.watchUnreadCount().first, equals(1));
    });

    test(
      'strips blocked actors from a multi-actor video group on merge',
      () async {
        final repository = buildRepository(
          blockFilter: (pubkey) => pubkey == blockedPubkey,
        );
        stubProfiles({
          allowedPubkey: makeProfile(allowedPubkey, displayName: 'Allowed'),
          blockedPubkey: makeProfile(blockedPubkey, displayName: 'Blocked'),
        });

        // Allowed actor lands first.
        await repository.acceptRealtime(makeNotification());
        // Blocked actor on the same (referencedEventId, kind) — would merge
        // into the existing VideoNotification group if not filtered.
        await repository.acceptRealtime(
          makeNotification(id: 'n2', sourcePubkey: blockedPubkey),
        );

        final snapshot = await repository.watchSnapshot().first;
        expect(snapshot.items, hasLength(1));
        final group = snapshot.items.single as VideoNotification;
        expect(
          group.actors.map((a) => a.pubkey),
          contains(allowedPubkey),
          reason: 'allowed actor must remain in the group',
        );
        expect(
          group.actors.map((a) => a.pubkey),
          isNot(contains(blockedPubkey)),
          reason: 'blocked actor must never reach the snapshot',
        );
      },
    );

    test('with no blockFilter, realtime notifications pass through', () async {
      final repository = NotificationRepository(
        funnelcakeApiClient: funnelcakeApiClient,
        profileRepository: profileRepository,
        notificationsDao: notificationsDao,
        userPubkey: userPubkey,
        hydrateOnStart: false,
      );
      stubProfiles({
        blockedPubkey: makeProfile(blockedPubkey, displayName: 'Blocked'),
      });

      await repository.acceptRealtime(
        makeNotification(sourcePubkey: blockedPubkey),
      );

      final snapshot = await repository.watchSnapshot().first;
      expect(snapshot.items, hasLength(1));
    });
  });
}
