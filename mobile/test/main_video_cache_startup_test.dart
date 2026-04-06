import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/main.dart' as app;

void main() {
  group('configureVideoPlayerCacheForStartup', () {
    test('skips cache configuration on web', () async {
      var invoked = false;

      await app.configureVideoPlayerCacheForStartup(
        isWeb: true,
        configureCache: () async {
          invoked = true;
        },
      );

      expect(invoked, isFalse);
    });

    test('configures cache on native platforms', () async {
      var invoked = false;

      await app.configureVideoPlayerCacheForStartup(
        isWeb: false,
        configureCache: () async {
          invoked = true;
        },
      );

      expect(invoked, isTrue);
    });
  });
}
