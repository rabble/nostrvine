// ABOUTME: Unit coverage for DmClock, the one-sided bound applied to
// ABOUTME: self-asserted DM `created_at` values on both ingest paths.

import 'package:dm_repository/src/dm_clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(DmClock, () {
    const nowSeconds = 1700000000;

    group('atMostNow', () {
      test('passes an honestly-dated timestamp through unchanged', () {
        expect(
          DmClock(nowSeconds).atMostNow(nowSeconds - 3600),
          equals(nowSeconds - 3600),
        );
      });

      test('passes a timestamp equal to now through unchanged', () {
        expect(DmClock(nowSeconds).atMostNow(nowSeconds), nowSeconds);
      });

      test('bounds a timestamp one second into the future', () {
        expect(DmClock(nowSeconds).atMostNow(nowSeconds + 1), nowSeconds);
      });

      test('bounds a far-future timestamp to now', () {
        // Year 2100.
        expect(DmClock(nowSeconds).atMostNow(4102444800), nowSeconds);
      });

      test('does not raise an implausibly old timestamp', () {
        // The bound is one-sided: the history-drain floor is a separate
        // defence and must not be applied here.
        expect(DmClock(nowSeconds).atMostNow(1), equals(1));
      });
    });

    test('now() pins to the local wall clock', () {
      final before = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final clock = DmClock.now();
      final after = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      expect(clock.nowSeconds, inInclusiveRange(before, after));
    });
  });
}
