// ABOUTME: Blurhash service for generating image placeholders and smooth loading transitions
// ABOUTME: Creates compact representations of images for better UX during vine loading

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service for generating and decoding Blurhash placeholders
class BlurhashService {
  static const int defaultComponentX = 4;
  static const int defaultComponentY = 3;
  static const double defaultPunch = 1.0;
  
  /// Generate blurhash from image bytes
  static Future<String?> generateBlurhash(
    Uint8List imageBytes, {
    int componentX = defaultComponentX,
    int componentY = defaultComponentY,
  }) async {
    try {
      // For now, return a simple deterministic blurhash based on file hash
      // In a full implementation, this would analyze the actual image
      final hash = _simpleHash(imageBytes);
      return _generateDeterministicBlurhash(hash, componentX, componentY);
    } catch (e) {
      debugPrint('❌ Failed to generate blurhash: $e');
      return null;
    }
  }
  
  /// Generate blurhash from image widget
  static Future<String?> generateBlurhashFromImage(
    ui.Image image, {
    int componentX = defaultComponentX,
    int componentY = defaultComponentY,
  }) async {
    try {
      // Convert image to bytes
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      
      final bytes = byteData.buffer.asUint8List();
      return generateBlurhash(bytes, componentX: componentX, componentY: componentY);
    } catch (e) {
      debugPrint('❌ Failed to generate blurhash from image: $e');
      return null;
    }
  }
  
  /// Decode blurhash to create placeholder widget data
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
      
      // For prototype, generate deterministic colors based on blurhash
      final colors = _extractColorsFromBlurhash(blurhash);
      
      return BlurhashData(
        blurhash: blurhash,
        width: width,
        height: height,
        colors: colors,
        primaryColor: colors.isNotEmpty ? colors.first : const ui.Color(0xFF888888),
        timestamp: DateTime.now(),
      );
    } catch (e) {
      debugPrint('❌ Failed to decode blurhash: $e');
      return null;
    }
  }
  
  /// Generate a default blurhash for vine content
  static String getDefaultVineBlurhash() {
    // Purple gradient for NostrVine branding
    return 'L6Pj0^jE.AyE_3t7t7R**0o#DgR4';
  }
  
  /// Get common vine blurhashes for different content types
  static String getBlurhashForContentType(VineContentType contentType) {
    switch (contentType) {
      case VineContentType.comedy:
        return 'L8Q9Kx4n00M{~qD%_3t7D%WBRjof'; // Warm yellow/orange
      case VineContentType.dance:
        return 'L6PZfxjF4nWB_3t7t7R**0o#DgR4'; // Purple/pink
      case VineContentType.nature:
        return 'L8F5?xYk^6#M@-5c,1J5@[or[Q6.'; // Green tones
      case VineContentType.food:
        return 'L8RC8w4n00M{~qD%_3t7D%WBRjof'; // Warm brown/orange
      case VineContentType.music:
        return 'L4Pj0^jE.AyE_3t7t7R**0o#DgR4'; // Blue/purple
      case VineContentType.tech:
        return 'L2P?^~00~q00~qIU9FIU_3M{t7of'; // Cool blue/gray
      case VineContentType.art:
        return 'L8RC8w4n00M{~qD%_3t7D%WBRjof'; // Rich colors
      case VineContentType.sports:
        return 'L8F5?xYk^6#M@-5c,1J5@[or[Q6.'; // Dynamic green
      case VineContentType.lifestyle:
        return 'L6Pj0^jE.AyE_3t7t7R**0o#DgR4'; // Soft purple
      case VineContentType.meme:
        return 'L8Q9Kx4n00M{~qD%_3t7D%WBRjof'; // Bright yellow
      case VineContentType.tutorial:
        return 'L2P?^~00~q00~qIU9FIU_3M{t7of'; // Professional blue
      case VineContentType.unknown:
        return getDefaultVineBlurhash();
    }
  }
  
  /// Validate blurhash format
  static bool _isValidBlurhash(String blurhash) {
    if (blurhash.length < 6) return false;
    
    // Basic validation - should start with 'L' and contain valid base83 characters
    if (!blurhash.startsWith('L')) return false;
    
    final validChars = RegExp(r'^[0-9A-Za-z#$%*+,-.:;=?@\[\]^_{|}~]+$');
    return validChars.hasMatch(blurhash);
  }
  
  /// Simple hash function for deterministic blurhash generation
  static int _simpleHash(Uint8List bytes) {
    int hash = 0;
    for (int i = 0; i < bytes.length; i += 100) { // Sample every 100th byte
      hash = ((hash * 31) + bytes[i]) & 0xFFFFFFFF;
    }
    return hash;
  }
  
  /// Generate deterministic blurhash from hash
  static String _generateDeterministicBlurhash(int hash, int componentX, int componentY) {
    // Simple algorithm to create a valid-looking blurhash
    final base83Chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz#\$%*+,-.:;=?@[]^_{|}~';
    
    final random = _SimplePseudoRandom(hash);
    final buffer = StringBuffer('L');
    
    // Generate 20-30 characters for a typical blurhash
    final length = 20 + (hash % 10); // Length between 20-29
    
    for (int i = 0; i < length; i++) {
      final index = random.nextInt(base83Chars.length);
      buffer.write(base83Chars[index]);
    }
    
    return buffer.toString();
  }
  
  /// Extract representative colors from blurhash
  static List<ui.Color> _extractColorsFromBlurhash(String blurhash) {
    final hash = blurhash.hashCode;
    final random = _SimplePseudoRandom(hash);
    
    final colors = <ui.Color>[];
    
    // Generate 3-5 representative colors
    final colorCount = 3 + (hash % 3);
    
    for (int i = 0; i < colorCount; i++) {
      final r = random.nextInt(256);
      final g = random.nextInt(256);
      final b = random.nextInt(256);
      
      colors.add(ui.Color.fromARGB(255, r, g, b));
    }
    
    return colors;
  }
}

