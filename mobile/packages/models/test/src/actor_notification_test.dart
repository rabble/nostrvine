import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group(ActorNotification, () {
    final actor = ActorInfo(
      pubkey: 'a' * 64,
      displayName: 'Alice',
    );
    final timestamp = DateTime.utc(2026, 5, 4, 12);

    group('structure', () {
      test('exposes actor + type + timestamp', () {
        final notification = ActorNotification(
          id: 'n1',
          type: NotificationKind.follow,
          actor: actor,
          timestamp: timestamp,
        );

        expect(notification.actor.displayName, equals('Alice'));
        expect(notification.type, equals(NotificationKind.follow));
        expect(notification.timestamp, equals(timestamp));
        expect(notification.isFollowingBack, isFalse);
      });

      test('accepts likeComment as an actor-anchored kind', () {
        // Should not throw the assert.
        ActorNotification(
          id: 'n1',
          type: NotificationKind.likeComment,
          actor: actor,
          timestamp: timestamp,
        );
      });
    });

    group('equality', () {
      test('equal when all fields match', () {
        final a = ActorNotification(
          id: 'n1',
          type: NotificationKind.follow,
          actor: actor,
          timestamp: timestamp,
        );
        final b = ActorNotification(
          id: 'n1',
          type: NotificationKind.follow,
          actor: actor,
          timestamp: timestamp,
        );

        expect(a, equals(b));
      });

      test('unequal when isFollowingBack differs', () {
        final a = ActorNotification(
          id: 'n1',
          type: NotificationKind.follow,
          actor: actor,
          timestamp: timestamp,
        );
        final b = ActorNotification(
          id: 'n1',
          type: NotificationKind.follow,
          actor: actor,
          timestamp: timestamp,
          isFollowingBack: true,
        );

        expect(a, isNot(equals(b)));
      });
    });

    group('copyWith', () {
      test('toggles isFollowingBack', () {
        final original = ActorNotification(
          id: 'n1',
          type: NotificationKind.follow,
          actor: actor,
          timestamp: timestamp,
        );

        final updated = original.copyWith(isFollowingBack: true);

        expect(updated.isFollowingBack, isTrue);
        expect(original.isFollowingBack, isFalse);
      });

      test('preserves isRead when not overridden', () {
        final original = ActorNotification(
          id: 'n1',
          type: NotificationKind.follow,
          actor: actor,
          timestamp: timestamp,
          isRead: true,
        );

        final updated = original.copyWith(isFollowingBack: true);

        expect(updated.isRead, isTrue);
      });
    });
  });
}
