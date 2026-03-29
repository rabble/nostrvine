import 'package:count_formatter/count_formatter.dart';
import 'package:test/test.dart';

void main() {
  group(CountFormatter, () {
    group('formatCompact', () {
      group('below 1000', () {
        test('returns "0" for 0', () {
          expect(CountFormatter.formatCompact(0), equals('0'));
        });

        test('returns the number as-is for 999', () {
          expect(CountFormatter.formatCompact(999), equals('999'));
        });

        test('accepts string input', () {
          expect(CountFormatter.formatCompact('42'), equals('42'));
        });

        test('returns "0" for unparseable string', () {
          expect(CountFormatter.formatCompact('abc'), equals('0'));
        });
      });

      group('thousands (1k–999k)', () {
        test('returns "1k" for 1000', () {
          expect(CountFormatter.formatCompact(1000), equals('1k'));
        });

        test('returns "1.2k" for 1200', () {
          expect(CountFormatter.formatCompact(1200), equals('1.2k'));
        });

        test('returns "10k" for 10000', () {
          expect(CountFormatter.formatCompact(10000), equals('10k'));
        });

        test('returns "999k" for 999000', () {
          expect(CountFormatter.formatCompact(999000), equals('999k'));
        });

        test('rounds to 1 decimal place for 1500', () {
          expect(CountFormatter.formatCompact(1500), equals('1.5k'));
        });

        test('omits decimal when whole number for 2000', () {
          expect(CountFormatter.formatCompact(2000), equals('2k'));
        });
      });

      group('boundary near 1m (999950 threshold)', () {
        test('returns "999.9k" for 999900', () {
          expect(CountFormatter.formatCompact(999900), equals('999.9k'));
        });

        test('returns "1m" for 999950 (rounds up to 1m)', () {
          expect(CountFormatter.formatCompact(999950), equals('1m'));
        });
      });

      group('millions (1m+)', () {
        test('returns "1m" for 1000000', () {
          expect(CountFormatter.formatCompact(1000000), equals('1m'));
        });

        test('returns "1.2m" for 1200000', () {
          expect(CountFormatter.formatCompact(1200000), equals('1.2m'));
        });

        test('returns "3m" for 3000000', () {
          expect(CountFormatter.formatCompact(3000000), equals('3m'));
        });

        test('returns "10m" for 10000000', () {
          expect(CountFormatter.formatCompact(10000000), equals('10m'));
        });

        test('omits decimal when whole number for 5000000', () {
          expect(CountFormatter.formatCompact(5000000), equals('5m'));
        });

        test('rounds to 1 decimal place for 1500000', () {
          expect(CountFormatter.formatCompact(1500000), equals('1.5m'));
        });
      });
    });
  });
}
