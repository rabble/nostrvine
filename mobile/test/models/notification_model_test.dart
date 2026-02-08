// ABOUTME: Tests for NotificationModel navigation logic
// ABOUTME: Verifies navigationAction and navigationTarget for all notification types

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/notification_model.dart';

void main() {
  group(NotificationModel, () {
    const actorPubkey =
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
    const targetEventId =
        'f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5d4c3b2a1f6e5';
    final timestamp = DateTime(2025);

    NotificationModel _createNotification({
      required NotificationType type,
      String? eventId,
    }) {
      return NotificationModel(
        id: 'test-id',
        type: type,
        actorPubkey: actorPubkey,
        message: 'test message',
        timestamp: timestamp,
        targetEventId: eventId,
      );
    }

    group('navigationAction', () {
      test('returns open_video for like with targetEventId', () {
        final notification = _createNotification(
          type: NotificationType.like,
          eventId: targetEventId,
        );
        expect(notification.navigationAction, equals('open_video'));
      });

      test('returns open_profile for like without targetEventId', () {
        final notification = _createNotification(type: NotificationType.like);
        expect(notification.navigationAction, equals('open_profile'));
      });

      test('returns open_video for comment with targetEventId', () {
        final notification = _createNotification(
          type: NotificationType.comment,
          eventId: targetEventId,
        );
        expect(notification.navigationAction, equals('open_video'));
      });

      test('returns open_profile for comment without targetEventId', () {
        final notification = _createNotification(
          type: NotificationType.comment,
        );
        expect(notification.navigationAction, equals('open_profile'));
      });

      test('returns open_video for repost with targetEventId', () {
        final notification = _createNotification(
          type: NotificationType.repost,
          eventId: targetEventId,
        );
        expect(notification.navigationAction, equals('open_video'));
      });

      test('returns open_profile for repost without targetEventId', () {
        final notification = _createNotification(type: NotificationType.repost);
        expect(notification.navigationAction, equals('open_profile'));
      });

      test('returns open_profile for follow', () {
        final notification = _createNotification(type: NotificationType.follow);
        expect(notification.navigationAction, equals('open_profile'));
      });

      test('returns open_profile for mention', () {
        final notification = _createNotification(
          type: NotificationType.mention,
        );
        expect(notification.navigationAction, equals('open_profile'));
      });

      test('returns none for system', () {
        final notification = _createNotification(type: NotificationType.system);
        expect(notification.navigationAction, equals('none'));
      });
    });

    group('navigationTarget', () {
      test('returns targetEventId for like with targetEventId', () {
        final notification = _createNotification(
          type: NotificationType.like,
          eventId: targetEventId,
        );
        expect(notification.navigationTarget, equals(targetEventId));
      });

      test('returns actorPubkey for like without targetEventId', () {
        final notification = _createNotification(type: NotificationType.like);
        expect(notification.navigationTarget, equals(actorPubkey));
      });

      test('returns targetEventId for comment with targetEventId', () {
        final notification = _createNotification(
          type: NotificationType.comment,
          eventId: targetEventId,
        );
        expect(notification.navigationTarget, equals(targetEventId));
      });

      test('returns actorPubkey for comment without targetEventId', () {
        final notification = _createNotification(
          type: NotificationType.comment,
        );
        expect(notification.navigationTarget, equals(actorPubkey));
      });

      test('returns targetEventId for repost with targetEventId', () {
        final notification = _createNotification(
          type: NotificationType.repost,
          eventId: targetEventId,
        );
        expect(notification.navigationTarget, equals(targetEventId));
      });

      test('returns actorPubkey for repost without targetEventId', () {
        final notification = _createNotification(type: NotificationType.repost);
        expect(notification.navigationTarget, equals(actorPubkey));
      });

      test('returns actorPubkey for follow', () {
        final notification = _createNotification(type: NotificationType.follow);
        expect(notification.navigationTarget, equals(actorPubkey));
      });

      test('returns actorPubkey for mention', () {
        final notification = _createNotification(
          type: NotificationType.mention,
        );
        expect(notification.navigationTarget, equals(actorPubkey));
      });

      test('returns null for system', () {
        final notification = _createNotification(type: NotificationType.system);
        expect(notification.navigationTarget, isNull);
      });
    });

    group('fromJson / toJson', () {
      test('round-trips correctly', () {
        final notification = NotificationModel(
          id: 'test-id',
          type: NotificationType.like,
          actorPubkey: actorPubkey,
          message: 'Someone liked your video',
          timestamp: timestamp,
          targetEventId: targetEventId,
          isRead: true,
        );

        final json = notification.toJson();
        final restored = NotificationModel.fromJson(json);

        expect(restored, equals(notification));
      });
    });

    group('formattedTimestamp', () {
      test('returns just now for recent timestamps', () {
        final notification = NotificationModel(
          id: 'test-id',
          type: NotificationType.like,
          actorPubkey: actorPubkey,
          message: 'test',
          timestamp: DateTime.now().subtract(const Duration(seconds: 30)),
        );
        expect(notification.formattedTimestamp, equals('just now'));
      });
    });

    group('copyWith', () {
      test('copies with updated fields', () {
        final original = _createNotification(
          type: NotificationType.like,
          eventId: targetEventId,
        );

        final updated = original.copyWith(isRead: true);

        expect(updated.isRead, isTrue);
        expect(updated.type, equals(NotificationType.like));
        expect(updated.targetEventId, equals(targetEventId));
      });
    });
  });
}
