import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:test/test.dart';

void main() {
  group('RelayNotification', () {
    group('fromJson', () {
      test('parses valid notification JSON', () {
        final json = {
          'id': 'notif_123',
          'source_pubkey': 'aabbccdd' * 8,
          'source_event_id': '11223344' * 8,
          'source_kind': 7,
          'referenced_event_id': '55667788' * 8,
          'notification_type': 'reaction',
          'created_at': 1712345678,
          'read': false,
          'content': '+',
        };

        final notification = RelayNotification.fromJson(json);

        expect(notification.id, equals('notif_123'));
        expect(notification.sourcePubkey, equals('aabbccdd' * 8));
        expect(notification.sourceEventId, equals('11223344' * 8));
        expect(notification.sourceKind, equals(7));
        expect(
          notification.referencedEventId,
          equals('55667788' * 8),
        );
        expect(notification.notificationType, equals('reaction'));
        expect(notification.read, isFalse);
        expect(notification.content, equals('+'));
      });

      test('handles null optional fields', () {
        final json = {
          'id': 'notif_123',
          'source_pubkey': 'aabbccdd' * 8,
          'source_event_id': '11223344' * 8,
          'source_kind': 7,
          'notification_type': 'reaction',
          'created_at': 1712345678,
          'read': false,
        };

        final notification = RelayNotification.fromJson(json);

        expect(notification.referencedEventId, isNull);
        expect(notification.content, isNull);
        expect(notification.isReferencedVideo, isFalse);
        expect(notification.referencedVideoTitle, isNull);
      });

      test(
        'flags video target when referenced_video is populated',
        () {
          final json = {
            'id': 'notif_123',
            'source_pubkey': 'aabbccdd' * 8,
            'source_event_id': '11223344' * 8,
            'source_kind': 7,
            'referenced_event_id': '55667788' * 8,
            'referenced_video': {
              'title': 'My funny vine',
              'thumbnail': 'https://example.com/thumb.jpg',
            },
            'notification_type': 'reaction',
            'created_at': 1712345678,
            'read': false,
          };

          final notification = RelayNotification.fromJson(json);

          expect(notification.isReferencedVideo, isTrue);
          expect(notification.referencedVideoTitle, equals('My funny vine'));
        },
      );

      test(
        'reports non-video target when referenced_video is absent (like '
        'on a comment)',
        () {
          final json = {
            'id': 'notif_123',
            'source_pubkey': 'aabbccdd' * 8,
            'source_event_id': '11223344' * 8,
            'source_kind': 7,
            'referenced_event_id': '55667788' * 8,
            'notification_type': 'reaction',
            'created_at': 1712345678,
            'read': false,
          };

          final notification = RelayNotification.fromJson(json);

          expect(notification.isReferencedVideo, isFalse);
          expect(notification.referencedVideoTitle, isNull);
        },
      );

      test(
        'falls back to referenced_event_title when referenced_video is null',
        () {
          final json = {
            'id': 'notif_123',
            'source_pubkey': 'aabbccdd' * 8,
            'source_event_id': '11223344' * 8,
            'source_kind': 7,
            'referenced_event_id': '55667788' * 8,
            'referenced_event_title': 'Top-level title',
            'notification_type': 'reaction',
            'created_at': 1712345678,
            'read': false,
          };

          final notification = RelayNotification.fromJson(json);

          expect(notification.isReferencedVideo, isFalse);
          expect(
            notification.referencedVideoTitle,
            equals('Top-level title'),
          );
        },
      );

      test('treats empty referenced_video.title as null title', () {
        final json = {
          'id': 'notif_123',
          'source_pubkey': 'aabbccdd' * 8,
          'source_event_id': '11223344' * 8,
          'source_kind': 7,
          'referenced_event_id': '55667788' * 8,
          'referenced_video': {'title': ''},
          'notification_type': 'reaction',
          'created_at': 1712345678,
          'read': false,
        };

        final notification = RelayNotification.fromJson(json);

        expect(notification.isReferencedVideo, isTrue);
        expect(notification.referencedVideoTitle, isNull);
      });

      test('handles missing fields with defaults', () {
        final notification = RelayNotification.fromJson(<String, dynamic>{});

        expect(notification.id, equals(''));
        expect(notification.sourcePubkey, equals(''));
        expect(notification.sourceEventId, equals(''));
        expect(notification.sourceKind, equals(0));
        expect(notification.notificationType, equals(''));
        expect(notification.read, isFalse);
      });

      test('converts created_at unix seconds to DateTime', () {
        final json = {
          'id': 'notif_123',
          'source_pubkey': 'aabbccdd' * 8,
          'source_event_id': '11223344' * 8,
          'source_kind': 7,
          'notification_type': 'reaction',
          'created_at': 1712345678,
          'read': false,
        };

        final notification = RelayNotification.fromJson(json);

        expect(
          notification.createdAt,
          equals(
            DateTime.fromMillisecondsSinceEpoch(1712345678 * 1000),
          ),
        );
      });
    });

    group('dedupeKey', () {
      test('uses id when present', () {
        final notification = RelayNotification.fromJson({
          'id': 'notif_123',
          'source_pubkey': 'aabbccdd' * 8,
          'source_event_id': '11223344' * 8,
          'source_kind': 7,
          'notification_type': 'reaction',
          'created_at': 1712345678,
          'read': false,
        });

        expect(notification.dedupeKey, equals('notif_123'));
      });

      test('falls back to sourceEventId when id is empty', () {
        final notification = RelayNotification.fromJson({
          'id': '',
          'source_pubkey': 'aabbccdd' * 8,
          'source_event_id': '11223344' * 8,
          'source_kind': 7,
          'notification_type': 'reaction',
          'created_at': 1712345678,
          'read': false,
        });

        expect(notification.dedupeKey, equals('11223344' * 8));
      });
    });
  });
}
