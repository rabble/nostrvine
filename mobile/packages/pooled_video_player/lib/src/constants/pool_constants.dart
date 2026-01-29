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

  // Preload Configuration

  /// Number of videos to preload ahead for low memory devices.
  static const int lowMemoryPreloadAhead = 1;

  /// Number of videos to preload ahead for medium memory devices.
  static const int mediumMemoryPreloadAhead = 2;

  /// Number of videos to preload ahead for high memory devices.
  static const int highMemoryPreloadAhead = 3;

  /// Number of videos to preload behind for low memory devices.
  static const int lowMemoryPreloadBehind = 1;

  /// Number of videos to preload behind for medium memory devices.
  static const int mediumMemoryPreloadBehind = 1;

  /// Number of videos to preload behind for high memory devices.
  static const int highMemoryPreloadBehind = 2;

  // Max Active Players Configuration

  /// Maximum active players for low memory devices.
  static const int lowMemoryMaxActivePlayers = 4;

  /// Maximum active players for medium memory devices.
  static const int mediumMemoryMaxActivePlayers = 5;

  /// Maximum active players for high memory devices.
  static const int highMemoryMaxActivePlayers = 7;
}
