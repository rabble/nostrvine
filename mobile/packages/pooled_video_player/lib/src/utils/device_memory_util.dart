import 'dart:developer' as developer;
import 'dart:io';
import 'dart:ui' show Size;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Device memory tier for determining pool size.
enum MemoryTier {
  /// < 3GB RAM - pool size 2
  low,

  /// 3-4GB RAM - pool size 3
  medium,

  /// > 4GB RAM - pool size 4
  high,
}

/// Utility for detecting device memory tier.
class DeviceMemoryUtil {
  DeviceMemoryUtil._();

  static MemoryTier? _cachedTier;
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  static Future<MemoryTier> getMemoryTier() async {
    if (_cachedTier != null) {
      return _cachedTier!;
    }

    try {
      if (Platform.isIOS) {
        _cachedTier = await _getIOSMemoryTier();
      } else if (Platform.isAndroid) {
        _cachedTier = await _getAndroidMemoryTier();
      } else {
        _cachedTier = MemoryTier.medium;
      }
    } on Exception catch (e) {
      developer.log(
        'Failed to detect memory tier, defaulting to medium: $e',
        name: 'DeviceMemoryUtil',
      );
      _cachedTier = MemoryTier.medium;
    }

    developer.log(
      'Device memory tier: ${_cachedTier!.name}',
      name: 'DeviceMemoryUtil',
    );

    return _cachedTier!;
  }

  static Future<MemoryTier> _getIOSMemoryTier() async {
    final iosInfo = await _deviceInfo.iosInfo;
    final model = iosInfo.utsname.machine;

    developer.log(
      'iOS device model: $model',
      name: 'DeviceMemoryUtil',
    );

    if (model.startsWith('iPhone')) {
      final versionPart = model.replaceFirst('iPhone', '');
      final parts = versionPart.split(',');
      if (parts.isNotEmpty) {
        final major = int.tryParse(parts[0]) ?? 0;

        if (major >= 14) {
          return MemoryTier.high;
        }
        if (major >= 11) {
          return MemoryTier.medium;
        }
        return MemoryTier.low;
      }
    }

    if (model.startsWith('iPad')) {
      return MemoryTier.high;
    }

    return MemoryTier.medium;
  }

  static Future<MemoryTier> _getAndroidMemoryTier() async {
    final androidInfo = await _deviceInfo.androidInfo;

    developer.log(
      'Android device: ${androidInfo.model}, '
      'SDK: ${androidInfo.version.sdkInt}, '
      '64-bit: ${androidInfo.supported64BitAbis.isNotEmpty}',
      name: 'DeviceMemoryUtil',
    );

    if (androidInfo.version.sdkInt >= 29 &&
        androidInfo.supported64BitAbis.isNotEmpty) {
      return MemoryTier.high;
    }

    if (androidInfo.version.sdkInt >= 26 &&
        androidInfo.supported64BitAbis.isNotEmpty) {
      return MemoryTier.medium;
    }

    return MemoryTier.low;
  }

  static Future<Size> getMaxOverlayResolution(Size videoSize) async {
    final tier = await getMemoryTier();

    switch (tier) {
      case MemoryTier.low:
        return _scaleToMax(videoSize, 1280, 720);

      case MemoryTier.medium:
        return _scaleToMax(videoSize, 1920, 1080);

      case MemoryTier.high:
        return _scaleToMax(videoSize, 3840, 2160);
    }
  }

  static Size _scaleToMax(Size size, double maxWidth, double maxHeight) {
    final isPortrait = size.height > size.width;

    final effectiveMaxWidth = isPortrait ? maxHeight : maxWidth;
    final effectiveMaxHeight = isPortrait ? maxWidth : maxHeight;

    if (size.width <= effectiveMaxWidth && size.height <= effectiveMaxHeight) {
      return size;
    }

    final scaleX = effectiveMaxWidth / size.width;
    final scaleY = effectiveMaxHeight / size.height;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    return Size(
      (size.width * scale).roundToDouble(),
      (size.height * scale).roundToDouble(),
    );
  }

  static Future<bool> isLowMemoryDevice() async {
    final tier = await getMemoryTier();
    return tier == MemoryTier.low;
  }

  @visibleForTesting
  static void resetCache() {
    _cachedTier = null;
  }
}
