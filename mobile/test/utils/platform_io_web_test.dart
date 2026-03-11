import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/platform_io_web.dart' as io;

void main() {
  group('platform_io_web', () {
    test('exposes a web-safe Platform API', () {
      expect(io.Platform.isAndroid, isFalse);
      expect(io.Platform.isIOS, isFalse);
      expect(io.Platform.isMacOS, isFalse);
      expect(io.Platform.isWindows, isFalse);
      expect(io.Platform.isLinux, isFalse);
      expect(io.Platform.operatingSystem, 'web');
    });

    test('returns null when parsing internet addresses on web', () {
      expect(io.InternetAddress.tryParse('1.1.1.1'), isNull);
    });
  });
}
