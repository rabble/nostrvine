import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:pooled_video_player/src/constants/pool_constants.dart';

/// Device memory tier for determining pool size.
enum MemoryTier {
  /// < 3GB RAM - pool size 2
  low,

  /// 3-4GB RAM - pool size 3
  medium,

  /// > 4GB RAM - pool size 4
  high,
}

/// Platform type for device classification.
enum PlatformType {
  /// iOS platform
  ios,

  /// Android platform
  android,

  /// Other/unknown platform
  other,
}

/// Abstraction for platform detection. Enables testing.
abstract class PlatformChecker {
  /// Returns the current platform type.
  PlatformType get currentPlatform;
}

/// Default platform checker using dart:io Platform.
class DefaultPlatformChecker implements PlatformChecker {
  @override
  PlatformType get currentPlatform {
    if (Platform.isIOS) return PlatformType.ios;
    if (Platform.isAndroid) return PlatformType.android;
    return PlatformType.other;
  }
}

/// Implementation of device memory classification.
///
/// This class determines the memory tier of the current device to optimize
/// video controller pool sizing. Uses dependency injection for testability.
///
/// Example usage:
/// ```dart
/// final classifier = DeviceMemoryUtil();
/// final tier = await classifier.getMemoryTier();
/// ```
class DeviceMemoryUtil {
  /// Creates a device memory classifier with the given device info plugin.
  ///
  /// If [deviceInfo] is not provided, uses the default [DeviceInfoPlugin].
  /// If [platformChecker] is not provided, uses [DefaultPlatformChecker].
  DeviceMemoryUtil({
    DeviceInfoPlugin? deviceInfo,
    PlatformChecker? platformChecker,
  }) : _deviceInfo = deviceInfo ?? DeviceInfoPlugin(),
       _platformChecker = platformChecker ?? DefaultPlatformChecker();

  final DeviceInfoPlugin _deviceInfo;
  final PlatformChecker _platformChecker;
  MemoryTier? _cachedTier;

  /// Returns the memory tier of the current device.
  ///
  /// The result is cached after the first call.
  Future<MemoryTier> getMemoryTier() async {
    if (_cachedTier != null) {
      return _cachedTier!;
    }

    try {
      switch (_platformChecker.currentPlatform) {
        case PlatformType.ios:
          _cachedTier = await _getIOSMemoryTier();
        case PlatformType.android:
          _cachedTier = await _getAndroidMemoryTier();
        case PlatformType.other:
          _cachedTier = MemoryTier.medium;
      }
    } on Exception catch (e) {
      debugPrint('DeviceMemoryUtil: Failed to detect memory tier: $e');
      _cachedTier = MemoryTier.medium;
    }

    return _cachedTier!;
  }

  Future<MemoryTier> _getIOSMemoryTier() async {
    final iosInfo = await _deviceInfo.iosInfo;
    final model = iosInfo.utsname.machine;
    return _classifyIOSDevice(model);
  }

  MemoryTier _classifyIOSDevice(String model) {
    if (model.startsWith('iPhone')) {
      final versionPart = model.replaceFirst('iPhone', '');
      final parts = versionPart.split(',');
      if (parts.isNotEmpty) {
        final major = int.tryParse(parts[0]) ?? 0;

        if (major >= MemoryTierConfig.iPhoneHighMemoryGeneration) {
          return MemoryTier.high;
        }
        if (major >= MemoryTierConfig.iPhoneMediumMemoryGeneration) {
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

  Future<MemoryTier> _getAndroidMemoryTier() async {
    final androidInfo = await _deviceInfo.androidInfo;
    return _classifyAndroidDevice(
      androidInfo.version.sdkInt,
      androidInfo.supported64BitAbis,
    );
  }

  MemoryTier _classifyAndroidDevice(
    int sdkInt,
    List<String> supported64BitAbis,
  ) {
    if (sdkInt >= MemoryTierConfig.androidHighMemorySdk &&
        supported64BitAbis.isNotEmpty) {
      return MemoryTier.high;
    }

    if (sdkInt >= MemoryTierConfig.androidMediumMemorySdk &&
        supported64BitAbis.isNotEmpty) {
      return MemoryTier.medium;
    }

    return MemoryTier.low;
  }

  /// Resets the cached memory tier. Used for testing.
  void resetCache() {
    _cachedTier = null;
  }
}
