import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:test/test.dart';

void main() {
  group('NotificationResponse', () {
    test('parses response with notifications', () {
      final json = {
        'notifications': [
          {
            'id': 'notif_1',
            'source_pubkey': 'aabbccdd' * 8,
            'source_event_id': '11223344' * 8,
            'source_kind': 7,
            'notification_type': 'reaction',
            'created_at': 1712345678,
            'read': false,
          },
        ],
        'unread_count': 5,
        'next_cursor': 'cursor_abc',
        'has_more': true,
      };

      final response = NotificationResponse.fromJson(json);

      expect(response.notifications, hasLength(1));
      expect(response.unreadCount, equals(5));
      expect(response.nextCursor, equals('cursor_abc'));
      expect(response.hasMore, isTrue);
    });

    test('handles empty notifications list', () {
      final json = {
        'notifications': <Map<String, dynamic>>[],
        'unread_count': 0,
        'has_more': false,
      };

      final response = NotificationResponse.fromJson(json);

      expect(response.notifications, isEmpty);
      expect(response.unreadCount, equals(0));
      expect(response.nextCursor, isNull);
      expect(response.hasMore, isFalse);
    });

    test('handles missing notifications key', () {
      final response = NotificationResponse.fromJson(<String, dynamic>{});

      expect(response.notifications, isEmpty);
      expect(response.unreadCount, equals(0));
      expect(response.nextCursor, isNull);
      expect(response.hasMore, isFalse);
    });
  });

  group('MarkReadResponse', () {
    test('parses success response', () {
      final json = {
        'success': true,
        'marked_count': 10,
      };

      final response = MarkReadResponse.fromJson(json);

      expect(response.success, isTrue);
      expect(response.markedCount, equals(10));
      expect(response.error, isNull);
    });

    test('parses failure response with error', () {
      final json = {
        'success': false,
        'marked_count': 0,
        'error': 'unauthorized',
      };

      final response = MarkReadResponse.fromJson(json);

      expect(response.success, isFalse);
      expect(response.markedCount, equals(0));
      expect(response.error, equals('unauthorized'));
    });

    test('handles missing fields with defaults', () {
      final response = MarkReadResponse.fromJson(<String, dynamic>{});

      expect(response.success, isFalse);
      expect(response.markedCount, equals(0));
      expect(response.error, isNull);
    });
  });
}
