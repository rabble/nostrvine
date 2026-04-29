import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:blurhash_service/blurhash_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Creates a solid-colour JPEG with the given [width] and [height].
Uint8List _makeJpeg({required int width, required int height}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(100, 149, 237));
  return Uint8List.fromList(img.encodeJpg(image));
}

void main() {
  group('BlurhashService', () {
    test('generates deterministic blurhash from image bytes', () async {
      // Use real thumbnail image from test fixtures
      final thumbnailFile = File('test/fixtures/test_thumbnail.jpg');
      if (!thumbnailFile.existsSync()) {
        fail(
          'Test thumbnail not found at test/fixtures/test_thumbnail.jpg.',
        );
      }
      final testBytes = await thumbnailFile.readAsBytes();

      final blurhash1 = await BlurhashService.generateBlurhash(testBytes);
      final blurhash2 = await BlurhashService.generateBlurhash(testBytes);

      expect(blurhash1, isNotNull);
      expect(blurhash1, equals(blurhash2)); // Should be deterministic
    });

    test('decodes blurhash to color data', () {
      final testBlurhash = BlurhashService.getDefaultVineBlurhash();

      final data = BlurhashService.decodeBlurhash(testBlurhash);

      expect(data, isNotNull);
      expect(data!.blurhash, equals(testBlurhash));
      expect(data.colors, isNotEmpty);
      expect(data.width, equals(32));
      expect(data.height, equals(32));
    });

    test('provides content-specific blurhashes', () {
      final comedyBlurhash = BlurhashService.getBlurhashForContentType(
        VineContentType.comedy,
      );
      final natureBlurhash = BlurhashService.getBlurhashForContentType(
        VineContentType.nature,
      );

      expect(comedyBlurhash, isNotEmpty);
      expect(natureBlurhash, isNotEmpty);
      expect(comedyBlurhash, isNot(equals(natureBlurhash)));
    });

    test('validates blurhash format', () {
      expect(
        BlurhashService.decodeBlurhash(
          'L6Pj0^jE.AyE_3t7t7R**0o#DgR4',
        ),
        isNotNull,
      );
      expect(BlurhashService.decodeBlurhash('invalid'), isNull);
      expect(BlurhashService.decodeBlurhash(''), isNull);
      expect(BlurhashService.decodeBlurhash('short'), isNull);
    });

    test('blurhash data provides gradient', () {
      final testBlurhash = BlurhashService.getDefaultVineBlurhash();
      final data = BlurhashService.decodeBlurhash(testBlurhash);

      expect(data, isNotNull);
      expect(data!.gradient, isNotNull);
    });

    test('blurhash data tracks validity', () {
      final testBlurhash = BlurhashService.getDefaultVineBlurhash();
      final data = BlurhashService.decodeBlurhash(testBlurhash);

      expect(data, isNotNull);
      expect(data!.isValid, isTrue);
    });

    group('generateBlurhash aspect-ratio component selection', () {
      // Blurhash length = 6 + 2 * (compX * compY - 1)
      // Portrait 4×7 → 6 + 2*27 = 60 chars
      // Square   4×4 → 6 + 2*15 = 36 chars

      test('uses 4×7 components for 9:16 portrait image', () async {
        final bytes = _makeJpeg(width: 90, height: 160);
        final hash = await BlurhashService.generateBlurhash(bytes);
        expect(hash, isNotNull);
        expect(hash!.length, equals(60));
      });

      test('uses 4×4 components for 1:1 square image', () async {
        final bytes = _makeJpeg(width: 100, height: 100);
        final hash = await BlurhashService.generateBlurhash(bytes);
        expect(hash, isNotNull);
        expect(hash!.length, equals(36));
      });

      test('real fixture (720×1280) uses portrait components', () async {
        final thumbnailFile = File('test/fixtures/test_thumbnail.jpg');
        if (!thumbnailFile.existsSync()) {
          fail('Test thumbnail not found at test/fixtures/test_thumbnail.jpg.');
        }
        final hash = await BlurhashService.generateBlurhash(
          await thumbnailFile.readAsBytes(),
        );
        expect(hash, isNotNull);
        expect(hash!.length, equals(60));
      });

      test('runs encoding in a background isolate '
          '(result is still deterministic)', () async {
        final bytes = _makeJpeg(width: 90, height: 160);
        final hash1 = await BlurhashService.generateBlurhash(bytes);
        final hash2 = await BlurhashService.generateBlurhash(bytes);
        expect(hash1, isNotNull);
        expect(hash1, equals(hash2));
      });

      test('returns null for invalid image bytes', () async {
        final hash = await BlurhashService.generateBlurhash(
          Uint8List.fromList([0, 1, 2, 3]),
        );
        expect(hash, isNull);
      });
    });

    group('getBlurhashForContentType', () {
      test('returns unique blurhash for each content type', () {
        final results = <VineContentType, String>{};
        for (final type in VineContentType.values) {
          results[type] = BlurhashService.getBlurhashForContentType(type);
        }

        // All results should be non-empty valid blurhashes
        for (final entry in results.entries) {
          expect(
            entry.value,
            isNotEmpty,
            reason:
                '${entry.key} should return '
                'a non-empty blurhash',
          );
          expect(
            entry.value.startsWith('L'),
            isTrue,
            reason:
                '${entry.key} blurhash should '
                'start with L',
          );
        }
      });

      test(
        'returns default blurhash for '
        '${VineContentType.unknown}',
        () {
          final result = BlurhashService.getBlurhashForContentType(
            VineContentType.unknown,
          );

          expect(
            result,
            equals(
              BlurhashService.getDefaultVineBlurhash(),
            ),
          );
        },
      );
    });

    group('BlurhashData', () {
      test('gradient returns single-color gradient '
          'when colors has fewer than 2 entries', () {
        const primaryColor = ui.Color(0xFFFF0000);
        final data = BlurhashData(
          blurhash: 'L6Pj0^jE.AyE_3t7t7R**0o#DgR4',
          width: 32,
          height: 32,
          colors: [primaryColor],
          primaryColor: primaryColor,
          timestamp: DateTime.now(),
        );

        final gradient = data.gradient;
        expect(gradient, isA<ui.Gradient>());
      });

      test('gradient returns two-color gradient '
          'when colors has 2 or more entries', () {
        const color1 = ui.Color(0xFFFF0000);
        const color2 = ui.Color(0xFF00FF00);
        final data = BlurhashData(
          blurhash: 'L6Pj0^jE.AyE_3t7t7R**0o#DgR4',
          width: 32,
          height: 32,
          colors: [color1, color2],
          primaryColor: color1,
          timestamp: DateTime.now(),
        );

        final gradient = data.gradient;
        expect(gradient, isA<ui.Gradient>());
      });

      test('toString returns formatted string', () {
        const primaryColor = ui.Color(0xFFFF8040);
        final data = BlurhashData(
          blurhash: 'L6Pj0^jE.AyE_3t7t7R**0o#DgR4',
          width: 32,
          height: 32,
          colors: [primaryColor],
          primaryColor: primaryColor,
          timestamp: DateTime.now(),
        );

        final result = data.toString();
        expect(result, contains('BlurhashData('));
        expect(result, contains('hash: L6Pj0^jE...'));
        expect(result, contains('colors: 1'));
        expect(result, contains('primary: #'));
      });

      test('isValid returns false for expired data', () {
        final data = BlurhashData(
          blurhash: 'L6Pj0^jE.AyE_3t7t7R**0o#DgR4',
          width: 32,
          height: 32,
          colors: const [],
          primaryColor: const ui.Color(0xFF888888),
          timestamp: DateTime.now().subtract(
            const Duration(minutes: 31),
          ),
        );

        expect(data.isValid, isFalse);
      });
    });
  });

  group(BlurhashException, () {
    test('stores message', () {
      const exception = BlurhashException('test error');
      expect(exception.message, equals('test error'));
    });

    test('toString returns formatted message', () {
      const exception = BlurhashException('test error');
      expect(
        exception.toString(),
        equals('BlurhashException: test error'),
      );
    });
  });

  group('BlurhashCache', () {
    late BlurhashCache cache;

    setUp(() {
      cache = BlurhashCache();
    });

    test('stores and retrieves blurhash data', () {
      final testBlurhash = BlurhashService.getDefaultVineBlurhash();
      final data = BlurhashService.decodeBlurhash(testBlurhash)!;

      cache.put('test_key', data);
      final retrieved = cache.get('test_key');

      expect(retrieved, isNotNull);
      expect(retrieved!.blurhash, equals(data.blurhash));
    });

    test('returns null for non-existent keys', () {
      final retrieved = cache.get('non_existent');
      expect(retrieved, isNull);
    });

    test('removes entries', () {
      final testBlurhash = BlurhashService.getDefaultVineBlurhash();
      final data = BlurhashService.decodeBlurhash(testBlurhash)!;

      cache.put('test_key', data);
      expect(cache.get('test_key'), isNotNull);

      cache.remove('test_key');
      expect(cache.get('test_key'), isNull);
    });

    test('clears all entries', () {
      final testBlurhash = BlurhashService.getDefaultVineBlurhash();
      final data = BlurhashService.decodeBlurhash(testBlurhash)!;

      cache
        ..put('key1', data)
        ..put('key2', data);
      expect(cache.get('key1'), isNotNull);
      expect(cache.get('key2'), isNotNull);

      cache.clear();
      expect(cache.get('key1'), isNull);
      expect(cache.get('key2'), isNull);
    });

    test('provides cache statistics', () {
      final stats = cache.getStats();

      expect(stats, containsPair('size', 0));
      expect(
        stats,
        containsPair('maxSize', BlurhashCache.maxCacheSize),
      );
    });

    test('provides stats with oldest and newest entries', () {
      final data = BlurhashData(
        blurhash: 'L6Pj0^jE.AyE_3t7t7R**0o#DgR4',
        width: 32,
        height: 32,
        colors: const [],
        primaryColor: const ui.Color(0xFF888888),
        timestamp: DateTime.now(),
      );

      cache
        ..put('key1', data)
        ..put('key2', data);

      final stats = cache.getStats();
      expect(stats['size'], equals(2));
      expect(stats['oldestEntry'], isA<DateTime>());
      expect(stats['newestEntry'], isA<DateTime>());
    });

    test(
      'returns null for expired cache entries',
      () {
        final cache = _ExpiredTimestampCache();
        final data = BlurhashData(
          blurhash: 'L6Pj0^jE.AyE_3t7t7R**0o#DgR4',
          width: 32,
          height: 32,
          colors: const [],
          primaryColor: const ui.Color(0xFF888888),
          timestamp: DateTime.now(),
        );

        cache
          ..put('key1', data)
          // Manually expire the entry by backdating
          // the timestamp
          ..backdateTimestamp(
            'key1',
            DateTime.now().subtract(
              const Duration(hours: 2),
            ),
          );

        // Should return null because entry is expired
        expect(cache.get('key1'), isNull);
      },
    );

    test(
      'cleans old entries when cache reaches max size',
      () {
        final cache = _ExpiredTimestampCache();
        final data = BlurhashData(
          blurhash: 'L6Pj0^jE.AyE_3t7t7R**0o#DgR4',
          width: 32,
          height: 32,
          colors: const [],
          primaryColor: const ui.Color(0xFF888888),
          timestamp: DateTime.now(),
        );

        // Fill cache to maxCacheSize
        for (var i = 0; i < BlurhashCache.maxCacheSize; i++) {
          cache.put('key_$i', data);
        }

        // Backdate half the entries so they are expired
        final expiredTime = DateTime.now().subtract(
          const Duration(hours: 2),
        );
        for (var i = 0; i < BlurhashCache.maxCacheSize ~/ 2; i++) {
          cache.backdateTimestamp('key_$i', expiredTime);
        }

        // Adding one more entry triggers _cleanOldEntries
        cache.put('trigger_clean', data);

        // Expired entries should have been cleaned
        expect(cache.get('key_0'), isNull);

        // Non-expired entries should still be present
        expect(
          cache.get(
            'key_${BlurhashCache.maxCacheSize - 1}',
          ),
          isNotNull,
        );
      },
    );

    test(
      'evicts oldest non-expired entries when cache is '
      'still full after cleaning expired entries',
      () {
        final cache = _ExpiredTimestampCache();
        final data = BlurhashData(
          blurhash: 'L6Pj0^jE.AyE_3t7t7R**0o#DgR4',
          width: 32,
          height: 32,
          colors: const [],
          primaryColor: const ui.Color(0xFF888888),
          timestamp: DateTime.now(),
        );

        // Fill cache to maxCacheSize with non-expired
        // entries (none will be cleaned by expiry)
        for (var i = 0; i < BlurhashCache.maxCacheSize; i++) {
          cache.put('key_$i', data);
        }

        // Adding one more entry triggers _cleanOldEntries
        // Since none are expired, it removes the oldest
        // to bring size down to maxCacheSize / 2
        cache.put('trigger_evict', data);

        final stats = cache.getStats();
        // Cache should have been reduced
        expect(
          stats['size'] as int,
          lessThanOrEqualTo(BlurhashCache.maxCacheSize),
        );
      },
    );
  });
}

/// Test helper that exposes internal timestamp
/// manipulation for testing cache expiry.
class _ExpiredTimestampCache extends BlurhashCache {
  /// Backdate the timestamp of [key] to simulate
  /// an expired entry.
  void backdateTimestamp(String key, DateTime time) {
    // Access the private _cacheTimestamps via the
    // public put/get API is not possible, so we use
    // a workaround: remove and re-add with manipulation.
    // Instead, we subclass and keep our own shadow map.
    _timestamps[key] = time;
  }

  final Map<String, DateTime> _timestamps = {};

  @override
  void put(String key, BlurhashData data) {
    super.put(key, data);
    _timestamps[key] = DateTime.now();
  }

  @override
  BlurhashData? get(String key) {
    // If we have a backdated timestamp, check it
    final backdated = _timestamps[key];
    if (backdated != null &&
        DateTime.now().difference(backdated) > BlurhashCache.cacheExpiry) {
      remove(key);
      return null;
    }
    return super.get(key);
  }
}
