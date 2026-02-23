import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group(VideoViewsResponse, () {
    group('constructor', () {
      test('creates instance with views', () {
        const response = VideoViewsResponse(views: 1000);

        expect(response.views, equals(1000));
      });

      test('creates instance with zero views', () {
        const response = VideoViewsResponse(views: 0);

        expect(response.views, equals(0));
      });
    });
  });
}
