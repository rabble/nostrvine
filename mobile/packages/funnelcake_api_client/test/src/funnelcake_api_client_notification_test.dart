import 'dart:async';
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
    const stableCursorId =
        '1122334411223344112233441122334411223344112233441122334411223344';

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

      test('passes cursorId as before_id parameter', () async {
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
          cursor: '1700000000',
          cursorId: stableCursorId,
        );

        final captured = verify(
          () => mockHttpClient.get(
            captureAny(),
            headers: any(named: 'headers'),
          ),
        ).captured;
        final url = captured.first as Uri;
        expect(url.queryParameters['before'], equals('1700000000'));
        expect(
          url.queryParameters['before_id'],
          equals(stableCursorId),
        );
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

      test('uses the provided requestUri without rebuilding it', () async {
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

        final requestUri = Uri.parse(
          '$baseUrl/api/users/$testPubkey/notifications'
          '?limit=50&before=custom_cursor_123',
        );

        await client.getNotifications(
          pubkey: testPubkey,
          requestUri: requestUri,
        );

        final captured = verify(
          () => mockHttpClient.get(
            captureAny(),
            headers: any(named: 'headers'),
          ),
        ).captured;
        expect(captured.first, same(requestUri));
      });

      test('throws FunnelcakeNotConfiguredException when not available', () {
        final emptyClient = FunnelcakeApiClient(
          baseUrl: '',
          httpClient: mockHttpClient,
        );

        expect(
          () => emptyClient.getNotifications(pubkey: testPubkey),
          throwsA(isA<FunnelcakeNotConfiguredException>()),
        );

        emptyClient.dispose();
      });

      test('throws FunnelcakeApiException on 404', () async {
        when(
          () => mockHttpClient.get(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer(
          (_) async => http.Response('Not found', 404),
        );

        expect(
          () => client.getNotifications(pubkey: testPubkey),
          throwsA(
            isA<FunnelcakeApiException>().having(
              (e) => e.statusCode,
              'statusCode',
              equals(404),
            ),
          ),
        );
      });

      test('throws FunnelcakeApiException on server error', () async {
        when(
          () => mockHttpClient.get(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            '{"error":"Internal server error"}',
            500,
            headers: {
              'x-request-id': 'req-123',
              'cf-ray': 'ray-456',
            },
          ),
        );

        expect(
          () => client.getNotifications(
            pubkey: testPubkey,
            cursor: '1778198474',
            cursorId: stableCursorId,
          ),
          throwsA(
            isA<FunnelcakeApiException>()
                .having(
                  (e) => e.statusCode,
                  'statusCode',
                  equals(500),
                )
                .having(
                  (e) => e.url,
                  'url',
                  allOf(
                    contains('before=1778198474'),
                    contains('before_id=$stableCursorId'),
                  ),
                )
                .having(
                  (e) => e.responseBody,
                  'responseBody',
                  equals('{"error":"Internal server error"}'),
                )
                .having(
                  (e) => e.requestId,
                  'requestId',
                  equals('req-123'),
                )
                .having(
                  (e) => e.diagnosticHeaders,
                  'diagnosticHeaders',
                  containsPair('cf-ray', 'ray-456'),
                )
                .having(
                  (e) => e.toString(),
                  'toString',
                  allOf(
                    contains('status: 500'),
                    contains('before=1778198474'),
                    contains('before_id=$stableCursorId'),
                    contains('requestId: req-123'),
                    contains('cf-ray: ray-456'),
                    contains('body: {"error":"Internal server error"}'),
                  ),
                ),
          ),
        );
      });

      test('includes response body details on server error', () async {
        when(
          () => mockHttpClient.get(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            '{"error":"notifications table unavailable"}',
            500,
          ),
        );

        expect(
          () => client.getNotifications(pubkey: testPubkey),
          throwsA(
            isA<FunnelcakeApiException>().having(
              (e) => e.toString(),
              'toString',
              contains('notifications table unavailable'),
            ),
          ),
        );
      });

      test('throws FunnelcakeTimeoutException on timeout', () async {
        when(
          () => mockHttpClient.get(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer((_) async => throw TimeoutException('Request timed out'));

        expect(
          () => client.getNotifications(pubkey: testPubkey),
          throwsA(isA<FunnelcakeTimeoutException>()),
        );
      });

      test('throws FunnelcakeException on network error', () async {
        when(
          () => mockHttpClient.get(
            any(),
            headers: any(named: 'headers'),
          ),
        ).thenThrow(Exception('network error'));

        expect(
          () => client.getNotifications(pubkey: testPubkey),
          throwsA(
            isA<FunnelcakeException>().having(
              (e) => e.message,
              'message',
              contains('Failed to fetch notifications'),
            ),
          ),
        );
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

      test('throws FunnelcakeNotConfiguredException when not available', () {
        final emptyClient = FunnelcakeApiClient(
          baseUrl: '',
          httpClient: mockHttpClient,
        );

        expect(
          () => emptyClient.markNotificationsRead(pubkey: testPubkey),
          throwsA(isA<FunnelcakeNotConfiguredException>()),
        );

        emptyClient.dispose();
      });

      test('throws FunnelcakeApiException on server error', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response('Internal error', 500),
        );

        expect(
          () => client.markNotificationsRead(pubkey: testPubkey),
          throwsA(
            isA<FunnelcakeApiException>().having(
              (e) => e.statusCode,
              'statusCode',
              equals(500),
            ),
          ),
        );
      });

      test('throws FunnelcakeTimeoutException on timeout', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => throw TimeoutException('Request timed out'));

        expect(
          () => client.markNotificationsRead(pubkey: testPubkey),
          throwsA(isA<FunnelcakeTimeoutException>()),
        );
      });

      test('throws FunnelcakeException on network error', () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenThrow(Exception('network error'));

        expect(
          () => client.markNotificationsRead(pubkey: testPubkey),
          throwsA(
            isA<FunnelcakeException>().having(
              (e) => e.message,
              'message',
              contains('Failed to mark notifications as read'),
            ),
          ),
        );
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

      test(
        'throws FunnelcakeApiException on 200 with success: false',
        () async {
          when(
            () => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            ),
          ).thenAnswer(
            (_) async => http.Response(
              jsonEncode({
                'success': false,
                'marked_count': 0,
                'error': 'token rejected',
              }),
              200,
            ),
          );

          expect(
            () => client.markNotificationsRead(pubkey: testPubkey),
            throwsA(
              isA<FunnelcakeApiException>()
                  .having((e) => e.statusCode, 'statusCode', equals(200))
                  .having(
                    (e) => e.message,
                    'message',
                    contains('token rejected'),
                  ),
            ),
          );
        },
      );

      test(
        'throws FunnelcakeApiException on 200 / success:false with no error',
        () async {
          when(
            () => mockHttpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            ),
          ).thenAnswer(
            (_) async => http.Response(
              jsonEncode({'success': false, 'marked_count': 0}),
              200,
            ),
          );

          expect(
            () => client.markNotificationsRead(pubkey: testPubkey),
            throwsA(
              isA<FunnelcakeApiException>()
                  .having((e) => e.statusCode, 'statusCode', equals(200))
                  .having(
                    (e) => e.message,
                    'message',
                    equals('Mark notifications read rejected by server'),
                  ),
            ),
          );
        },
      );
    });

    group('notificationsUri', () {
      test('default cursor uses Unix seconds not milliseconds', () {
        final uri = client.notificationsUri(pubkey: testPubkey);
        final before = int.parse(uri.queryParameters['before']!);

        // Unix seconds should be ~10 digits (1.7 billion in 2026).
        // Milliseconds would be ~13 digits (1.7 trillion).
        expect(before, lessThan(10000000000));
      });

      test('passes cursor through unchanged', () {
        final uri = client.notificationsUri(
          pubkey: testPubkey,
          cursor: '1700000000',
        );

        expect(uri.queryParameters['before'], equals('1700000000'));
      });

      test('includes before_id when cursorId is provided', () {
        final uri = client.notificationsUri(
          pubkey: testPubkey,
          cursor: '1700000000',
          cursorId: stableCursorId,
        );

        expect(uri.queryParameters['before'], equals('1700000000'));
        expect(
          uri.queryParameters['before_id'],
          equals(stableCursorId),
        );
      });
    });
  });
}
