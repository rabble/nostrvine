import 'package:test/test.dart';
import 'package:time_formatter/time_formatter.dart';

void main() {
  group('EpochSecondsToDateTime', () {
    test('zero seconds maps to the Unix epoch in UTC', () {
      final dt = 0.toDateTimeFromEpochSeconds();
      expect(dt, equals(DateTime.utc(1970)));
    });

    test('returned DateTime is UTC', () {
      expect(0.toDateTimeFromEpochSeconds().isUtc, isTrue);
      expect(1700000000.toDateTimeFromEpochSeconds().isUtc, isTrue);
    });

    test('known timestamp 1700000000 maps to expected UTC datetime', () {
      // 2023-11-14T22:13:20Z
      final dt = 1700000000.toDateTimeFromEpochSeconds();
      expect(dt, equals(DateTime.utc(2023, 11, 14, 22, 13, 20)));
    });

    test('negative seconds return pre-epoch UTC datetime', () {
      // -86400 seconds == one day before the epoch
      final dt = (-86400).toDateTimeFromEpochSeconds();
      expect(dt, equals(DateTime.utc(1969, 12, 31)));
    });
  });

  group('DateTimeToEpochSeconds', () {
    test('UTC epoch returns 0', () {
      expect(DateTime.utc(1970).toEpochSeconds(), equals(0));
    });

    test('known UTC datetime returns expected epoch seconds', () {
      expect(
        DateTime.utc(2023, 11, 14, 22, 13, 20).toEpochSeconds(),
        equals(1700000000),
      );
    });

    test('truncates sub-second milliseconds', () {
      // 1500ms past epoch -> 1 epoch second (not 2 — confirms `~/`, not round)
      final dt = DateTime.fromMillisecondsSinceEpoch(1500, isUtc: true);
      expect(dt.toEpochSeconds(), equals(1));
    });

    test('local datetime returns the same epoch seconds as its UTC value', () {
      // millisecondsSinceEpoch is timezone-agnostic, so the extension
      // must return the same int regardless of the DateTime's `isUtc`.
      final utc = DateTime.utc(2023, 11, 14, 22, 13, 20);
      expect(utc.toLocal().toEpochSeconds(), equals(utc.toEpochSeconds()));
    });
  });

  group('round-trip', () {
    test('epoch seconds -> DateTime -> epoch seconds is identity', () {
      const samples = [0, 1, 1700000000, -86400, 2147483647];
      for (final s in samples) {
        expect(
          s.toDateTimeFromEpochSeconds().toEpochSeconds(),
          equals(s),
          reason: 'round-trip failed for $s',
        );
      }
    });
  });
}
