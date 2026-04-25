import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_cache/media_cache.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

void main() {
  group('openVineImageCache', () {
    test('is a $MediaCacheManager', () {
      expect(openVineImageCache, isA<MediaCacheManager>());
    });

    test('uses image config with correct cache key', () {
      expect(
        openVineImageCache.mediaConfig.cacheKey,
        equals('openvine_image_cache'),
      );
    });

    test('uses 7-day stale period from image preset', () {
      expect(
        openVineImageCache.mediaConfig.stalePeriod,
        equals(const Duration(days: 7)),
      );
    });

    test('limits to 200 cache objects', () {
      expect(openVineImageCache.mediaConfig.maxNrOfCacheObjects, equals(200));
    });
  });

  group(VineCachedImage, () {
    const testUrl = 'https://example.com/image.jpg';

    testWidgets('renders $CachedNetworkImage with correct imageUrl', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: VineCachedImage(imageUrl: testUrl),
        ),
      );

      expect(find.byType(CachedNetworkImage), findsOneWidget);

      final cached = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(cached.imageUrl, equals(testUrl));
    });

    testWidgets('uses openVineImageCache as cacheManager', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: VineCachedImage(imageUrl: testUrl),
        ),
      );

      final cached = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(cached.cacheManager, equals(openVineImageCache));
    });

    testWidgets('defaults fit to BoxFit.cover', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: VineCachedImage(imageUrl: testUrl),
        ),
      );

      final cached = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(cached.fit, equals(BoxFit.cover));
    });

    testWidgets('defaults alignment to Alignment.center', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: VineCachedImage(imageUrl: testUrl),
        ),
      );

      final cached = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(cached.alignment, equals(Alignment.center));
    });

    testWidgets('passes width and height through', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: VineCachedImage(imageUrl: testUrl, width: 100, height: 200),
        ),
      );

      final cached = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(cached.width, equals(100));
      expect(cached.height, equals(200));
    });

    testWidgets('passes fit and alignment through', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: VineCachedImage(
            imageUrl: testUrl,
            fit: BoxFit.contain,
            alignment: Alignment.topCenter,
          ),
        ),
      );

      final cached = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(cached.fit, equals(BoxFit.contain));
      expect(cached.alignment, equals(Alignment.topCenter));
    });

    testWidgets('passes memCacheWidth and memCacheHeight through', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: VineCachedImage(
            imageUrl: testUrl,
            memCacheWidth: 256,
            memCacheHeight: 512,
          ),
        ),
      );

      final cached = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(cached.memCacheWidth, equals(256));
      expect(cached.memCacheHeight, equals(512));
    });

    testWidgets('defaults fadeInDuration to 500ms', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: VineCachedImage(imageUrl: testUrl),
        ),
      );

      final cached = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(cached.fadeInDuration, equals(const Duration(milliseconds: 500)));
    });

    testWidgets('defaults fadeOutDuration to 1000ms', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: VineCachedImage(imageUrl: testUrl),
        ),
      );

      final cached = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(
        cached.fadeOutDuration,
        equals(const Duration(milliseconds: 1000)),
      );
    });

    testWidgets('passes fadeInDuration and fadeOutDuration through', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: VineCachedImage(
            imageUrl: testUrl,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration(milliseconds: 200),
          ),
        ),
      );

      final cached = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(cached.fadeInDuration, equals(Duration.zero));
      expect(cached.fadeOutDuration, equals(const Duration(milliseconds: 200)));
    });
  });
}
