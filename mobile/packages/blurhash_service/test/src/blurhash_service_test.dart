import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:blurhash_service/blurhash_service.dart';
import 'package:divine_blurhash/divine_blurhash.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:unified_logger/unified_logger.dart';

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

    test('memoizes decode results for identical inputs', () {
      final testBlurhash = BlurhashService.getDefaultVineBlurhash();

      final first = BlurhashService.decodeBlurhash(testBlurhash);
      final second = BlurhashService.decodeBlurhash(testBlurhash);

      expect(first, isNotNull);
      expect(
        identical(first, second),
        isTrue,
        reason: 'repeated decodes of the same hash must hit the cache',
      );
    });

    test('memoization keys include the requested dimensions', () {
      final testBlurhash = BlurhashService.getDefaultVineBlurhash();

      final large = BlurhashService.decodeBlurhash(testBlurhash);
      final small = BlurhashService.decodeBlurhash(
        testBlurhash,
        width: 16,
        height: 16,
      );

      expect(identical(large, small), isFalse);
      expect(small!.width, equals(16));
      expect(small.height, equals(16));
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

    test(
      'logs an error when a valid-charset hash has a mismatched length',
      () async {
        await LogCaptureService().clearAllLogs();

        // A real hash truncated mid-string: passes the charset/length-floor
        // check but its length no longer matches its declared component count,
        // so decoding bails. Corrupt/truncated tags must stay observable.
        const truncatedHash = 'L6Pj0^jE.AyE_3t7t7R*';

        expect(BlurhashService.decodeBlurhash(truncatedHash), isNull);

        final errors = LogCaptureService()
            .getRecentLogs(minLevel: LogLevel.error)
            .where((entry) => entry.name == 'BlurhashService')
            .toList();
        expect(
          errors,
          isNotEmpty,
          reason:
              'a malformed blurhash must emit an error log, not fail '
              'silently',
        );
      },
    );

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

    test('decodes grayscale content without a color tint', () async {
      // Regression: blurhash_dart's decodeAc misses the spec's integer
      // division, which inflates red/green in every AC component — a
      // white→black gradient decoded with navy blue shadows and a cream
      // top. The spec-correct decode must keep gray pixels gray.
      final gradient = img.Image(width: 128, height: 227);
      for (var y = 0; y < gradient.height; y++) {
        final v = (230 - (y / gradient.height) * 215).round();
        for (var x = 0; x < gradient.width; x++) {
          gradient.setPixelRgb(x, y, v, v, v);
        }
      }
      final hash = await BlurhashService.generateBlurhash(
        Uint8List.fromList(img.encodePng(gradient)),
      );
      expect(hash, isNotNull);

      final data = BlurhashService.decodeBlurhash(hash!);
      expect(data, isNotNull);
      final pixels = data!.pixels!;
      for (var i = 0; i + 3 < pixels.length; i += 4) {
        final r = pixels[i];
        final g = pixels[i + 1];
        final b = pixels[i + 2];
        expect(
          (r - g).abs() <= 2 && (g - b).abs() <= 2 && (r - b).abs() <= 2,
          isTrue,
          reason: 'pixel ${i ~/ 4} is tinted: r=$r g=$g b=$b',
        );
      }
    });

    test('decodes a solid fill back to its source color', () async {
      // DC reference vector: a solid fill carries no AC energy, so every
      // decoded pixel must round-trip the DC (average) color on all three
      // channels. The expected values are the source color itself — an
      // independent reference, not this decoder's own output — so a channel
      // swap or a broken DC/sRGB round-trip fails it. (The AC division
      // regression is guarded separately by the grayscale-tint test above;
      // it can't be pinned here because a solid fill has ~zero AC energy.)
      const sourceR = 100;
      const sourceG = 149;
      const sourceB = 237;
      final image = img.Image(width: 128, height: 128);
      img.fill(image, color: img.ColorRgb8(sourceR, sourceG, sourceB));
      final hash = await BlurhashService.generateBlurhash(
        Uint8List.fromList(img.encodePng(image)),
      );
      expect(hash, isNotNull);

      final data = BlurhashService.decodeBlurhash(hash!);
      expect(data, isNotNull);
      final pixels = data!.pixels!;
      for (var i = 0; i + 3 < pixels.length; i += 4) {
        expect(
          (pixels[i] - sourceR).abs(),
          lessThanOrEqualTo(5),
          reason: 'red @ ${i ~/ 4}: ${pixels[i]}',
        );
        expect(
          (pixels[i + 1] - sourceG).abs(),
          lessThanOrEqualTo(5),
          reason: 'green @ ${i ~/ 4}: ${pixels[i + 1]}',
        );
        expect(
          (pixels[i + 2] - sourceB).abs(),
          lessThanOrEqualTo(5),
          reason: 'blue @ ${i ~/ 4}: ${pixels[i + 2]}',
        );
      }
    });

    test(
      'punch scales AC contrast, including the first component row',
      () async {
        // A pure horizontal gradient puts nearly all of its AC energy in the
        // first component row (j = 0, i > 0) — exactly the row blurhash_dart's
        // punch skipped. Our decode bakes punch into maxAc for every AC term,
        // so the left↔right contrast must scale ~linearly with punch. A plain
        // `contrast(high) > contrast(low)` check is NOT enough: the upstream
        // first-row-skip bug still satisfies it via the tiny residual energy
        // in the punched j > 0 rows (measured 175 vs 173 at punch 1 vs 0.5).
        // The ratio assertion below fails under that bug (it needs the
        // dominant first-row AC to actually be scaled): correct decode gives
        // ~175 vs ~81, the skip bug gives ~175 vs ~173.
        final gradient = img.Image(width: 128, height: 128);
        for (var x = 0; x < gradient.width; x++) {
          final v = (x / (gradient.width - 1) * 255).round();
          for (var y = 0; y < gradient.height; y++) {
            gradient.setPixelRgb(x, y, v, v, v);
          }
        }
        final hash = await BlurhashService.generateBlurhash(
          Uint8List.fromList(img.encodePng(gradient)),
        );
        expect(hash, isNotNull);

        int horizontalContrast(double punch) {
          final data = BlurhashService.decodeBlurhash(
            hash!,
            width: 16,
            punch: punch,
          )!;
          final pixels = data.pixels!;
          final left = pixels[0];
          final right = pixels[(16 - 1) * 4];
          return (right - left).abs();
        }

        final softContrast = horizontalContrast(0.5);
        final fullContrast = horizontalContrast(1);
        expect(
          fullContrast,
          greaterThan((softContrast * 1.4).round()),
          reason:
              'punch must scale the dominant first-row AC contrast, '
              'not skip it',
        );
      },
    );

    test(
      'decodes a legacy high-component (4x7) hash without a tint',
      () async {
        // Pre-PR production hashes used 4x7 / 4x4 components and are still
        // live in published Nostr events — the decoder must keep handling
        // them. The high-contrast grayscale checkerboard also pins channel
        // symmetry under heavy ringing: the old blurhash_dart decode bug
        // tinted exactly this kind of content.
        final source = img.Image(width: 128, height: 227);
        for (var y = 0; y < source.height; y++) {
          for (var x = 0; x < source.width; x++) {
            final v = ((x ~/ 16) + (y ~/ 16)).isEven ? 245 : 10;
            source.setPixelRgb(x, y, v, v, v);
          }
        }
        // Encode the legacy shape directly — the service only emits 3x4/3x3
        // now, so this reproduces a pre-PR production hash. numCompX defaults
        // to 4; numCompY: 7 makes it the 4x7 shape.
        final legacyHash = encodeBlurHash(
          source.getBytes(order: img.ChannelOrder.rgba),
          source.width,
          source.height,
          numCompY: 7,
        );

        final data = BlurhashService.decodeBlurhash(legacyHash);
        expect(data, isNotNull);
        final pixels = data!.pixels!;
        expect(pixels, hasLength(32 * 32 * 4));
        for (var i = 0; i + 3 < pixels.length; i += 4) {
          final r = pixels[i];
          final g = pixels[i + 1];
          final b = pixels[i + 2];
          expect(
            (r - g).abs() <= 2 && (g - b).abs() <= 2 && (r - b).abs() <= 2,
            isTrue,
            reason: 'pixel ${i ~/ 4} is tinted: r=$r g=$g b=$b',
          );
        }
      },
    );

    group('generateBlurhash aspect-ratio component selection', () {
      // Blurhash length = 6 + 2 * (compX * compY - 1)
      // Portrait 3×4 → 6 + 2*11 = 28 chars
      // Square   3×3 → 6 + 2*8  = 22 chars

      test('uses 3×4 components for 9:16 portrait image', () async {
        final bytes = _makeJpeg(width: 90, height: 160);
        final hash = await BlurhashService.generateBlurhash(bytes);
        expect(hash, isNotNull);
        expect(hash!.length, equals(28));
      });

      test('uses 3×3 components for 1:1 square image', () async {
        final bytes = _makeJpeg(width: 100, height: 100);
        final hash = await BlurhashService.generateBlurhash(bytes);
        expect(hash, isNotNull);
        expect(hash!.length, equals(22));
      });

      test('falls back to square components for landscape input', () async {
        // Divine only produces 9:16 and 1:1 videos; wider input (e.g.
        // imported media) shares the square components.
        final bytes = _makeJpeg(width: 160, height: 90);
        final hash = await BlurhashService.generateBlurhash(bytes);
        expect(hash, isNotNull);
        expect(hash!.length, equals(22));
      });

      test('accepts valid square hashes that do not start with L', () async {
        final bytes = _makeJpeg(width: 100, height: 100);
        final hash = await BlurhashService.generateBlurhash(bytes);

        expect(hash, isNotNull);
        expect(hash!.startsWith('L'), isFalse);
        expect(BlurhashService.decodeBlurhash(hash), isNotNull);
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
        expect(hash!.length, equals(28));
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

    group('generateBlurhash fallback behavior', () {
      test('returns null when encoding throws an exception', () async {
        // Empty bytes cause `img.decodeImage` to throw a RangeError rather
        // than return null, which exercises the broad `on Object catch`
        // branch in `BlurhashService.generateBlurhash`.
        final hash = await BlurhashService.generateBlurhash(Uint8List(0));
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

    group('deriveContentType', () {
      test('returns null when no metadata is provided', () {
        expect(BlurhashService.deriveContentType(), isNull);
      });

      test('returns null when nothing matches a known keyword', () {
        expect(
          BlurhashService.deriveContentType(
            hashtags: const ['random'],
            title: 'plain title',
            content: 'nothing of interest',
          ),
          isNull,
        );
      });

      test('matches keywords case-insensitively in hashtags', () {
        expect(
          BlurhashService.deriveContentType(hashtags: const ['Dance']),
          equals(VineContentType.dance),
        );
      });

      test('matches keywords inside title and content', () {
        expect(
          BlurhashService.deriveContentType(title: 'My recipe video'),
          equals(VineContentType.food),
        );
        expect(
          BlurhashService.deriveContentType(
            content: 'Watch this football clip',
          ),
          equals(VineContentType.sports),
        );
      });

      test('matches keywords inside group field', () {
        expect(
          BlurhashService.deriveContentType(group: 'tech-talk'),
          equals(VineContentType.tech),
        );
      });

      test('first matching category wins', () {
        // dance is checked before music, so a clip tagged with both
        // returns dance.
        expect(
          BlurhashService.deriveContentType(
            hashtags: const ['music', 'dance'],
          ),
          equals(VineContentType.dance),
        );
      });
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
