// ABOUTME: Cross-platform IO abstraction to handle web vs native differences
// ABOUTME: Provides stubs for IO operations that aren't available on web platform

import 'package:flutter/foundation.dart';

// Platform stub for web builds using the repo's dart:io compatibility layer.
class Platform {
  static bool get isIOS => false;

  static bool get isAndroid => false;

  static bool get isMacOS => false;

  static bool get isWindows => false;

  static bool get isLinux => false;

  static String get operatingSystem => 'web';
}

// InternetAddress stub for web platform
class InternetAddress {
  static InternetAddress? tryParse(String address) {
    if (kIsWeb) {
      // On web, return null since we can't use IO overrides
      return null;
    }
    // This won't be reached on web, but keeps the API consistent
    return null;
  }
}

// HttpOverrides stub for web platform
class HttpOverrides {
  static dynamic global;
}

// VineCdnHttpOverrides stub for web platform
class VineCdnHttpOverrides {
  // ignore: avoid_unused_constructor_parameters
  VineCdnHttpOverrides({required dynamic overrideAddress});
}
