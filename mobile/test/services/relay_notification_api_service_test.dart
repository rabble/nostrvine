// ABOUTME: Unit tests for RelayNotificationApiService
// ABOUTME: Tests HTTP client, NIP-98 auth, pagination, and error handling

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/nip98_auth_service.dart';
import 'package:openvine/services/relay_notification_api_service.dart';

class MockHttpClient extends Mock implements http.Client {}

class MockNip98AuthService extends Mock implements Nip98AuthService {}

class FakeUri extends Fake implements Uri {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeUri());
  });

  group('RelayNotificationApiService', () {
    late MockHttpClient mockHttpClient;
    late MockNip98AuthService mockNip98AuthService;
    late RelayNotificationApiService service;

    const testBaseUrl = 'https://relay.dvines.org';
    const testPubkey = 'test_pubkey_hex_1234567890abcdef';

    setUp(() {
      mockHttpClient = MockHttpClient();
      mockNip98AuthService = MockNip98AuthService();

      service = RelayNotificationApiService(
        baseUrl: testBaseUrl,
        nip98AuthService: mockNip98AuthService,
        httpClient: mockHttpClient,
      );
    });

    group('isAvailable', () {
      test('returns true when base URL is configured', () {
        expect(service.isAvailable, isTrue);
      });

      test('returns false when base URL is null', () {
        final serviceWithoutUrl = RelayNotificationApiService(
          baseUrl: null,
          nip98AuthService: mockNip98AuthService,
          httpClient: mockHttpClient,
        );
        expect(serviceWithoutUrl.isAvailable, isFalse);
      });

      test('returns false when base URL is empty', () {
        final serviceWithEmptyUrl = RelayNotificationApiService(
          baseUrl: '',
          nip98AuthService: mockNip98AuthService,
          httpClient: mockHttpClient,
        );
        expect(serviceWithEmptyUrl.isAvailable, isFalse);
      });
    });

    group('getNotifications', () {
      final mockAuthToken = Nip98Token(
        token: 'mock_token_base64',
        signedEvent: _createMockEvent(),
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      );

      test('returns empty response when API is not available', () async {
        final serviceWithoutUrl = RelayNotificationApiService(
          baseUrl: null,
          nip98AuthService: mockNip98AuthService,
          httpClient: mockHttpClient,
        );

        final response = await serviceWithoutUrl.getNotifications(
          pubkey: testPubkey,
        );

        expect(response.notifications, isEmpty);
        expect(response.unreadCount, 0);
      });

      test('returns empty response when pubkey is empty', () async {
        final response = await service.getNotifications(pubkey: '');

        expect(response.notifications, isEmpty);
        expect(response.unreadCount, 0);
      });

      test('returns empty response when auth token creation fails', () async {
        when(
          () => mockNip98AuthService.createAuthToken(
            url: any(named: 'url'),
            method: HttpMethod.get,
          ),
        ).thenAnswer((_) async => null);

        final response = await service.getNotifications(pubkey: testPubkey);

        expect(response.notifications, isEmpty);
      });

      test('fetches notifications successfully with pagination', () async {
        when(
          () => mockNip98AuthService.createAuthToken(
            url: any(named: 'url'),
            method: HttpMethod.get,
          ),
        ).thenAnswer((_) async => mockAuthToken);

        final responseBody = jsonEncode({
          'notifications': [
            {
              'id': 'notif_1',
              'source_pubkey': 'author_pubkey_1',
              'source_event_id': 'event_1',
              'source_kind': 7,
              'referenced_event_id': 'video_event_1',
              'notification_type': 'reaction',
              'created_at': 1700000000,
              'read': false,
            },
            {
              'id': 'notif_2',
              'source_pubkey': 'author_pubkey_2',
              'source_event_id': 'event_2',
              'source_kind': 1111,
              'referenced_event_id': 'video_event_1',
              'notification_type': 'reply',
              'created_at': 1699999000,
              'read': true,
            },
          ],
          'unread_count': 5,
          'next_cursor': 'cursor_abc123',
          'has_more': true,
        });

        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response(responseBody, 200));

        final response = await service.getNotifications(pubkey: testPubkey);

        expect(response.notifications.length, 2);
        expect(response.unreadCount, 5);
        expect(response.nextCursor, 'cursor_abc123');
        expect(response.hasMore, isTrue);

        // Verify first notification
        expect(response.notifications[0].id, 'notif_1');
        expect(response.notifications[0].sourcePubkey, 'author_pubkey_1');
        expect(response.notifications[0].notificationType, 'reaction');
        expect(response.notifications[0].read, isFalse);

        // Verify second notification
        expect(response.notifications[1].id, 'notif_2');
        expect(response.notifications[1].notificationType, 'reply');
        expect(response.notifications[1].read, isTrue);
      });

      test('passes query parameters correctly', () async {
        when(
          () => mockNip98AuthService.createAuthToken(
            url: any(named: 'url'),
            method: HttpMethod.get,
          ),
        ).thenAnswer((_) async => mockAuthToken);

        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({'notifications': [], 'unread_count': 0}),
            200,
          ),
        );

        await service.getNotifications(
          pubkey: testPubkey,
          types: ['reaction', 'follow'],
          unreadOnly: true,
          limit: 25,
          before: 'cursor_xyz',
        );

        final captured =
            verify(
                  () => mockHttpClient.get(
                    captureAny(),
                    headers: any(named: 'headers'),
                  ),
                ).captured.first
                as Uri;

        expect(captured.queryParameters['limit'], '25');
        expect(captured.queryParameters['types'], 'reaction,follow');
        expect(captured.queryParameters['unread_only'], 'true');
        expect(captured.queryParameters['before'], 'cursor_xyz');
      });

      test('handles 404 response gracefully', () async {
        when(
          () => mockNip98AuthService.createAuthToken(
            url: any(named: 'url'),
            method: HttpMethod.get,
          ),
        ).thenAnswer((_) async => mockAuthToken);

        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Not found', 404));

        final response = await service.getNotifications(pubkey: testPubkey);

        expect(response.notifications, isEmpty);
        expect(response.unreadCount, 0);
      });

      test('handles 401 unauthorized response', () async {
        when(
          () => mockNip98AuthService.createAuthToken(
            url: any(named: 'url'),
            method: HttpMethod.get,
          ),
        ).thenAnswer((_) async => mockAuthToken);

        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('Unauthorized', 401));

        final response = await service.getNotifications(pubkey: testPubkey);

        expect(response.notifications, isEmpty);
      });

      test('handles network errors gracefully', () async {
        when(
          () => mockNip98AuthService.createAuthToken(
            url: any(named: 'url'),
            method: HttpMethod.get,
          ),
        ).thenAnswer((_) async => mockAuthToken);

        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenThrow(Exception('Network error'));

        final response = await service.getNotifications(pubkey: testPubkey);

        expect(response.notifications, isEmpty);
      });
    });

    group('markAsRead', () {
      final mockAuthToken = Nip98Token(
        token: 'mock_token_base64',
        signedEvent: _createMockEvent(),
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      );

      test('marks specific notifications as read', () async {
        when(
          () => mockNip98AuthService.createAuthToken(
            url: any(named: 'url'),
            method: HttpMethod.post,
            payload: any(named: 'payload'),
          ),
        ).thenAnswer((_) async => mockAuthToken);

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

        final response = await service.markAsRead(
          pubkey: testPubkey,
          notificationIds: ['notif_1', 'notif_2'],
        );

        expect(response.success, isTrue);
        expect(response.markedCount, 2);
      });

      test('marks all notifications as read when no IDs provided', () async {
        when(
          () => mockNip98AuthService.createAuthToken(
            url: any(named: 'url'),
            method: HttpMethod.post,
            payload: any(named: 'payload'),
          ),
        ).thenAnswer((_) async => mockAuthToken);

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

        final response = await service.markAsRead(pubkey: testPubkey);

        expect(response.success, isTrue);
        expect(response.markedCount, 10);
      });

      test('returns error when API is not available', () async {
        final serviceWithoutUrl = RelayNotificationApiService(
          baseUrl: null,
          nip98AuthService: mockNip98AuthService,
          httpClient: mockHttpClient,
        );

        final response = await serviceWithoutUrl.markAsRead(pubkey: testPubkey);

        expect(response.success, isFalse);
        expect(response.error, 'API not available');
      });

      test('handles 401 unauthorized response', () async {
        when(
          () => mockNip98AuthService.createAuthToken(
            url: any(named: 'url'),
            method: HttpMethod.post,
            payload: any(named: 'payload'),
          ),
        ).thenAnswer((_) async => mockAuthToken);

        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response('Unauthorized', 401));

        final response = await service.markAsRead(pubkey: testPubkey);

        expect(response.success, isFalse);
        expect(response.error, 'Authentication failed');
      });
    });

    group('getUnreadCount', () {
      test('returns unread count', () async {
        final mockAuthToken = Nip98Token(
          token: 'mock_token_base64',
          signedEvent: _createMockEvent(),
          createdAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(minutes: 10)),
        );

        when(
          () => mockNip98AuthService.createAuthToken(
            url: any(named: 'url'),
            method: HttpMethod.get,
          ),
        ).thenAnswer((_) async => mockAuthToken);

        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({'notifications': [], 'unread_count': 42}),
            200,
          ),
        );

        final count = await service.getUnreadCount(pubkey: testPubkey);

        expect(count, 42);
      });
    });

    group('RelayNotification model', () {
      test('parses from JSON correctly', () {
        final json = {
          'id': 'notif_123',
          'source_pubkey': 'author_pubkey',
          'source_event_id': 'event_abc',
          'source_kind': 7,
          'referenced_event_id': 'video_event_xyz',
          'notification_type': 'reaction',
          'created_at': 1700000000,
          'read': false,
          'content': '+',
        };

        final notification = RelayNotification.fromJson(json);

        expect(notification.id, 'notif_123');
        expect(notification.sourcePubkey, 'author_pubkey');
        expect(notification.sourceEventId, 'event_abc');
        expect(notification.sourceKind, 7);
        expect(notification.referencedEventId, 'video_event_xyz');
        expect(notification.notificationType, 'reaction');
        expect(notification.read, isFalse);
        expect(notification.content, '+');
        expect(notification.createdAt.year, 2023);
      });

      test('handles missing optional fields', () {
        final json = {
          'id': 'notif_123',
          'source_pubkey': 'author_pubkey',
          'source_event_id': 'event_abc',
          'source_kind': 3,
          'notification_type': 'follow',
          'created_at': 1700000000,
          'read': true,
        };

        final notification = RelayNotification.fromJson(json);

        expect(notification.referencedEventId, isNull);
        expect(notification.content, isNull);
      });

      test('handles ISO date string format', () {
        final json = {
          'id': 'notif_123',
          'source_pubkey': 'author_pubkey',
          'source_event_id': 'event_abc',
          'source_kind': 7,
          'notification_type': 'reaction',
          'created_at': '2023-11-14T12:00:00Z',
          'read': false,
        };

        final notification = RelayNotification.fromJson(json);

        expect(notification.createdAt.year, 2023);
        expect(notification.createdAt.month, 11);
        expect(notification.createdAt.day, 14);
      });
    });

    group('NotificationsResponse model', () {
      test('parses from JSON correctly', () {
        final json = {
          'notifications': [
            {
              'id': 'notif_1',
              'source_pubkey': 'pubkey_1',
              'source_event_id': 'event_1',
              'source_kind': 7,
              'notification_type': 'reaction',
              'created_at': 1700000000,
              'read': false,
            },
          ],
          'unread_count': 3,
          'next_cursor': 'cursor_abc',
          'has_more': true,
        };

        final response = NotificationsResponse.fromJson(json);

        expect(response.notifications.length, 1);
        expect(response.unreadCount, 3);
        expect(response.nextCursor, 'cursor_abc');
        expect(response.hasMore, isTrue);
      });

      test('handles empty notifications array', () {
        final json = {
          'notifications': <Map<String, dynamic>>[],
          'unread_count': 0,
        };

        final response = NotificationsResponse.fromJson(json);

        expect(response.notifications, isEmpty);
        expect(response.unreadCount, 0);
        expect(response.nextCursor, isNull);
        expect(response.hasMore, isFalse);
      });
    });

    group('MarkReadResponse model', () {
      test('parses success response', () {
        final json = {'success': true, 'marked_count': 5};

        final response = MarkReadResponse.fromJson(json);

        expect(response.success, isTrue);
        expect(response.markedCount, 5);
        expect(response.error, isNull);
      });

      test('parses error response', () {
        final json = {'success': false, 'error': 'Invalid notification IDs'};

        final response = MarkReadResponse.fromJson(json);

        expect(response.success, isFalse);
        expect(response.error, 'Invalid notification IDs');
      });
    });
  });
}

/// Creates a mock Event for testing Nip98Token
Event _createMockEvent() {
  return Event.fromJson({
    'id':
        'mock_event_id_0123456789abcdef0123456789abcdef0123456789abcdef0123456789abc',
    'kind': 27235,
    'pubkey':
        'mock_pubkey_0123456789abcdef0123456789abcdef0123456789abcdef01234567',
    'created_at': 1700000000,
    'content': '',
    'tags': <List<String>>[],
    'sig':
        'mock_signature_0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef01234567',
  });
}
