import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/byte_size_format.dart';

void main() {
  group('formatByteSize', () {
    test('keeps raw bytes below one kilobyte', () {
      expect(formatByteSize(0), '0 B');
      expect(formatByteSize(1023), '1023 B');
    });

    test('steps up a unit every 1024', () {
      expect(formatByteSize(1024), '1.0 KB');
      expect(formatByteSize(1024 * 1024), '1.0 MB');
      expect(formatByteSize(1024 * 1024 * 1024), '1.0 GB');
      expect(formatByteSize(1024 * 1024 * 1024 * 1024), '1.0 TB');
    });

    test('drops the fraction from ten upwards to keep sizes column-width', () {
      expect(formatByteSize(9 * 1024 * 1024), '9.0 MB');
      expect(formatByteSize(42 * 1024 * 1024), '42 MB');
    });

    test('saturates at terabytes rather than inventing a unit', () {
      expect(formatByteSize(4096 * 1024 * 1024 * 1024), '4.0 TB');
    });
  });
}
