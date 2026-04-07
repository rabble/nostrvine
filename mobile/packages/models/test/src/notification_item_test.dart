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

    test('message includes video title for like', () {
      final notification = SingleNotification(
        id: 'notif_1',
        type: NotificationKind.like,
        actor: _testActor,
        timestamp: DateTime(2026, 4, 6),
        videoTitle: 'My Video',
      );

      expect(
        notification.message,
        equals('alice_rebel liked your video My Video'),
      );
    });

    test('message without video title for like', () {
      final notification = SingleNotification(
        id: 'notif_1',
        type: NotificationKind.like,
        actor: _testActor,
        timestamp: DateTime(2026, 4, 6),
      );

      expect(notification.message, equals('alice_rebel liked your video'));
    });

    test('message for comment with title', () {
      final notification = SingleNotification(
        id: 'notif_1',
        type: NotificationKind.comment,
        actor: _testActor,
        timestamp: DateTime(2026, 4, 6),
        videoTitle: 'My Video',
      );

      expect(
        notification.message,
        equals('alice_rebel commented on your video My Video'),
      );
    });

    test('message for comment without title', () {
      final notification = SingleNotification(
        id: 'notif_1',
        type: NotificationKind.comment,
        actor: _testActor,
        timestamp: DateTime(2026, 4, 6),
      );

      expect(
        notification.message,
        equals('alice_rebel commented on your video'),
      );
    });

    test('message for reply', () {
      final notification = SingleNotification(
        id: 'notif_1',
        type: NotificationKind.reply,
        actor: _testActor,
        timestamp: DateTime(2026, 4, 6),
      );

      expect(
        notification.message,
        equals('alice_rebel replied to your comment'),
      );
    });

    test('message for follow', () {
      final notification = SingleNotification(
        id: 'notif_1',
        type: NotificationKind.follow,
        actor: _testActor,
        timestamp: DateTime(2026, 4, 6),
      );

      expect(
        notification.message,
        equals('alice_rebel started following you'),
      );
    });

    test('message for repost with title', () {
      final notification = SingleNotification(
        id: 'notif_1',
        type: NotificationKind.repost,
        actor: _testActor,
        timestamp: DateTime(2026, 4, 6),
        videoTitle: 'My Video',
      );

      expect(
        notification.message,
        equals('alice_rebel reposted your video My Video'),
      );
    });

    test('message for repost without title', () {
      final notification = SingleNotification(
        id: 'notif_1',
        type: NotificationKind.repost,
        actor: _testActor,
        timestamp: DateTime(2026, 4, 6),
      );

      expect(
        notification.message,
        equals('alice_rebel reposted your video'),
      );
    });

    test('message for mention', () {
      final notification = SingleNotification(
        id: 'notif_1',
        type: NotificationKind.mention,
        actor: _testActor,
        timestamp: DateTime(2026, 4, 6),
      );

      expect(notification.message, equals('alice_rebel mentioned you'));
    });

    test('message for system', () {
      final notification = SingleNotification(
        id: 'notif_1',
        type: NotificationKind.system,
        actor: _testActor,
        timestamp: DateTime(2026, 4, 6),
      );

      expect(notification.message, equals('You have a new update'));
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

    test('message returns grouped format', () {
      const actors = [
        ActorInfo(pubkey: _pubkeyAlice, displayName: 'alice'),
      ];

      final notification = GroupedNotification(
        id: 'group_1',
        type: NotificationKind.like,
        actors: actors,
        totalCount: 94,
        timestamp: DateTime(2026, 4, 6),
        videoTitle: 'Best Post Ever',
      );

      expect(notification.message, contains('alice'));
      expect(notification.message, contains('93 others'));
      expect(notification.message, contains('Best Post Ever'));
    });

    test('message for single actor group', () {
      const actors = [
        ActorInfo(pubkey: _pubkeyAlice, displayName: 'alice'),
      ];

      final notification = GroupedNotification(
        id: 'group_1',
        type: NotificationKind.like,
        actors: actors,
        totalCount: 1,
        timestamp: DateTime(2026, 4, 6),
        videoTitle: 'My Video',
      );

      expect(
        notification.message,
        equals('alice liked your video My Video'),
      );
    });

    test('message for single actor group without title', () {
      const actors = [
        ActorInfo(pubkey: _pubkeyAlice, displayName: 'alice'),
      ];

      final notification = GroupedNotification(
        id: 'group_1',
        type: NotificationKind.like,
        actors: actors,
        totalCount: 1,
        timestamp: DateTime(2026, 4, 6),
      );

      expect(notification.message, equals('alice liked your video'));
    });

    test('message uses singular other for count of 2', () {
      const actors = [
        ActorInfo(pubkey: _pubkeyAlice, displayName: 'alice'),
        ActorInfo(pubkey: _pubkeyBob, displayName: 'bob'),
      ];

      final notification = GroupedNotification(
        id: 'group_1',
        type: NotificationKind.like,
        actors: actors,
        totalCount: 2,
        timestamp: DateTime(2026, 4, 6),
      );

      expect(notification.message, contains('1 other'));
      expect(notification.message, isNot(contains('others')));
    });

    test('message for empty actors list', () {
      final notification = GroupedNotification(
        id: 'group_1',
        type: NotificationKind.like,
        actors: const [],
        totalCount: 0,
        timestamp: DateTime(2026, 4, 6),
      );

      expect(notification.message, equals('Someone liked your video'));
    });

    test('message without title', () {
      const actors = [
        ActorInfo(pubkey: _pubkeyAlice, displayName: 'alice'),
      ];

      final notification = GroupedNotification(
        id: 'group_1',
        type: NotificationKind.like,
        actors: actors,
        totalCount: 94,
        timestamp: DateTime(2026, 4, 6),
      );

      expect(
        notification.message,
        equals('alice and 93 others liked your video'),
      );
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
