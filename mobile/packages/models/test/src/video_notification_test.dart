import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group(VideoNotification, () {
    final actorAlice = ActorInfo(pubkey: 'a' * 64, displayName: 'Alice');
    final actorBob = ActorInfo(pubkey: 'b' * 64, displayName: 'Bob');
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

      test('exposes optional commentText for comment kind', () {
        // Comment notifications carry an excerpt of the most recent
        // comment so the row can quote it under the message text.
        final notification = VideoNotification(
          id: 'n1',
          type: NotificationKind.comment,
          videoEventId: 'v1',
          actors: [actorAlice],
          totalCount: 1,
          timestamp: timestamp,
          commentText: 'Loved this clip!',
        );

        expect(notification.commentText, equals('Loved this clip!'));
      });

      test('commentText defaults to null when not set', () {
        final notification = VideoNotification(
          id: 'n1',
          type: NotificationKind.like,
          videoEventId: 'v1',
          actors: [actorAlice],
          totalCount: 1,
          timestamp: timestamp,
        );

        expect(notification.commentText, isNull);
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

      test('preserves commentText when not overridden', () {
        final original = VideoNotification(
          id: 'n1',
          type: NotificationKind.comment,
          videoEventId: 'v1',
          actors: [actorAlice],
          totalCount: 1,
          timestamp: timestamp,
          commentText: 'Original comment',
        );

        final updated = original.copyWith(isRead: true);

        expect(updated.commentText, equals('Original comment'));
      });
    });

    group('sourceEventIds (#4264)', () {
      test('defaults to const [] when not provided', () {
        final notification = VideoNotification(
          id: 'n1',
          type: NotificationKind.like,
          videoEventId: 'v1',
          actors: [actorAlice],
          totalCount: 1,
          timestamp: timestamp,
        );

        expect(notification.sourceEventIds, isEmpty);
      });

      test('round-trips through copyWith', () {
        final original = VideoNotification(
          id: 'n1',
          type: NotificationKind.like,
          videoEventId: 'v1',
          actors: [actorAlice],
          totalCount: 1,
          timestamp: timestamp,
        );

        final updated = original.copyWith(
          sourceEventIds: const ['nostr-evt-1', 'nostr-evt-2'],
        );

        expect(
          updated.sourceEventIds,
          equals(<String>['nostr-evt-1', 'nostr-evt-2']),
        );
      });

      test('two otherwise-equal items differ by sourceEventIds', () {
        final a = VideoNotification(
          id: 'n1',
          type: NotificationKind.like,
          videoEventId: 'v1',
          actors: [actorAlice],
          totalCount: 1,
          timestamp: timestamp,
          sourceEventIds: const ['evt-a'],
        );
        final b = VideoNotification(
          id: 'n1',
          type: NotificationKind.like,
          videoEventId: 'v1',
          actors: [actorAlice],
          totalCount: 1,
          timestamp: timestamp,
          sourceEventIds: const ['evt-b'],
        );

        expect(a, isNot(equals(b)));
      });
    });
  });
}
