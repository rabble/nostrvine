import 'package:divine_blurhash/divine_blurhash.dart';
import 'package:test/test.dart';

void main() {
  group('BlurHashDecodeException', () {
    test('stores its message', () {
      const exception = BlurHashDecodeException('bad hash');
      expect(exception.message, 'bad hash');
    });

    test('toString prefixes the message', () {
      expect(
        const BlurHashDecodeException('bad hash').toString(),
        'BlurHashDecodeException: bad hash',
      );
    });
  });
}
