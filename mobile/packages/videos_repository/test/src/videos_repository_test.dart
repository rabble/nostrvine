// Not required for test files
// ignore_for_file: prefer_const_constructors
import 'package:test/test.dart';
import 'package:videos_repository/videos_repository.dart';

void main() {
  group('VideosRepository', () {
    test('can be instantiated', () {
      expect(VideosRepository(), isNotNull);
    });
  });
}
