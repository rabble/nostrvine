import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/main.dart' as app;

void main() {
  group('configureVideoPlayerCacheForStartup', () {
    test('skips cache configuration when skip is true', () async {
      var invoked = false;

      await app.configureVideoPlayerCacheForStartup(
        skip: true,
        configureCache: () async {
          invoked = true;
        },
      );

      expect(invoked, isFalse);
    });

    test('configures cache when skip is false', () async {
      var invoked = false;

      await app.configureVideoPlayerCacheForStartup(
        skip: false,
        configureCache: () async {
          invoked = true;
        },
      );

      expect(invoked, isTrue);
    });
  });

  group('disposeVideoPlayersForStartup', () {
    test('skips disposal when skip is true', () async {
      var invoked = false;

      await app.disposeVideoPlayersForStartup(
        skip: true,
        disposeAll: () async {
          invoked = true;
        },
      );

      expect(invoked, isFalse);
    });

    test('disposes players when skip is false', () async {
      var invoked = false;

      await app.disposeVideoPlayersForStartup(
        skip: false,
        disposeAll: () async {
          invoked = true;
        },
      );

      expect(invoked, isTrue);
    });
  });
}
