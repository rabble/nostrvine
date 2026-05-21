import 'package:models/src/engagement_count_parser.dart';
import 'package:test/test.dart';

void main() {
  group('tryParseEngagementCount', () {
    test('returns null for unusable values', () {
      expect(tryParseEngagementCount(null), isNull);
      expect(tryParseEngagementCount(''), isNull);
      expect(tryParseEngagementCount('   '), isNull);
      expect(tryParseEngagementCount(-1), isNull);
      expect(tryParseEngagementCount('2147483647'), isNull);
      expect(tryParseEngagementCount('9223372036854775807'), isNull);
      expect(tryParseEngagementCount('18446744073709551615'), isNull);
    });

    test('returns parsed non-negative counts', () {
      expect(tryParseEngagementCount(0), equals(0));
      expect(tryParseEngagementCount('0'), equals(0));
      expect(tryParseEngagementCount('1,000'), equals(1000));
      expect(tryParseEngagementCount('42.9'), equals(42));
      expect(tryParseEngagementCount(7.8), equals(7));
    });
  });

  group('parseEngagementCount', () {
    test('normalizes unusable values to zero', () {
      expect(parseEngagementCount(null), equals(0));
      expect(parseEngagementCount(''), equals(0));
      expect(parseEngagementCount(-1), equals(0));
      expect(parseEngagementCount('4294967295'), equals(0));
    });

    test('preserves parsed non-negative counts', () {
      expect(parseEngagementCount('0'), equals(0));
      expect(parseEngagementCount('1,000'), equals(1000));
      expect(parseEngagementCount('42.9'), equals(42));
    });
  });
}
