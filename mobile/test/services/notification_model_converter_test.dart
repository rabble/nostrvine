// ABOUTME: Tests for relay notification conversion into app-facing models
// ABOUTME: Covers fallback type mapping, user-facing copy, and metadata

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/services/notification_model_converter.dart';
import 'package:openvine/services/relay_notification_api_service.dart';

void main() {
  group('notificationModelFromRelayApi', () {
    RelayNotification makeRelayNotification({
      String id = 'notif-1',
      String notificationType = 'reaction',
      int sourceKind = 7,
      String? referencedEventId = 'video-event-1',
      String? content,
    }) {
      return RelayNotification(
        id: id,
        sourcePubkey:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        sourceEventId:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        sourceKind: sourceKind,
        referencedEventId: referencedEventId,
        notificationType: notificationType,
        createdAt: DateTime.utc(2026, 3, 9, 10),
        read: false,
        content: content,
      );
    }

    test('maps unknown relay type to like using source kind fallback', () {
      final relay = makeRelayNotification(
        notificationType: 'notification',
      );

      final model = notificationModelFromRelayApi(relay, actorName: 'Alice');

      expect(model.type, NotificationType.like);
      expect(model.message, 'Alice liked your video');
      expect(model.metadata?['relayNotificationType'], 'notification');
    });

    test(
      'maps unknown relay type to comment and preserves comment metadata',
      () {
        final relay = makeRelayNotification(
          notificationType: 'notification',
          sourceKind: 1111,
          content: 'Great video!',
        );

        final model = notificationModelFromRelayApi(relay, actorName: 'Alice');

        expect(model.type, NotificationType.comment);
        expect(model.message, 'Alice commented: Great video!');
        expect(model.metadata?['comment'], 'Great video!');
        expect(model.metadata?['content'], 'Great video!');
      },
    );

    test('maps common relay aliases to their app notification types', () {
      final cases = <String, NotificationType>{
        'like': NotificationType.like,
        'comment': NotificationType.comment,
        'reposted': NotificationType.repost,
        'followed': NotificationType.follow,
        'mentioned': NotificationType.mention,
        'zapped': NotificationType.like,
      };

      for (final entry in cases.entries) {
        final relay = makeRelayNotification(
          notificationType: entry.key,
          sourceKind: 9999,
        );

        final model = notificationModelFromRelayApi(relay, actorName: 'Alice');

        expect(model.type, entry.value, reason: 'failed for ${entry.key}');
      }
    });

    test('avoids surfacing raw generic notification copy to users', () {
      final relay = makeRelayNotification(
        notificationType: 'notification',
        sourceKind: 9999,
        content: 'Scary Guy notification',
      );

      final model = notificationModelFromRelayApi(
        relay,
        actorName: 'Scary Guy',
      );

      expect(model.type, NotificationType.system);
      expect(model.message, 'Scary Guy interacted with your video');
      expect(model.message.toLowerCase(), isNot(contains('notification')));
    });

    test(
      'uses a neutral update fallback for unknown system activity without actor',
      () {
        final relay = makeRelayNotification(
          notificationType: 'notification',
          sourceKind: 9999,
          referencedEventId: null,
          content: 'notification',
        );

        final model = notificationModelFromRelayApi(relay);

        expect(model.type, NotificationType.system);
        expect(model.message, 'You have a new update');
      },
    );

    test(
      'uses a deterministic generated name for follow notifications without actorName',
      () {
        final relay = makeRelayNotification(
          notificationType: 'follow',
          sourceKind: 3,
          referencedEventId: null,
        );

        final model = notificationModelFromRelayApi(relay);

        expect(model.type, NotificationType.follow);
        expect(model.message, isNot('Someone started following you'));
        expect(model.message, endsWith(' started following you'));
      },
    );

    test(
      'preserves original relay.id for API calls, not uniqueId fallback',
      () {
        // When API returns a notification without an id field, the model
        // should have an empty id (not fall back to sourceEventId) so that
        // markAsRead can detect it and skip the API call.
        final relayWithEmptyId = makeRelayNotification(
          id: '',
        );

        final model = notificationModelFromRelayApi(
          relayWithEmptyId,
          actorName: 'Alice',
        );

        // Model.id should be empty (the original relay.id), not sourceEventId
        expect(model.id, isEmpty);
        expect(model.type, NotificationType.like);
      },
    );

    test(
      'uses relay.id when provided by API',
      () {
        final relayWithId = makeRelayNotification(
          id: 'real-notification-id-123',
        );

        final model = notificationModelFromRelayApi(
          relayWithId,
          actorName: 'Alice',
        );

        // Model.id should be the actual notification ID from the API
        expect(model.id, 'real-notification-id-123');
      },
    );
  });
}
