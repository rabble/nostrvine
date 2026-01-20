/// Constants for video controller pool configuration.
class PoolConstants {
  PoolConstants._();

  /// Maximum number of controllers that can be initialized concurrently.
  ///
  /// Prevents overwhelming the system by limiting parallel video
  /// initializations. Subsequent requests are queued.
  static const int maxConcurrentInitializations = 4;

  /// Distance threshold for canceling in-flight controller requests.
  ///
  /// When a video is more than this many positions away from the current
  /// video, any pending controller request for that video is canceled
  /// to conserve resources.
  static const int distanceCancellationThreshold = 5;

  /// Duration to cache failed URL information.
  ///
  /// After a video URL fails to load, it's cached as failed for this duration
  /// to avoid repeated failed attempts. After this time, the URL will be
  /// retried.
  static const Duration failedUrlCacheDuration = Duration(minutes: 5);
}

/// Constants for video feed prewarming and scrolling behavior.
class FeedConstants {
  FeedConstants._();

  /// Number of videos to prewarm ahead of current position.
  ///
  /// Higher values improve perceived performance by loading more videos
  /// in advance, but use more memory.
  static const int prewarmAheadCount = 3;

  /// Number of videos to prewarm behind current position.
  ///
  /// Keeps recently viewed videos ready for quick backward navigation.
  static const int prewarmBehindCount = 1;

  /// Debounce duration for prewarm requests during rapid scrolling.
  ///
  /// Prevents excessive prewarming when user rapidly scrolls through feed.
  /// Prewarming only occurs after scrolling has settled for this duration.
  static const Duration prewarmDebounce = Duration(milliseconds: 150);
}

/// Memory tier thresholds for iOS and Android device classification.
class MemoryTierConfig {
  MemoryTierConfig._();

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
