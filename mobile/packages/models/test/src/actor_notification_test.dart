import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group(ActorNotification, () {
    final actor = ActorInfo(pubkey: 'a' * 64, displayName: 'Alice');
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

      test('exposes targetEventId for likeComment', () {
        final notification = ActorNotification(
          id: 'n1',
          type: NotificationKind.likeComment,
          actor: actor,
          timestamp: timestamp,
          targetEventId: 'b' * 64,
        );

        expect(notification.targetEventId, equals('b' * 64));
      });

      test('accepts reply as an actor-anchored kind', () {
        // Should not throw the assert.
        ActorNotification(
          id: 'n1',
          type: NotificationKind.reply,
          actor: actor,
          timestamp: timestamp,
          targetEventId: 'd' * 64,
        );
      });

      test('videoAddressableId defaults to null', () {
        final notification = ActorNotification(
          id: 'n1',
          type: NotificationKind.likeComment,
          actor: actor,
          timestamp: timestamp,
        );

        expect(notification.videoAddressableId, isNull);
      });

      test('exposes videoAddressableId when set on likeComment', () {
        final addressableId = '34236:${'a' * 64}:vine-abc';
        final notification = ActorNotification(
          id: 'n1',
          type: NotificationKind.likeComment,
          actor: actor,
          timestamp: timestamp,
          videoAddressableId: addressableId,
        );

        expect(notification.videoAddressableId, equals(addressableId));
      });

      test('unequal when videoAddressableId differs', () {
        final a = ActorNotification(
          id: 'n1',
          type: NotificationKind.likeComment,
          actor: actor,
          timestamp: timestamp,
        );
        final b = ActorNotification(
          id: 'n1',
          type: NotificationKind.likeComment,
          actor: actor,
          timestamp: timestamp,
          videoAddressableId: '34236:${'a' * 64}:vine-abc',
        );

        expect(a, isNot(equals(b)));
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

      test('preserves targetEventId when not overridden', () {
        final original = ActorNotification(
          id: 'n1',
          type: NotificationKind.likeComment,
          actor: actor,
          timestamp: timestamp,
          targetEventId: 'c' * 64,
        );

        final updated = original.copyWith(isRead: true);

        expect(updated.targetEventId, equals('c' * 64));
      });

      test('preserves videoAddressableId when not overridden', () {
        final addressableId = '34236:${'b' * 64}:vine-xyz';
        final original = ActorNotification(
          id: 'n1',
          type: NotificationKind.likeComment,
          actor: actor,
          timestamp: timestamp,
          videoAddressableId: addressableId,
        );

        final updated = original.copyWith(isRead: true);

        expect(updated.videoAddressableId, equals(addressableId));
      });

      test('updates videoAddressableId when overridden', () {
        final initial = '34236:${'b' * 64}:vine-old';
        final updated = '34236:${'b' * 64}:vine-new';
        final original = ActorNotification(
          id: 'n1',
          type: NotificationKind.likeComment,
          actor: actor,
          timestamp: timestamp,
          videoAddressableId: initial,
        );

        final copy = original.copyWith(videoAddressableId: updated);

        expect(copy.videoAddressableId, equals(updated));
        expect(original.videoAddressableId, equals(initial));
      });
    });

    group('sourceEventIds (#4264)', () {
      test('defaults to const [] when not provided', () {
        final notification = ActorNotification(
          id: 'n1',
          type: NotificationKind.follow,
          actor: actor,
          timestamp: timestamp,
        );

        expect(notification.sourceEventIds, isEmpty);
      });

      test('round-trips through copyWith', () {
        final original = ActorNotification(
          id: 'n1',
          type: NotificationKind.follow,
          actor: actor,
          timestamp: timestamp,
        );

        final updated = original.copyWith(
          sourceEventIds: const ['nostr-follow-evt-1'],
        );

        expect(updated.sourceEventIds, equals(<String>['nostr-follow-evt-1']));
      });

      test('two otherwise-equal items differ by sourceEventIds', () {
        final a = ActorNotification(
          id: 'n1',
          type: NotificationKind.follow,
          actor: actor,
          timestamp: timestamp,
          sourceEventIds: const ['evt-a'],
        );
        final b = ActorNotification(
          id: 'n1',
          type: NotificationKind.follow,
          actor: actor,
          timestamp: timestamp,
          sourceEventIds: const ['evt-b'],
        );

        expect(a, isNot(equals(b)));
      });
    });

    group('notificationIds', () {
      test('defaults to const [] when not provided', () {
        final notification = ActorNotification(
          id: 'n1',
          type: NotificationKind.follow,
          actor: actor,
          timestamp: timestamp,
        );

        expect(notification.notificationIds, isEmpty);
      });

      test('round-trips through copyWith', () {
        final original = ActorNotification(
          id: 'n1',
          type: NotificationKind.follow,
          actor: actor,
          timestamp: timestamp,
        );

        final updated = original.copyWith(
          notificationIds: const ['notif-follow-1'],
        );

        expect(updated.notificationIds, equals(<String>['notif-follow-1']));
      });

      test('two otherwise-equal items differ by notificationIds', () {
        final a = ActorNotification(
          id: 'n1',
          type: NotificationKind.follow,
          actor: actor,
          timestamp: timestamp,
          notificationIds: const ['notif-a'],
        );
        final b = ActorNotification(
          id: 'n1',
          type: NotificationKind.follow,
          actor: actor,
          timestamp: timestamp,
          notificationIds: const ['notif-b'],
        );

        expect(a, isNot(equals(b)));
      });
    });
  });
}
