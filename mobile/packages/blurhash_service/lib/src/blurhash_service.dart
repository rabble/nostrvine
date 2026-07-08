// ABOUTME: Blurhash service for generating image
// placeholders and smooth loading transitions
// ABOUTME: Creates compact representations of images
// for better UX during vine loading

import 'dart:ui' as ui;

import 'package:blurhash_dart/blurhash_dart.dart' as blurhash_dart;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:unified_logger/unified_logger.dart';

/// Isolate worker for [BlurhashService.generateBlurhash].
///
/// Top-level so [compute] can pass it to a background isolate.
String? _generateBlurhashSync(Uint8List imageBytes) {
  final image = img.decodeImage(imageBytes);
  if (image == null) return null;

  final (componentX, componentY) = BlurhashService._componentsForAspectRatio(
    image.width,
    image.height,
  );

  final resized = image.width > BlurhashService._encodeMaxWidth
      ? img.copyResize(image, width: BlurhashService._encodeMaxWidth)
      : image;

  return blurhash_dart.BlurHash.encode(
    resized,
    numCompX: componentX,
    numCompY: componentY,
  ).hash;
}

/// Service for generating and decoding Blurhash
/// placeholders.
class BlurhashService {
  /// Components for 9:16 portrait videos (4:7 ≈ 0.57, matches 9:16 ≈ 0.5625).
  static const int _portraitComponentX = 4;
  static const int _portraitComponentY = 7;

  /// Components for 1:1 square and landscape videos (balanced).
  static const int _squareComponentX = 4;
  static const int _squareComponentY = 4;

  /// Max width used when downscaling before encoding.
  static const int _encodeMaxWidth = 128;

  /// Default punch (contrast) value.
  static const double defaultPunch = 1;

  /// Process-wide memo for [decodeBlurhash]. Decoding is a pure function
  /// of (hash, width, height, punch) and runs synchronously on the UI
  /// isolate, so repeated decodes of the same hash (feed item recycling,
  /// shared default hashes) burn main-thread CPU for identical results —
  /// ~11% of main-isolate CPU in on-device profiling.
  static final BlurhashCache _decodeCache = BlurhashCache();

  /// Compiled once — [_isValidBlurhash] runs on every decode.
  static final RegExp _validBlurhashChars = RegExp(
    r'^[0-9A-Za-z#$%*+,-.:;=?@\[\]^_{|}~]+$',
  );

  /// Returns component counts suited to the image's aspect ratio.
  /// Supports 9:16 portrait, 1:1 square, and landscape; falls back to portrait.
  static (int compX, int compY) _componentsForAspectRatio(
    int width,
    int height,
  ) {
    if (width == 0 || height == 0) {
      return (_portraitComponentX, _portraitComponentY);
    }
    final ratio = width / height;
    // Square or landscape: ratio ≥ 0.9 (covers 1:1 and any wider format)
    if (ratio >= 0.9) return (_squareComponentX, _squareComponentY);
    // Portrait 9:16 (and any other tall format)
    return (_portraitComponentX, _portraitComponentY);
  }

  /// Generate blurhash from image bytes.
  ///
  /// Encoding runs in a background isolate via [compute] to avoid
  /// blocking the UI thread.
  static Future<String?> generateBlurhash(
    Uint8List imageBytes,
  ) async {
    try {
      return await compute(_generateBlurhashSync, imageBytes);
    } on Object catch (e, stackTrace) {
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
  }

  /// Generate blurhash from a [ui.Image] instance.
  // coverage:ignore-start
  static Future<String?> generateBlurhashFromImage(
    ui.Image image,
  ) async {
    try {
      // Convert image to bytes
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) return null;

      final bytes = byteData.buffer.asUint8List();
      return generateBlurhash(bytes);
    } on Object catch (e) {
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
  ///
  /// Results are memoized in [_decodeCache]; repeated calls with the same
  /// arguments return the cached [BlurhashData] instance.
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

      final cacheKey = '$blurhash:$width:$height:$punch';
      final cached = _decodeCache.get(cacheKey);
      if (cached != null) {
        return cached;
      }

      // Use real blurhash_dart library to decode
      final blurHashObject = blurhash_dart.BlurHash.decode(
        blurhash,
        punch: punch,
      );
      final image = blurHashObject.toImage(width, height);

      // RGBA pixel data of the decoded image (getBytes already returns a
      // buffer we own — no defensive copy needed)
      final pixels = image.getBytes(order: img.ChannelOrder.rgba);

      // Extract colors from the decoded pixel data
      final colors = _extractColorsFromPixels(
        pixels,
        width,
        height,
      );
      final primaryColor = colors.isNotEmpty
          ? colors.first
          : const ui.Color(0xFF888888);

      final data = BlurhashData(
        blurhash: blurhash,
        width: width,
        height: height,
        colors: colors,
        primaryColor: primaryColor,
        timestamp: DateTime.now(),
        pixels: pixels,
      );
      _decodeCache.put(cacheKey, data);
      return data;
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

  /// Derive a [VineContentType] from free-form metadata strings.
  ///
  /// Returns `null` when no keyword matches; callers can then fall back to
  /// [getDefaultVineBlurhash]. Comparison is case-insensitive.
  static VineContentType? deriveContentType({
    Iterable<String> hashtags = const [],
    String? group,
    String? title,
    String? content,
  }) {
    final tokens = <String>[
      ...hashtags.map((h) => h.toLowerCase()),
      group?.toLowerCase() ?? '',
      title?.toLowerCase() ?? '',
      content?.toLowerCase() ?? '',
    ].join(' ');

    bool hasAny(List<String> keywords) => keywords.any(tokens.contains);

    if (hasAny(['dance', 'choreo'])) return VineContentType.dance;
    if (hasAny(['nature', 'outdoor', 'wildlife'])) {
      return VineContentType.nature;
    }
    if (hasAny(['food', 'recipe', 'cooking'])) return VineContentType.food;
    if (hasAny(['music', 'song', 'beat'])) return VineContentType.music;
    if (hasAny(['tech', 'coding', 'code', 'dev'])) {
      return VineContentType.tech;
    }
    if (hasAny(['art', 'design', 'drawing'])) return VineContentType.art;
    if (hasAny(['sport', 'fitness', 'workout', 'soccer', 'football'])) {
      return VineContentType.sports;
    }
    if (hasAny(['lifestyle', 'daily', 'vlog'])) {
      return VineContentType.lifestyle;
    }
    if (hasAny(['meme', 'shitpost', 'funny'])) return VineContentType.meme;
    if (hasAny(['tutorial', 'howto', 'how-to'])) {
      return VineContentType.tutorial;
    }

    return null;
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

    return _validBlurhashChars.hasMatch(blurhash);
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
