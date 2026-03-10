import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_cache/media_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MediaCacheManager on web', () {
    test(
      'can be instantiated without native IO dependencies',
      () {
        expect(kIsWeb, isTrue);

        expect(
          () => MediaCacheManager(
            config: const MediaCacheConfig.video(cacheKey: 'web_video_cache'),
          ),
          returnsNormally,
        );
      },
      skip: !kIsWeb,
    );

    test(
      'initializes without touching file-backed manifest storage',
      () async {
        expect(kIsWeb, isTrue);

        final cacheManager = MediaCacheManager(
          config: const MediaCacheConfig.video(cacheKey: 'web_video_cache'),
        );

        await expectLater(cacheManager.initialize(), completes);
        expect(cacheManager.isInitialized, isTrue);
        expect(cacheManager.getCachedFileSync('missing-video'), isNull);
      },
      skip: !kIsWeb,
    );
  });
}
