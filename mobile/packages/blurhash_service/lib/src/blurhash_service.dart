// ABOUTME: Blurhash service for generating image
// placeholders and smooth loading transitions
// ABOUTME: Creates compact representations of images
// for better UX during vine loading

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:blurhash_dart/blurhash_dart.dart' as blurhash_dart;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:unified_logger/unified_logger.dart';

/// Service for generating and decoding Blurhash
/// placeholders.
class BlurhashService {
  /// Default horizontal component count.
  static const int defaultComponentX = 4;

  /// Default vertical component count.
  static const int defaultComponentY = 3;

  /// Default punch (contrast) value.
  static const double defaultPunch = 1;

  /// Generate blurhash from image bytes using
  /// blurhash_dart.
  static Future<String?> generateBlurhash(
    Uint8List imageBytes, {
    int componentX = defaultComponentX,
    int componentY = defaultComponentY,
  }) async {
    try {
      // Decode image to get dimensions and pixel data
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        // coverage:ignore-start
        Log.error(
          'Failed to decode image for blurhash '
          'generation',
          name: 'BlurhashService',
          category: LogCategory.system,
        );
        return null;
        // coverage:ignore-end
      }

      // Encode blurhash using blurhash_dart library
      final blurhash = blurhash_dart.BlurHash.encode(
        image,
        numCompX: componentX,
        numCompY: componentY,
      );

      final hashString = blurhash.hash;

      Log.verbose(
        'Generated blurhash: $hashString '
        '(${image.width}x${image.height}, '
        '${componentX}x$componentY components)',
        name: 'BlurhashService',
        category: LogCategory.system,
      );

      return hashString;
      // coverage:ignore-start
    } on Exception catch (e, stackTrace) {
      Log.error(
        'Failed to generate blurhash: $e',
        name: 'BlurhashService',
        category: LogCategory.system,
      );
      Log.verbose(
        'Stack trace: $stackTrace',
        name: 'BlurhashService',
        category: LogCategory.system,
      );
      return null;
    }
    // coverage:ignore-end
  }

  /// Generate blurhash from a [ui.Image] instance.
  // coverage:ignore-start
  static Future<String?> generateBlurhashFromImage(
    ui.Image image, {
    int componentX = defaultComponentX,
    int componentY = defaultComponentY,
  }) async {
    try {
      // Convert image to bytes
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) return null;

      final bytes = byteData.buffer.asUint8List();
      return generateBlurhash(
        bytes,
        componentX: componentX,
        componentY: componentY,
      );
    } on Exception catch (e) {
      Log.error(
        'Failed to generate blurhash from image: $e',
        name: 'BlurhashService',
        category: LogCategory.system,
      );
      return null;
    }
  }
  // coverage:ignore-end

  /// Decode blurhash to create placeholder widget data.
  static BlurhashData? decodeBlurhash(
    String blurhash, {
    int width = 32,
    int height = 32,
    double punch = defaultPunch,
  }) {
    try {
      if (!_isValidBlurhash(blurhash)) {
        return null;
      }

      // Use real blurhash_dart library to decode
      final blurHashObject = blurhash_dart.BlurHash.decode(blurhash);
      final image = blurHashObject.toImage(width, height);

      // Convert image to RGBA pixels
      final pixels = Uint8List.fromList(
        image.getBytes(order: img.ChannelOrder.rgba),
      );

      // Extract colors from the decoded pixel data
      final colors = _extractColorsFromPixels(
        pixels,
        width,
        height,
      );
      final primaryColor = colors.isNotEmpty
          ? colors.first
          : const ui.Color(0xFF888888);

      return BlurhashData(
        blurhash: blurhash,
        width: width,
        height: height,
        colors: colors,
        primaryColor: primaryColor,
        timestamp: DateTime.now(),
        pixels: pixels,
      );
      // coverage:ignore-start
    } on Exception catch (e) {
      Log.error(
        'Failed to decode blurhash: $e',
        name: 'BlurhashService',
        category: LogCategory.system,
      );
      return null;
    }
    // coverage:ignore-end
  }

  /// Generate a default blurhash for vine content.
  static String getDefaultVineBlurhash() {
    // Purple gradient for Divine branding
    return 'L6Pj0^jE.AyE_3t7t7R**0o#DgR4';
  }

  /// Get common vine blurhashes for different content
  /// types.
  static String getBlurhashForContentType(
    VineContentType contentType,
  ) {
    switch (contentType) {
      case VineContentType.comedy:
        // Warm yellow/orange
        return 'L8Q9Kx4n00M{~qD%_3t7D%WBRjof';
      case VineContentType.dance:
        // Purple/pink
        return 'L6PZfxjF4nWB_3t7t7R**0o#DgR4';
      case VineContentType.nature:
        // Green tones
        return 'L8F5?xYk^6#M@-5c,1J5@[or[Q6.';
      case VineContentType.food:
        // Warm brown/orange
        return 'L8RC8w4n00M{~qD%_3t7D%WBRjof';
      case VineContentType.music:
        // Blue/purple
        return 'L4Pj0^jE.AyE_3t7t7R**0o#DgR4';
      case VineContentType.tech:
        // Cool blue/gray
        return 'L2P?^~00~q00~qIU9FIU_3M{t7of';
      case VineContentType.art:
        // Rich colors
        return 'L8RC8w4n00M{~qD%_3t7D%WBRjof';
      case VineContentType.sports:
        // Dynamic green
        return 'L8F5?xYk^6#M@-5c,1J5@[or[Q6.';
      case VineContentType.lifestyle:
        // Soft purple
        return 'L6Pj0^jE.AyE_3t7t7R**0o#DgR4';
      case VineContentType.meme:
        // Bright yellow
        return 'L8Q9Kx4n00M{~qD%_3t7D%WBRjof';
      case VineContentType.tutorial:
        // Professional blue
        return 'L2P?^~00~q00~qIU9FIU_3M{t7of';
      case VineContentType.unknown:
        return getDefaultVineBlurhash();
    }
  }

  /// Validate blurhash format.
  static bool _isValidBlurhash(String blurhash) {
    if (blurhash.length < 6) return false;

    // Basic validation - should start with 'L'
    // and contain valid base83 characters
    if (!blurhash.startsWith('L')) return false;

    final validChars = RegExp(r'^[0-9A-Za-z#$%*+,-.:;=?@\[\]^_{|}~]+$');
    return validChars.hasMatch(blurhash);
  }

  /// Extract representative colors from decoded pixel
  /// data.
  static List<ui.Color> _extractColorsFromPixels(
    Uint8List pixels,
    int width,
    int height,
  ) {
    final colors = <ui.Color>[];

    if (pixels.isEmpty) return colors;

    // Sample a few pixels to get representative colors
    const sampleCount = 4; // Sample 4 colors
    final totalPixels = width * height;
    final step = totalPixels ~/ sampleCount;

    for (var i = 0; i < sampleCount && i * step * 4 < pixels.length - 3; i++) {
      // 4 bytes per pixel (RGBA)
      final pixelIndex = i * step * 4;

      if (pixelIndex + 3 < pixels.length) {
        final r = pixels[pixelIndex];
        final g = pixels[pixelIndex + 1];
        final b = pixels[pixelIndex + 2];
        final a = pixels[pixelIndex + 3];

        colors.add(ui.Color.fromARGB(a, r, g, b));
      }
    }

    // If we didn't get enough colors, add the first
    // pixel as fallback
    // coverage:ignore-start
    if (colors.isEmpty && pixels.length >= 4) {
      colors.add(
        ui.Color.fromARGB(
          pixels[3],
          pixels[0],
          pixels[1],
          pixels[2],
        ),
      );
    }
    // coverage:ignore-end

    return colors;
  }
}

