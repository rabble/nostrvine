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
        'next_cursor_id': '11223344' * 8,
        'has_more': true,
      };

      final response = NotificationResponse.fromJson(json);

      expect(response.notifications, hasLength(1));
      expect(response.unreadCount, equals(5));
      expect(response.nextCursor, equals('cursor_abc'));
      expect(response.nextCursorId, equals('11223344' * 8));
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
      expect(response.nextCursorId, isNull);
      expect(response.hasMore, isFalse);
    });

    test('handles missing notifications key', () {
      final response = NotificationResponse.fromJson(<String, dynamic>{});

      expect(response.notifications, isEmpty);
      expect(response.unreadCount, equals(0));
      expect(response.nextCursor, isNull);
      expect(response.nextCursorId, isNull);
      expect(response.hasMore, isFalse);
    });
  });

  group('MarkReadResponse', () {
    test('honors explicit `success: true` when the server sends it', () {
      final json = {
        'success': true,
        'marked_count': 10,
      };

      final response = MarkReadResponse.fromJson(json);

      expect(response.success, isTrue);
      expect(response.markedCount, equals(10));
      expect(response.error, isNull);
    });

    test('honors explicit `success: false` when the server sends it', () {
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

    test(
      'treats the real funnelcake response shape (no `success` field) as '
      'success',
      () {
        // Per https://relay.divine.video/docs/llm-guide the server
        // returns {"marked_count": N, "marked_all": bool} on success.
        // There is no `success` field — PR #4271 assumed one and
        // defaulted to `false`, which made every successful mark-read
        // parse as a soft-failure and bounce the notifications badge
        // back up via the repository's rollback path.
        final json = {'marked_count': 5, 'marked_all': true};

        final response = MarkReadResponse.fromJson(json);

        expect(response.success, isTrue);
        expect(response.markedCount, equals(5));
        expect(response.error, isNull);
      },
    );

    test('treats a body with an `error` field as failure', () {
      // No `success` field but an `error` string → still a failure.
      final json = {'error': 'token rejected'};

      final response = MarkReadResponse.fromJson(json);

      expect(response.success, isFalse);
      expect(response.markedCount, equals(0));
      expect(response.error, equals('token rejected'));
    });

    test('treats an empty body as success (no error reported)', () {
      // Degenerate empty body: server returned 200 with `{}`. Since
      // there is no `error`, treat as success — the repository's
      // optimistic flip already happened and no rollback is needed.
      final response = MarkReadResponse.fromJson(<String, dynamic>{});

      expect(response.success, isTrue);
      expect(response.markedCount, equals(0));
      expect(response.error, isNull);
    });
  });
}
