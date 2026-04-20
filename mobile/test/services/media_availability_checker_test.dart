// ABOUTME: Tests for MediaAvailabilityChecker — HEAD-based 404 confirmation
// ABOUTME: used before permanently removing a video from all feeds.

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openvine/services/media_availability_checker.dart';

void main() {
  group(MediaAvailabilityChecker, () {
    group('isConfirmedMissing', () {
      test('returns true when HEAD returns 404', () async {
        final client = MockClient((request) async {
          expect(request.method, equals('HEAD'));
          return http.Response('', 404);
        });
        final checker = MediaAvailabilityChecker(client: client);

        final result = await checker.isConfirmedMissing(
          'https://example.com/missing.mp4',
        );

        expect(result, isTrue);
      });

      test('returns false when HEAD returns 200', () async {
        final client = MockClient((_) async => http.Response('', 200));
        final checker = MediaAvailabilityChecker(client: client);

        final result = await checker.isConfirmedMissing(
          'https://example.com/ok.mp4',
        );

        expect(result, isFalse);
      });

      test('returns false when HEAD returns 500', () async {
        final client = MockClient((_) async => http.Response('', 500));
        final checker = MediaAvailabilityChecker(client: client);

        final result = await checker.isConfirmedMissing(
          'https://example.com/flaky.mp4',
        );

        expect(result, isFalse);
      });

      test('returns false on network exception', () async {
        final client = MockClient(
          (_) async => throw http.ClientException('timeout'),
        );
        final checker = MediaAvailabilityChecker(client: client);

        final result = await checker.isConfirmedMissing(
          'https://example.com/slow.mp4',
        );

        expect(result, isFalse);
      });

      test('returns false for empty URL without hitting the client', () async {
        var calls = 0;
        final client = MockClient((_) async {
          calls++;
          return http.Response('', 404);
        });
        final checker = MediaAvailabilityChecker(client: client);

        final result = await checker.isConfirmedMissing('');

        expect(result, isFalse);
        expect(calls, equals(0));
      });
    });
  });
}
