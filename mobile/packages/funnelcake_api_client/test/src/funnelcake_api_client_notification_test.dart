import 'dart:convert';

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockHttpClient extends Mock implements http.Client {}

class _FakeUri extends Fake implements Uri {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeUri());
  });

  group('FunnelcakeApiClient notifications', () {
    late _MockHttpClient mockHttpClient;
    late FunnelcakeApiClient client;

    const baseUrl = 'https://api.example.com';
    const testPubkey =
        'aabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccdd';

    setUp(() {
      mockHttpClient = _MockHttpClient();
      client = FunnelcakeApiClient(
        baseUrl: baseUrl,
        httpClient: mockHttpClient,
      );
    });

    tearDown(() {
      client.dispose();
    });

    group('getNotifications', () {
      test('fetches notifications with correct URL and headers', () async {
        when(
          () => mockHttpClient.get(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'notifications': <Map<String, dynamic>>[],
              'unread_count': 0,
              'has_more': false,
            }),
            200,
          ),
        );

        final response = await client.getNotifications(pubkey: testPubkey);

        expect(response.notifications, isEmpty);
        expect(response.unreadCount, equals(0));

        final captured = verify(
          () => mockHttpClient.get(
            captureAny(),
            headers: any(named: 'headers'),
          ),
        ).captured;
        final url = captured.first as Uri;
        expect(
          url.path,
          contains('/api/users/$testPubkey/notifications'),
        );
        expect(url.queryParameters['limit'], equals('50'));
        expect(url.queryParameters['before'], isNotNull);
        expect(
          int.tryParse(url.queryParameters['before']!),
          isNotNull,
        );
      });

      test('passes cursor as before parameter', () async {
        when(
          () => mockHttpClient.get(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'notifications': <Map<String, dynamic>>[],
              'unread_count': 0,
              'has_more': false,
            }),
            200,
          ),
        );

        await client.getNotifications(
          pubkey: testPubkey,
          cursor: 'cursor_abc',
        );

        final captured = verify(
          () => mockHttpClient.get(
            captureAny(),
            headers: any(named: 'headers'),
          ),
        ).captured;
        final url = captured.first as Uri;
        expect(url.queryParameters['before'], equals('cursor_abc'));
      });

      test('passes authHeaders when provided', () async {
        when(
          () => mockHttpClient.get(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'notifications': <Map<String, dynamic>>[],
              'unread_count': 0,
              'has_more': false,
            }),
            200,
          ),
        );

        await client.getNotifications(
          pubkey: testPubkey,
          authHeaders: {'Authorization': 'Nostr abc123'},
        );

        final captured = verify(
          () => mockHttpClient.get(
            any(),
            headers: captureAny(named: 'headers'),
          ),
        ).captured;
        final headers = captured.first as Map<String, String>;
        expect(headers['Authorization'], equals('Nostr abc123'));
      });

      test('returns empty response on 404', () async {
        when(
          () => mockHttpClient.get(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer(
          (_) async => http.Response('Not found', 404),
        );

        final response = await client.getNotifications(pubkey: testPubkey);

        expect(response.notifications, isEmpty);
        expect(response.unreadCount, equals(0));
        expect(response.hasMore, isFalse);
      });

      test('returns empty response on server error', () async {
        when(
          () => mockHttpClient.get(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer(
          (_) async => http.Response('Internal error', 500),
        );

        final response = await client.getNotifications(pubkey: testPubkey);

        expect(response.notifications, isEmpty);
        expect(response.unreadCount, equals(0));
      });

      test('returns empty response on exception', () async {
        when(
          () => mockHttpClient.get(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenThrow(Exception('network error'));

        final response = await client.getNotifications(pubkey: testPubkey);

        expect(response.notifications, isEmpty);
        expect(response.unreadCount, equals(0));
      });

      test('parses successful response with notifications', () async {
        when(
          () => mockHttpClient.get(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'notifications': [
                {
                  'id': 'notif_1',
                  'source_pubkey': testPubkey,
                  'source_event_id':
                      '11223344112233441122334411223344'
                      '11223344112233441122334411223344',
                  'source_kind': 7,
                  'notification_type': 'reaction',
                  'created_at': 1712345678,
                  'read': false,
                  'content': '+',
                },
              ],
              'unread_count': 3,
              'next_cursor': 'next_page',
              'has_more': true,
            }),
            200,
          ),
        );

        final response = await client.getNotifications(pubkey: testPubkey);

        expect(response.notifications, hasLength(1));
        expect(response.notifications.first.id, equals('notif_1'));
        expect(response.unreadCount, equals(3));
        expect(response.nextCursor, equals('next_page'));
        expect(response.hasMore, isTrue);
      });
    });

    group('markNotificationsRead', () {
      test('posts to correct endpoint', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({'success': true, 'marked_count': 5}),
            200,
          ),
        );

        await client.markNotificationsRead(pubkey: testPubkey);

        final captured = verify(
          () => mockHttpClient.post(
            captureAny(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).captured;
        final url = captured.first as Uri;
        expect(
          url.path,
          contains(
            '/api/users/$testPubkey/notifications/read',
          ),
        );
      });

      test('passes authHeaders when provided', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({'success': true, 'marked_count': 0}),
            200,
          ),
        );

        await client.markNotificationsRead(
          pubkey: testPubkey,
          authHeaders: {'Authorization': 'Nostr abc123'},
        );

        final captured = verify(
          () => mockHttpClient.post(
            any(),
            headers: captureAny(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).captured;
        final headers = captured.first as Map<String, String>;
        expect(headers['Authorization'], equals('Nostr abc123'));
      });

      test('sends notification_ids in body when provided', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({'success': true, 'marked_count': 2}),
            200,
          ),
        );

        await client.markNotificationsRead(
          pubkey: testPubkey,
          notificationIds: ['id1', 'id2'],
        );

        final captured = verify(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: captureAny(named: 'body'),
          ),
        ).captured;
        final body =
            jsonDecode(captured.first as String) as Map<String, dynamic>;
        expect(body['notification_ids'], equals(['id1', 'id2']));
      });

      test('returns failure response on server error', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response('Internal error', 500),
        );

        final response = await client.markNotificationsRead(pubkey: testPubkey);

        expect(response.success, isFalse);
        expect(response.markedCount, equals(0));
      });

      test('returns failure response on exception', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenThrow(Exception('network error'));

        final response = await client.markNotificationsRead(pubkey: testPubkey);

        expect(response.success, isFalse);
        expect(response.markedCount, equals(0));
      });

      test('parses successful mark-read response', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({'success': true, 'marked_count': 10}),
            200,
          ),
        );

        final response = await client.markNotificationsRead(pubkey: testPubkey);

        expect(response.success, isTrue);
        expect(response.markedCount, equals(10));
      });
    });
  });
}
