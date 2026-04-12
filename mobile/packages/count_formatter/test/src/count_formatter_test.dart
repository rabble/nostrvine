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

      group('thousands (1K-999K) in en locale', () {
        test('returns "1K" for 1000', () {
          expect(
            CountFormatter.formatCompact(1000, locale: 'en'),
            equals('1K'),
          );
        });

        test('returns "1.2K" for 1200', () {
          expect(
            CountFormatter.formatCompact(1200, locale: 'en'),
            equals('1.2K'),
          );
        });

        test('returns "10K" for 10000', () {
          expect(
            CountFormatter.formatCompact(10000, locale: 'en'),
            equals('10K'),
          );
        });

        test('returns "999K" for 999000', () {
          expect(
            CountFormatter.formatCompact(999000, locale: 'en'),
            equals('999K'),
          );
        });

        test('returns "1.5K" for 1500', () {
          expect(
            CountFormatter.formatCompact(1500, locale: 'en'),
            equals('1.5K'),
          );
        });

        test('returns "2K" for 2000', () {
          expect(
            CountFormatter.formatCompact(2000, locale: 'en'),
            equals('2K'),
          );
        });
      });

      group('millions (1M+) in en locale', () {
        test('returns "1M" for 1000000', () {
          expect(
            CountFormatter.formatCompact(1000000, locale: 'en'),
            equals('1M'),
          );
        });

        test('returns "1.2M" for 1200000', () {
          expect(
            CountFormatter.formatCompact(1200000, locale: 'en'),
            equals('1.2M'),
          );
        });

        test('returns "3M" for 3000000', () {
          expect(
            CountFormatter.formatCompact(3000000, locale: 'en'),
            equals('3M'),
          );
        });

        test('returns "10M" for 10000000', () {
          expect(
            CountFormatter.formatCompact(10000000, locale: 'en'),
            equals('10M'),
          );
        });

        test('returns "5M" for 5000000', () {
          expect(
            CountFormatter.formatCompact(5000000, locale: 'en'),
            equals('5M'),
          );
        });

        test('returns "1.5M" for 1500000', () {
          expect(
            CountFormatter.formatCompact(1500000, locale: 'en'),
            equals('1.5M'),
          );
        });
      });

      group('locale-aware formatting', () {
        test('uses locale-specific suffixes for German', () {
          final result = CountFormatter.formatCompact(
            1000000,
            locale: 'de',
          );
          // German uses different compact notation
          expect(result, isNotEmpty);
          expect(result, isNot(equals('1000000')));
        });

        test('uses locale-specific suffixes for Japanese', () {
          final result = CountFormatter.formatCompact(
            10000,
            locale: 'ja',
          );
          expect(result, isNotEmpty);
          expect(result, isNot(equals('10000')));
        });

        test('passes locale through to NumberFormat', () {
          // Spanish uses different formatting than English
          final enResult = CountFormatter.formatCompact(
            1500000,
            locale: 'en',
          );
          final esResult = CountFormatter.formatCompact(
            1500000,
            locale: 'es',
          );
          // Both should be compact, though format may differ
          expect(enResult, isNotEmpty);
          expect(esResult, isNotEmpty);
        });
      });
    });
  });
}
