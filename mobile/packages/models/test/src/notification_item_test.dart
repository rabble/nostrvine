import 'package:models/models.dart';
import 'package:test/test.dart';

// 64-char hex pubkeys for tests.
const _pubkeyAlice =
    'aabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccdd';
const _pubkeyBob =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _pubkeyCarol =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _eventId =
    '1122334411223344112233441122334411223344112233441122334411223344';

const _testActor = ActorInfo(
  pubkey: _pubkeyAlice,
  displayName: 'alice_rebel',
  pictureUrl: 'https://example.com/alice.jpg',
);

void main() {
  group('SingleNotification', () {
    test('creates like notification', () {
      final notification = SingleNotification(
        id: 'notif_1',
        type: NotificationKind.like,
        actor: _testActor,
        timestamp: DateTime(2026, 4, 6),
        targetEventId: _eventId,
        videoTitle: 'Best Post Ever',
      );

      expect(notification.type, equals(NotificationKind.like));
      expect(notification.actor.displayName, equals('alice_rebel'));
      expect(notification.videoTitle, equals('Best Post Ever'));
    });

    test('creates comment notification with text', () {
      final notification = SingleNotification(
        id: 'notif_2',
        type: NotificationKind.comment,
        actor: _testActor,
        timestamp: DateTime(2026, 4, 6),
        targetEventId: _eventId,
        videoTitle: 'Best Post Ever',
        commentText: "It's the power of Nostr in full effect. Let's go!",
      );

      expect(notification.commentText, isNotNull);
    });

    test('creates follow notification with followBack flag', () {
      final notification = SingleNotification(
        id: 'notif_3',
        type: NotificationKind.follow,
        actor: _testActor,
        timestamp: DateTime(2026, 4, 6),
      );

      expect(notification.isFollowingBack, isFalse);
      expect(notification.targetEventId, isNull);
      expect(notification.videoTitle, isNull);
    });

    test('every NotificationKind round-trips through the constructor', () {
      for (final kind in NotificationKind.values) {
        final notification = SingleNotification(
          id: 'notif_${kind.name}',
          type: kind,
          actor: _testActor,
          timestamp: DateTime(2026, 4, 6),
        );

        expect(notification.type, equals(kind));
        expect(notification.actor, equals(_testActor));
      }
    });

    test('isRead defaults to false', () {
      final notification = SingleNotification(
        id: 'notif_1',
        type: NotificationKind.like,
        actor: _testActor,
        timestamp: DateTime(2026, 4, 6),
      );

      expect(notification.isRead, isFalse);
    });

    test('copyWith replaces fields', () {
      final original = SingleNotification(
        id: 'notif_1',
        type: NotificationKind.like,
        actor: _testActor,
        timestamp: DateTime(2026, 4, 6),
      );

      final updated = original.copyWith(isRead: true);

      expect(updated.isRead, isTrue);
      expect(updated.id, equals('notif_1'));
      expect(updated.actor, equals(_testActor));
    });

    test('copyWith preserves fields when null', () {
      final original = SingleNotification(
        id: 'notif_1',
        type: NotificationKind.like,
        actor: _testActor,
        timestamp: DateTime(2026, 4, 6),
        videoTitle: 'My Video',
        commentText: 'Great!',
        isFollowingBack: true,
      );

      final updated = original.copyWith();

      expect(updated, equals(original));
    });

    test('equality works', () {
      final a = SingleNotification(
        id: 'notif_1',
        type: NotificationKind.like,
        actor: _testActor,
        timestamp: DateTime(2026, 4, 6),
      );
      final b = SingleNotification(
        id: 'notif_1',
        type: NotificationKind.like,
        actor: _testActor,
        timestamp: DateTime(2026, 4, 6),
      );

      expect(a, equals(b));
    });
  });

  group('GroupedNotification', () {
    test('creates grouped like notification', () {
      const actors = [
        ActorInfo(pubkey: _pubkeyAlice, displayName: 'alice'),
        ActorInfo(pubkey: _pubkeyBob, displayName: 'bob'),
        ActorInfo(pubkey: _pubkeyCarol, displayName: 'carol'),
      ];

      final notification = GroupedNotification(
        id: 'group_1',
        type: NotificationKind.like,
        actors: actors,
        totalCount: 94,
        timestamp: DateTime(2026, 4, 6),
        targetEventId: _eventId,
        videoTitle: 'Best Post Ever',
      );

      expect(notification.actors, hasLength(3));
      expect(notification.totalCount, equals(94));
      expect(notification.videoTitle, equals('Best Post Ever'));
    });

    test('preserves an empty actors list with zero totalCount', () {
      final notification = GroupedNotification(
        id: 'group_1',
        type: NotificationKind.like,
        actors: const [],
        totalCount: 0,
        timestamp: DateTime(2026, 4, 6),
      );

      expect(notification.actors, isEmpty);
      expect(notification.totalCount, equals(0));
    });

    test('equality works', () {
      const actors = [
        ActorInfo(pubkey: _pubkeyAlice, displayName: 'alice'),
      ];

      final a = GroupedNotification(
        id: 'group_1',
        type: NotificationKind.like,
        actors: actors,
        totalCount: 94,
        timestamp: DateTime(2026, 4, 6),
      );
      final b = GroupedNotification(
        id: 'group_1',
        type: NotificationKind.like,
        actors: actors,
        totalCount: 94,
        timestamp: DateTime(2026, 4, 6),
      );

      expect(a, equals(b));
    });

    test('copyWith updates only the specified fields', () {
      const originalActors = [
        ActorInfo(pubkey: _pubkeyAlice, displayName: 'alice'),
      ];
      const newActors = [
        ActorInfo(pubkey: _pubkeyBob, displayName: 'bob'),
        ActorInfo(pubkey: _pubkeyCarol, displayName: 'carol'),
      ];

      final original = GroupedNotification(
        id: 'group_1',
        type: NotificationKind.like,
        actors: originalActors,
        totalCount: 1,
        timestamp: DateTime(2026, 4, 6),
        targetEventId: _eventId,
        videoTitle: 'My Video',
      );

      final updated = original.copyWith(
        isRead: true,
        actors: newActors,
        totalCount: 2,
      );

      expect(updated.isRead, isTrue);
      expect(updated.actors, equals(newActors));
      expect(updated.totalCount, equals(2));
      // Untouched fields stay the same.
      expect(updated.id, equals(original.id));
      expect(updated.type, equals(original.type));
      expect(updated.timestamp, equals(original.timestamp));
      expect(updated.targetEventId, equals(original.targetEventId));
      expect(updated.videoTitle, equals(original.videoTitle));
    });

    test('copyWith with no arguments returns an equal instance', () {
      final original = GroupedNotification(
        id: 'group_1',
        type: NotificationKind.like,
        actors: const [
          ActorInfo(pubkey: _pubkeyAlice, displayName: 'alice'),
        ],
        totalCount: 1,
        timestamp: DateTime(2026, 4, 6),
      );

      expect(original.copyWith(), equals(original));
    });
  });

  group('pattern matching', () {
    test('exhaustive switch on SingleNotification', () {
      final NotificationItem item = SingleNotification(
        id: 'notif_1',
        type: NotificationKind.like,
        actor: _testActor,
        timestamp: DateTime(2026, 4, 6),
      );

      final result = switch (item) {
        SingleNotification(:final actor) => actor.displayName,
        GroupedNotification(:final totalCount) => '$totalCount',
      };

      expect(result, equals('alice_rebel'));
    });

    test('exhaustive switch on GroupedNotification', () {
      final NotificationItem item = GroupedNotification(
        id: 'group_1',
        type: NotificationKind.like,
        actors: const [
          ActorInfo(pubkey: _pubkeyAlice, displayName: 'alice'),
        ],
        totalCount: 42,
        timestamp: DateTime(2026, 4, 6),
      );

      final result = switch (item) {
        SingleNotification(:final actor) => actor.displayName,
        GroupedNotification(:final totalCount) => '$totalCount',
      };

      expect(result, equals('42'));
    });
  });
}
