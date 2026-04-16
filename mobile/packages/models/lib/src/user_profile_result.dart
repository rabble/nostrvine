// ABOUTME: Sealed class representing the result of a Funnelcake user profile
// ABOUTME: fetch. Replaces the loosely-typed Map<String, dynamic>? / _noProfile
// ABOUTME: sentinel pattern with a proper discriminated union.

import 'package:meta/meta.dart';
import 'package:models/src/user_profile_data.dart';

/// The result of fetching a single user profile from Funnelcake.
///
/// Use pattern matching to handle each variant:
///
/// ```dart
/// switch (result) {
///   case UserProfileFound(:final profile, :final social):
///     // user has a Kind 0 profile event
///   case UserProfileNotPublished(:final pubkey):
///     // user exists in Funnelcake but has never published Kind 0
/// }
/// ```
///
/// A `null` return from `getUserProfile` (not this type) means the user was
/// not found at all (404).
///
/// Both variants expose [social], [stats], and [engagement] directly on the
/// base class so callers that only need those fields don't have to switch.
sealed class UserProfileResult {
  const UserProfileResult();

  /// Social graph counts returned by the API, or `null` if absent.
  ProfileSocialData? get social;

  /// Content statistics returned by the API, or `null` if absent.
  ProfileStatsData? get stats;

  /// Engagement totals returned by the API, or `null` if absent.
  ProfileEngagementData? get engagement;
}

/// The user exists and has published a Kind 0 profile event.
@immutable
final class UserProfileFound extends UserProfileResult {
  const UserProfileFound({
    required this.profile,
    this.social,
    this.stats,
    this.engagement,
  });

  /// Core profile metadata (name, picture, etc.).
  final UserProfileData profile;

  @override
  final ProfileSocialData? social;

  @override
  final ProfileStatsData? stats;

  @override
  final ProfileEngagementData? engagement;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfileFound &&
        other.profile == profile &&
        other.social == social &&
        other.stats == stats &&
        other.engagement == engagement;
  }

  @override
  int get hashCode => Object.hash(profile, social, stats, engagement);

  @override
  String toString() =>
      'UserProfileFound(profile: $profile, social: $social, '
      'stats: $stats, engagement: $engagement)';
}

/// The user is known to Funnelcake but has never published a Kind 0 event.
///
/// Callers should **not** attempt a relay/indexer fallback — Funnelcake
/// confirmed the profile genuinely does not exist yet. Stats data may still
/// be present and can populate engagement counters.
@immutable
final class UserProfileNotPublished extends UserProfileResult {
  const UserProfileNotPublished({
    required this.pubkey,
    this.social,
    this.stats,
    this.engagement,
  });

  /// The user's public key (hex format).
  final String pubkey;

  @override
  final ProfileSocialData? social;

  @override
  final ProfileStatsData? stats;

  @override
  final ProfileEngagementData? engagement;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfileNotPublished &&
        other.pubkey == pubkey &&
        other.social == social &&
        other.stats == stats &&
        other.engagement == engagement;
  }

  @override
  int get hashCode => Object.hash(pubkey, social, stats, engagement);

  @override
  String toString() =>
      'UserProfileNotPublished(pubkey: $pubkey, social: $social, '
      'stats: $stats, engagement: $engagement)';
}