/// Simple pseudo-random number generator for deterministic results
class _SimplePseudoRandom {
  int _seed;
  
  _SimplePseudoRandom(this._seed);
  
  int nextInt(int max) {
    _seed = ((_seed * 1103515245) + 12345) & 0x7FFFFFFF;
    return _seed % max;
  }
}

/// Content types for vine classification
enum VineContentType {
  comedy,
  dance,
  nature,
  food,
  music,
  tech,
  art,
  sports,
  lifestyle,
  meme,
  tutorial,
  unknown,
}

/// Decoded blurhash data for UI rendering
class BlurhashData {
  final String blurhash;
  final int width;
  final int height;
  final List<ui.Color> colors;
  final ui.Color primaryColor;
  final DateTime timestamp;
  
  const BlurhashData({
    required this.blurhash,
    required this.width,
    required this.height,
    required this.colors,
    required this.primaryColor,
    required this.timestamp,
  });
  
  /// Get a gradient for placeholder background
  ui.Gradient get gradient {
    if (colors.length < 2) {
      return ui.Gradient.linear(
        const ui.Offset(0, 0),
        const ui.Offset(1, 1),
        [primaryColor, primaryColor.withOpacity(0.7)],
      );
    }
    
    return ui.Gradient.linear(
      const ui.Offset(0, 0),
      const ui.Offset(1, 1),
      colors.take(2).toList(), // Use only first 2 colors for gradient
    );
  }
  
  /// Check if this blurhash data is still valid (not too old)
  bool get isValid {
    final age = DateTime.now().difference(timestamp);
    return age.inMinutes < 30; // Expire after 30 minutes
  }
  
  @override
  String toString() {
    return 'BlurhashData(hash: ${blurhash.substring(0, 8)}..., '
           'colors: ${colors.length}, primary: #${primaryColor.value.toRadixString(16)})';
  }
}

/// Exception thrown by blurhash operations
class BlurhashException implements Exception {
  final String message;
  
  const BlurhashException(this.message);
  
  @override
  String toString() => 'BlurhashException: $message';
}

/// Blurhash cache for improved performance
class BlurhashCache {
  static const int maxCacheSize = 100;
  static const Duration cacheExpiry = Duration(hours: 1);
  
  final Map<String, BlurhashData> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  
  /// Store blurhash data in cache
  void put(String key, BlurhashData data) {
    // Clean old entries if cache is full
    if (_cache.length >= maxCacheSize) {
      _cleanOldEntries();
    }
    
    _cache[key] = data;
    _cacheTimestamps[key] = DateTime.now();
  }
  
  /// Get blurhash data from cache
  BlurhashData? get(String key) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return null;
    
    // Check if entry is expired
    if (DateTime.now().difference(timestamp) > cacheExpiry) {
      remove(key);
      return null;
    }
    
    return _cache[key];
  }
  
  /// Remove entry from cache
  void remove(String key) {
    _cache.remove(key);
    _cacheTimestamps.remove(key);
  }
  
  /// Clear all cache entries
  void clear() {
    _cache.clear();
    _cacheTimestamps.clear();
  }
  
  /// Clean old cache entries
  void _cleanOldEntries() {
    final now = DateTime.now();
    final keysToRemove = <String>[];
    
    _cacheTimestamps.forEach((key, timestamp) {
      if (now.difference(timestamp) > cacheExpiry) {
        keysToRemove.add(key);
      }
    });
    
    for (final key in keysToRemove) {
      remove(key);
    }
    
    // If still too many entries, remove oldest ones
    if (_cache.length >= maxCacheSize) {
      final sortedEntries = _cacheTimestamps.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      
      final toRemoveCount = _cache.length - (maxCacheSize ~/ 2);
      for (int i = 0; i < toRemoveCount && i < sortedEntries.length; i++) {
        remove(sortedEntries[i].key);
      }
    }
  }
  
  /// Get cache statistics
  Map<String, dynamic> getStats() {
    return {
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
}