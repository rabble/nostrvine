// ABOUTME: Video post expiration options with duration values and display descriptions
// ABOUTME: Defines lifecycle settings for video posts from permanent to decade-limited

import 'package:flutter/widgets.dart';
import 'package:openvine/l10n/l10n.dart';

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
  oneDecade
  ;

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

  String localizedLabel(BuildContext context) {
    return switch (this) {
      .notExpire => context.l10n.videoMetadataExpirationNotExpire,
      .oneDay => context.l10n.videoMetadataExpirationOneDay,
      .oneWeek => context.l10n.videoMetadataExpirationOneWeek,
      .oneMonth => context.l10n.videoMetadataExpirationOneMonth,
      .oneYear => context.l10n.videoMetadataExpirationOneYear,
      .oneDecade => context.l10n.videoMetadataExpirationOneDecade,
    };
  }
}