/// Content types for vine classification.
enum VineContentType {
  /// Comedy content.
  comedy,

  /// Dance content.
  dance,

  /// Nature content.
  nature,

  /// Food content.
  food,

  /// Music content.
  music,

  /// Tech content.
  tech,

  /// Art content.
  art,

  /// Sports content.
  sports,

  /// Lifestyle content.
  lifestyle,

  /// Meme content.
  meme,

  /// Tutorial content.
  tutorial,

  /// Unknown content type.
  unknown,
}

/// Decoded blurhash data for UI rendering.
class BlurhashData {
  /// Creates a [BlurhashData] instance.
  const BlurhashData({
    required this.blurhash,
    required this.width,
    required this.height,
    required this.colors,
    required this.primaryColor,
    required this.timestamp,
    this.pixels,
  });

  /// The blurhash string.
  final String blurhash;

  /// The decoded image width.
  final int width;

  /// The decoded image height.
  final int height;

  /// Representative colors extracted from the hash.
  final List<ui.Color> colors;

  /// The primary (dominant) color.
  final ui.Color primaryColor;

  /// When this data was decoded.
  final DateTime timestamp;

  /// The actual decoded pixel data, if available.
  final Uint8List? pixels;

  /// Get a gradient for placeholder background.
  ui.Gradient get gradient {
    if (colors.length < 2) {
      return ui.Gradient.linear(
        ui.Offset.zero,
        const ui.Offset(1, 1),
        [
          primaryColor,
          primaryColor.withValues(alpha: 0.7),
        ],
      );
    }

    return ui.Gradient.linear(
      ui.Offset.zero,
      const ui.Offset(1, 1),
      colors.take(2).toList(),
    );
  }

