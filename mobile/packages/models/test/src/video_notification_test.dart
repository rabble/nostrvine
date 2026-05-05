import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group(VideoNotification, () {
    final actorAlice = ActorInfo(
      pubkey: 'a' * 64,
      displayName: 'Alice',
    );
    final actorBob = ActorInfo(
      pubkey: 'b' * 64,
      displayName: 'Bob',
    );
    final timestamp = DateTime.utc(2026, 5, 4, 12);

    group('structure', () {
      test('exposes videoEventId, actors, totalCount, type', () {
        final notification = VideoNotification(
          id: 'n1',
          type: NotificationKind.like,
          videoEventId: 'v1',
          actors: [actorAlice],
          totalCount: 1,
          timestamp: timestamp,
        );

        expect(notification.videoEventId, equals('v1'));
        expect(notification.actors.first.displayName, equals('Alice'));
        expect(notification.totalCount, equals(1));
        expect(notification.type, equals(NotificationKind.like));
      });

      test('accepts likeComment as a video-anchored kind', () {
        // Should not throw the assert.
        VideoNotification(
          id: 'n1',
          type: NotificationKind.likeComment,
          videoEventId: 'v1',
          actors: [actorAlice],
          totalCount: 1,
          timestamp: timestamp,
        );
      });
    });

    group('equality', () {
      test('equal when all fields match', () {
        final a = VideoNotification(
          id: 'n1',
          type: NotificationKind.like,
          videoEventId: 'v1',
          videoThumbnailUrl: 'https://t/x.jpg',
          videoTitle: 'Hello',
          actors: [actorAlice],
          totalCount: 1,
          timestamp: timestamp,
        );
        final b = VideoNotification(
          id: 'n1',
          type: NotificationKind.like,
          videoEventId: 'v1',
          videoThumbnailUrl: 'https://t/x.jpg',
          videoTitle: 'Hello',
          actors: [actorAlice],
          totalCount: 1,
          timestamp: timestamp,
        );

        expect(a, equals(b));
      });

      test('unequal when totalCount differs', () {
        final a = VideoNotification(
          id: 'n1',
          type: NotificationKind.like,
          videoEventId: 'v1',
          actors: [actorAlice],
          totalCount: 1,
          timestamp: timestamp,
        );
        final b = VideoNotification(
          id: 'n1',
          type: NotificationKind.like,
          videoEventId: 'v1',
          actors: [actorAlice],
          totalCount: 2,
          timestamp: timestamp,
        );

        expect(a, isNot(equals(b)));
      });
    });

    group('copyWith', () {
      test('overrides only specified fields', () {
        final original = VideoNotification(
          id: 'n1',
          type: NotificationKind.like,
          videoEventId: 'v1',
          actors: [actorAlice],
          totalCount: 1,
          timestamp: timestamp,
        );

        final updated = original.copyWith(
          actors: [actorAlice, actorBob],
          totalCount: 2,
        );

        expect(updated.actors, hasLength(2));
        expect(updated.totalCount, equals(2));
        expect(updated.id, equals(original.id));
        expect(updated.timestamp, equals(original.timestamp));
        expect(updated.videoEventId, equals(original.videoEventId));
      });

      test('preserves isRead when not overridden', () {
        final original = VideoNotification(
          id: 'n1',
          type: NotificationKind.like,
          videoEventId: 'v1',
          actors: [actorAlice],
          totalCount: 1,
          timestamp: timestamp,
          isRead: true,
        );

        final updated = original.copyWith(totalCount: 2);

        expect(updated.isRead, isTrue);
      });
    });
  });
}
