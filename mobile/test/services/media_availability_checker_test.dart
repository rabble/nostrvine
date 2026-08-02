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

      // The 401 age gate must not read as "missing": blossom serves
      // AgeRestricted blobs to any authenticated request, so a caller that
      // pruned on this would hide viewable content. See #5953 / #6251.
      test('returns false for the 401 age gate', () async {
        final client = MockClient((_) async => http.Response('', 401));
        final checker = MediaAvailabilityChecker(client: client);

        expect(
          await checker.isConfirmedMissing('https://example.com/gated.mp4'),
          isFalse,
        );
      });
    });

    group('check', () {
      Future<MediaAvailability> classify(int status) async {
        final client = MockClient((request) async {
          expect(request.method, equals('HEAD'));
          return http.Response('', status);
        });
        return MediaAvailabilityChecker(
          client: client,
        ).check('https://example.com/video.mp4');
      }

      test('maps success statuses to available', () async {
        expect(await classify(200), MediaAvailability.available);
        expect(await classify(206), MediaAvailability.available);
      });

      test('maps 404 to missing', () async {
        expect(await classify(404), MediaAvailability.missing);
      });

      test('maps 401 and 403 to authRequired', () async {
        expect(await classify(401), MediaAvailability.authRequired);
        expect(await classify(403), MediaAvailability.authRequired);
      });

      test('maps other statuses to unknown', () async {
        expect(await classify(500), MediaAvailability.unknown);
        expect(await classify(429), MediaAvailability.unknown);
      });

      test('maps a network exception to unknown', () async {
        final client = MockClient(
          (_) async => throw http.ClientException('timeout'),
        );

        expect(
          await MediaAvailabilityChecker(
            client: client,
          ).check('https://example.com/slow.mp4'),
          MediaAvailability.unknown,
        );
      });

      test('maps an empty URL to unknown without hitting the client', () async {
        var calls = 0;
        final client = MockClient((_) async {
          calls++;
          return http.Response('', 404);
        });

        expect(
          await MediaAvailabilityChecker(client: client).check(''),
          MediaAvailability.unknown,
        );
        expect(calls, equals(0));
      });
    });
  });
}
