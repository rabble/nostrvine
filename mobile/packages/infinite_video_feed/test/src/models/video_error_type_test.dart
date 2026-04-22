import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/src/models/video_error_type.dart';

void main() {
  group(VideoErrorType, () {
    test('has 4 values', () {
      expect(VideoErrorType.values, hasLength(4));
    });

    test('contains ageRestricted', () {
      expect(VideoErrorType.values, contains(VideoErrorType.ageRestricted));
    });

    test('contains forbidden', () {
      expect(VideoErrorType.values, contains(VideoErrorType.forbidden));
    });

    test('contains notFound', () {
      expect(VideoErrorType.values, contains(VideoErrorType.notFound));
    });

    test('contains generic', () {
      expect(VideoErrorType.values, contains(VideoErrorType.generic));
    });
  });
}
