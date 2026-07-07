// ABOUTME: Tests for first-party product analytics ingest client.
// ABOUTME: Covers NIP-98 auth, batch POST shape, and outcome classification.

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/analytics_ingest_client.dart';
import 'package:openvine/services/nip98_auth_service.dart';

class _MockNip98AuthService extends Mock implements Nip98AuthService {}

void main() {
  const testPubkey =
      '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd';

  late _MockNip98AuthService mockNip98;

  setUpAll(() {
    registerFallbackValue(HttpMethod.post);
  });

  setUp(() {
    mockNip98 = _MockNip98AuthService();
  });

  Nip98Token buildToken() {
    final signedEvent = Event(
      testPubkey,
      27235,
      const [
        ['u', 'https://api.divine.video/api/analytics/events'],
        ['method', 'POST'],
      ],
      '',
      createdAt: 1700000000,
    );
    final now = clock.now();
    return Nip98Token(
      token: 'fake-base64-token',
      signedEvent: signedEvent,
      createdAt: now,
      expiresAt: now.add(const Duration(seconds: 45)),
    );
  }

  void stubToken(Nip98Token? token) {
    when(
      () => mockNip98.createAuthToken(
        url: any(named: 'url'),
        method: any(named: 'method'),
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((_) async => token);
  }

  AnalyticsIngestClient buildClient(http.Client httpClient) {
    return AnalyticsIngestClient(
      httpClient: httpClient,
      nip98AuthService: mockNip98,
      apiBaseUrl: () => 'https://api.divine.video',
    );
  }

  ProductAnalyticsEvent buildEvent(String id) {
    return ProductAnalyticsEvent(
      eventId: id,
      eventName: 'screen_time',
      occurredAt: DateTime.utc(2026, 7, 7, 12),
      userPubkey: testPubkey,
      anonymousId: '018ff7d7-2ef5-7000-8000-000000000001',
      sessionId: '018ff7d7-2ef5-7000-8000-000000000002',
      platform: 'ios',
      appVersion: '1.2.3',
      buildNumber: '123',
      surface: AnalyticsSurface.feed,
      props: const {'screen_name': 'feed'},
      propsNum: const {'duration_ms': 1500.0},
    );
  }

  group(AnalyticsIngestClient, () {
    test(
      'POSTs batch JSON to /api/analytics/events with NIP-98 auth',
      () async {
        stubToken(buildToken());
        http.Request? captured;
        final client = buildClient(
          MockClient((request) async {
            captured = request;
            return http.Response(jsonEncode({'accepted': true}), 200);
          }),
        );

        await client.publishBatch([buildEvent('event-a')]);

        expect(captured, isNotNull);
        expect(captured!.method, equals('POST'));
        expect(
          captured!.url.toString(),
          equals('https://api.divine.video/api/analytics/events'),
        );
        expect(captured!.headers['Authorization'], 'Nostr fake-base64-token');
        final body = jsonDecode(captured!.body) as Map<String, dynamic>;
        final events = body['events'] as List<dynamic>;
        expect(events, hasLength(1));
        expect(events.single, containsPair('event_id', 'event-a'));
        expect(events.single, containsPair('event_name', 'screen_time'));
        expect(events.single, containsPair('surface', 'feed'));
        expect(events.single, containsPair('schema_version', 1));
      },
    );

    test('returns accepted on 200 accepted response', () async {
      stubToken(buildToken());
      final client = buildClient(
        MockClient(
          (_) async => http.Response(jsonEncode({'accepted': true}), 200),
        ),
      );

      final result = await client.publishBatch([buildEvent('event-a')]);

      expect(result, isA<AnalyticsIngestAccepted>());
    });

    for (final status in [400, 401, 403, 422]) {
      test('returns rejected on non-retryable $status', () async {
        stubToken(buildToken());
        final client = buildClient(
          MockClient((_) async => http.Response('bad event', status)),
        );

        final result = await client.publishBatch([buildEvent('event-a')]);

        expect(result, isA<AnalyticsIngestRejected>());
        expect((result as AnalyticsIngestRejected).statusCode, status);
      });
    }

    test('returns transient failure on timeout', () async {
      stubToken(buildToken());
      final client = AnalyticsIngestClient(
        httpClient: MockClient((_) async {
          await Future<void>.delayed(const Duration(seconds: 30));
          return http.Response('', 200);
        }),
        nip98AuthService: mockNip98,
        apiBaseUrl: () => 'https://api.divine.video',
        timeout: const Duration(milliseconds: 50),
      );

      final result = await client.publishBatch([buildEvent('event-a')]);

      expect(result, isA<AnalyticsIngestTransientFailure>());
    });

    test('does not POST without a NIP-98 token', () async {
      stubToken(null);
      var requested = false;
      final client = buildClient(
        MockClient((_) async {
          requested = true;
          return http.Response('', 200);
        }),
      );

      final result = await client.publishBatch([buildEvent('event-a')]);

      expect(result, isA<AnalyticsIngestTransientFailure>());
      expect(requested, isFalse);
    });
  });
}
