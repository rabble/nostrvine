import 'package:app_update_repository/app_update_repository.dart';
import 'package:test/test.dart';

void main() {
  group('compareVersions', () {
    test('equal versions return 0', () {
      expect(compareVersions('1.0.8', '1.0.8'), equals(0));
    });

    test('older version returns negative', () {
      expect(compareVersions('1.0.4', '1.0.8'), isNegative);
    });

    test('newer version returns positive', () {
      expect(compareVersions('1.0.9', '1.0.8'), isPositive);
    });

    test('compares major version', () {
      expect(compareVersions('2.0.0', '1.9.9'), isPositive);
    });

    test('compares minor version', () {
      expect(compareVersions('1.1.0', '1.0.9'), isPositive);
    });

    test('handles two-part versions', () {
      expect(compareVersions('1.1', '1.0.9'), isPositive);
    });
  });

  group('isOlderThan', () {
    test('returns true when current is older', () {
      expect(isOlderThan('1.0.4', '1.0.8'), isTrue);
    });

    test('returns false when current is equal', () {
      expect(isOlderThan('1.0.8', '1.0.8'), isFalse);
    });

    test('returns false when current is newer', () {
      expect(isOlderThan('1.0.9', '1.0.8'), isFalse);
    });
  });

  group('isBelowMinimum', () {
    test('returns true when below minimum', () {
      expect(isBelowMinimum('1.0.4', '1.0.6'), isTrue);
    });

    test('returns false when at minimum', () {
      expect(isBelowMinimum('1.0.6', '1.0.6'), isFalse);
    });

    test('returns false when above minimum', () {
      expect(isBelowMinimum('1.0.8', '1.0.6'), isFalse);
    });
  });
}