  /// Check if this blurhash data is still valid
  /// (not too old).
  bool get isValid {
    final age = DateTime.now().difference(timestamp);
    return age.inMinutes < 30; // Expire after 30 minutes
  }

  @override
  String toString() {
    final rHex = primaryColor.r.toInt().toRadixString(16).padLeft(2, '0');
    final gHex = primaryColor.g.toInt().toRadixString(16).padLeft(2, '0');
    final bHex = primaryColor.b.toInt().toRadixString(16).padLeft(2, '0');
    return 'BlurhashData('
        'hash: ${blurhash.substring(0, 8)}..., '
        'colors: ${colors.length}, '
        'primary: #$rHex$gHex$bHex)';
  }
}

/// Exception thrown by blurhash operations.
class BlurhashException implements Exception {
  /// Creates a [BlurhashException] with the given
  /// [message].
  const BlurhashException(this.message);

  /// The error message.
  final String message;

  @override
  String toString() => 'BlurhashException: $message';
}

/// Blurhash cache for improved performance.
class BlurhashCache {
  /// Maximum number of entries in the cache.
  static const int maxCacheSize = 100;

  /// Duration before a cache entry expires.
  static const Duration cacheExpiry = Duration(hours: 1);

  final Map<String, BlurhashData> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  /// Store blurhash data in cache.
  void put(String key, BlurhashData data) {
    // Clean old entries if cache is full
    if (_cache.length >= maxCacheSize) {
      _cleanOldEntries();
    }

    _cache[key] = data;
    _cacheTimestamps[key] = DateTime.now();
  }

  /// Get blurhash data from cache.
  BlurhashData? get(String key) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return null;

    // Check if entry is expired
    if (DateTime.now().difference(timestamp) > cacheExpiry) {
      remove(key); // coverage:ignore-line
      return null; // coverage:ignore-line
    }

    return _cache[key];
  }

  /// Remove entry from cache.
  void remove(String key) {
    _cache.remove(key);
    _cacheTimestamps.remove(key);
  }

  /// Clear all cache entries.
  void clear() {
    _cache.clear();
    _cacheTimestamps.clear();
  }

  /// Clean old cache entries.
  void _cleanOldEntries() {
    final now = DateTime.now();
    final keysToRemove = <String>[];

    _cacheTimestamps.forEach((key, timestamp) {
      if (now.difference(timestamp) > cacheExpiry) {
        keysToRemove.add(key); // coverage:ignore-line
      }
    });

    keysToRemove.forEach(remove);

    // If still too many entries, remove oldest ones
    if (_cache.length >= maxCacheSize) {
      final sortedEntries = _cacheTimestamps.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));

      final toRemoveCount = _cache.length - (maxCacheSize ~/ 2);
      for (var i = 0; i < toRemoveCount && i < sortedEntries.length; i++) {
        remove(sortedEntries[i].key);
      }
    }
  }

  /// Get cache statistics.
  Map<String, dynamic> getStats() => {
    'size': _cache.length,
    'maxSize': maxCacheSize,
    'oldestEntry': _cacheTimestamps.values.isEmpty
        ? null
        : _cacheTimestamps.values.reduce((a, b) => a.isBefore(b) ? a : b),
    'newestEntry': _cacheTimestamps.values.isEmpty
        ? null
        : _cacheTimestamps.values.reduce((a, b) => a.isAfter(b) ? a : b),
  };
}
