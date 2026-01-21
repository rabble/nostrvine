/// Constants for video controller pool configuration.
class PoolConstants {
  /// Maximum number of controllers that can be initialized concurrently.
  ///
  /// Prevents overwhelming the system by limiting parallel video
  /// initializations. Subsequent requests are queued.
  ///
  /// Value of 4 balances network bandwidth utilization with memory pressure
  /// from simultaneous decode operations.
  static const int maxConcurrentInitializations = 4;

  /// Distance threshold for canceling in-flight controller requests.
  ///
  /// When a video is more than this many positions away from the current
  /// video, any pending controller request for that video is canceled
  /// to conserve resources.
  ///
  /// Value of 5 accommodates typical fast-scroll behavior (~5 positions
  /// per swipe gesture) while avoiding wasted network requests for videos
  /// the user has scrolled past.
  static const int distanceCancellationThreshold = 5;
}

/// Memory tier thresholds for iOS and Android device classification.
class MemoryTierConfig {
  // iOS Device Thresholds (based on iPhone generation number)

  /// iPhone generation threshold for high memory tier (iPhone 14+).
  static const int iPhoneHighMemoryGeneration = 14;

  /// iPhone generation threshold for medium memory tier (iPhone 11+).
  static const int iPhoneMediumMemoryGeneration = 11;

  // Android Device Thresholds (based on SDK version)

  /// Android SDK version threshold for high memory tier (Android 10+).
  static const int androidHighMemorySdk = 29;

  /// Android SDK version threshold for medium memory tier (Android 8.0+).
  static const int androidMediumMemorySdk = 26;

  // Pool Size Configuration

  /// Pool size for low memory devices.
  static const int lowMemoryPoolSize = 2;

  /// Pool size for medium memory devices.
  static const int mediumMemoryPoolSize = 3;

  /// Pool size for high memory devices.
  static const int highMemoryPoolSize = 4;
}
