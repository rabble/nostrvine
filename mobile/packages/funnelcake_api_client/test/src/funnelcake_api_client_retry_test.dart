// ABOUTME: Tests that idempotent Funnelcake GETs retry transient failures.
// ABOUTME: Pins that definitive 4xx answers are never retried.

import 'dart:async';
import 'dart:io';

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

  group('FunnelcakeApiClient GET retry', () {
    late _MockHttpClient httpClient;
    late FunnelcakeApiClient client;

    const baseUrl = 'https://api.example.com';
    const eventId =
        '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';

    const eventBody =
        '{"event":{"id":"$eventId","pubkey":"$eventId","created_at":1,'
        '"kind":34236,"tags":[],"content":"","sig":""}}';

    setUp(() {
      httpClient = _MockHttpClient();
      client = FunnelcakeApiClient(
        baseUrl: baseUrl,
        httpClient: httpClient,
        // Zero backoff keeps the suite fast; the retry policy itself is
        // what these tests pin, not the wall-clock delay.
        retryBaseDelay: Duration.zero,
      );
    });

    test('retries a timed-out GET and returns the retried response', () async {
      var attempts = 0;
      when(
        () => httpClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async {
        attempts++;
        if (attempts == 1) {
          throw TimeoutException('boom');
        }
        return http.Response(eventBody, 200);
      });

      final event = await client.getVideoEvent(eventId);

      expect(event, isNotNull);
      expect(attempts, equals(2));
    });

    test('retries a 503 and returns the retried response', () async {
      var attempts = 0;
      when(
        () => httpClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async {
        attempts++;
        if (attempts == 1) return http.Response('upstream down', 503);
        return http.Response(eventBody, 200);
      });

      final event = await client.getVideoEvent(eventId);

      expect(event, isNotNull);
      expect(attempts, equals(2));
    });

    test('retries a dropped connection', () async {
      var attempts = 0;
      when(
        () => httpClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async {
        attempts++;
        if (attempts == 1) {
          throw const SocketException('connection reset');
        }
        return http.Response(eventBody, 200);
      });

      final event = await client.getVideoEvent(eventId);

      expect(event, isNotNull);
      expect(attempts, equals(2));
    });

    test('does not retry a 404 — absence is a definitive answer', () async {
      var attempts = 0;
      when(
        () => httpClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async {
        attempts++;
        return http.Response('not found', 404);
      });

      final event = await client.getVideoEvent(eventId);

      expect(event, isNull);
      expect(attempts, equals(1));
    });

    test('gives up after the attempt budget and throws', () async {
      var attempts = 0;
      when(
        () => httpClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async {
        attempts++;
        throw TimeoutException('still down');
      });

      await expectLater(
        client.getVideoEvent(eventId),
        throwsA(isA<FunnelcakeTimeoutException>()),
      );
      expect(attempts, equals(FunnelcakeApiClient.maxGetAttempts));
    });
  });
}
