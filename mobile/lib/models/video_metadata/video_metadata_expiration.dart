// ABOUTME: Video post expiration options with duration values and display descriptions
// ABOUTME: Defines lifecycle settings for video posts from permanent to decade-limited

/// Expiration options for video posts.
///
/// Provides predefined time periods after which a video post will expire
/// and no longer be available. Includes [notExpire] for permanent posts.
enum VideoMetadataExpiration {
  /// Video does not expire and remains available permanently.
  notExpire,

  /// Video expires after 1 day (24 hours).
  oneDay,

  /// Video expires after 1 week (7 days).
  oneWeek,

  /// Video expires after 1 month (31 days).
  oneMonth,

  /// Video expires after 1 year (365 days).
  oneYear,

  /// Video expires after 1 decade (10 years, 3650 days).
  oneDecade;

  /// Returns the duration value for this expiration option.
  ///
  /// Returns [null] for [notExpire], indicating no expiration.
  Duration? get value => switch (this) {
    .notExpire => null,
    .oneDay => const Duration(days: 1),
    .oneWeek => const Duration(days: 7),
    .oneMonth => const Duration(days: 31),
    .oneYear => const Duration(days: 365),
    .oneDecade => const Duration(days: 3_650),
  };

  /// Returns a human-readable description of this expiration option.
  ///
  /// Used for display in UI elements like dropdowns and labels.
  String get description => switch (this) {
    .notExpire => 'Does not expire',
    .oneDay => '1 day',
    .oneWeek => '1 week',
    .oneMonth => '1 month',
    .oneYear => '1 year',
    .oneDecade => '1 decade',
  };

  /// Returns the expiration option matching the given [duration].
  ///
  /// Returns [notExpire] if duration is zero or no exact match is found.
  static VideoMetadataExpiration fromDuration(Duration? duration) {
    if (duration == null || duration == .zero) return notExpire;
    for (final expiration in values) {
      if (expiration.value == duration) return expiration;
    }
    return notExpire;
  }
}
