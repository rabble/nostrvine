import 'package:divine_camera/divine_camera.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(PhotoCaptureResult, () {
    test('creates result with all fields', () {
      const result = PhotoCaptureResult(
        filePath: '/path/to/photo.jpg',
        width: 1080,
        height: 1920,
      );

      expect(result.filePath, '/path/to/photo.jpg');
      expect(result.width, 1080);
      expect(result.height, 1920);
    });

    test('creates result from map', () {
      final map = {
        'filePath': '/path/to/photo.jpg',
        'width': 720,
        'height': 1280,
      };

      final result = PhotoCaptureResult.fromMap(map);

      expect(result.filePath, '/path/to/photo.jpg');
      expect(result.width, 720);
      expect(result.height, 1280);
    });

    test('fromMap tolerates missing dimensions', () {
      final result = PhotoCaptureResult.fromMap(const {
        'filePath': '/path/to/photo.jpg',
      });

      expect(result.filePath, '/path/to/photo.jpg');
      expect(result.width, isNull);
      expect(result.height, isNull);
    });

    test('toMap converts result to map', () {
      const result = PhotoCaptureResult(
        filePath: '/path/to/photo.jpg',
        width: 1080,
        height: 1920,
      );

      final map = result.toMap();

      expect(map['filePath'], '/path/to/photo.jpg');
      expect(map['width'], 1080);
      expect(map['height'], 1920);
    });

    test('file getter returns File object', () {
      const result = PhotoCaptureResult(filePath: '/path/to/photo.jpg');

      expect(result.file.path, '/path/to/photo.jpg');
    });

    test('toString returns formatted string', () {
      const result = PhotoCaptureResult(
        filePath: '/path/to/photo.jpg',
        width: 1080,
        height: 1920,
      );

      final str = result.toString();

      expect(str, contains('PhotoCaptureResult'));
      expect(str, contains('filePath: /path/to/photo.jpg'));
      expect(str, contains('width: 1080'));
      expect(str, contains('height: 1920'));
    });

    test('props returns correct list of properties', () {
      const result = PhotoCaptureResult(
        filePath: '/test.jpg',
        width: 720,
        height: 1280,
      );

      final props = result.props;

      expect(props.length, 3);
      expect(props[0], '/test.jpg');
      expect(props[1], 720);
      expect(props[2], 1280);
    });

    test('equality works correctly', () {
      const result1 = PhotoCaptureResult(filePath: '/test.jpg', width: 720);
      const result2 = PhotoCaptureResult(filePath: '/test.jpg', width: 720);
      const result3 = PhotoCaptureResult(filePath: '/other.jpg', width: 720);

      expect(result1, equals(result2));
      expect(result1, isNot(equals(result3)));
    });
  });
}
