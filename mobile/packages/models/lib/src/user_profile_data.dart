// ABOUTME: Typed sub-models for the Funnelcake user profile API response.
// ABOUTME: Replaces the loosely-typed Map<String, dynamic> shapes previously
// ABOUTME: returned by getUserProfile and getBulkProfiles.

import 'package:meta/meta.dart';

// ---------------------------------------------------------------------------
// Shared numeric parse helpers used by all sub-models below.
// ---------------------------------------------------------------------------

/// Parses [value] as an [int], accepting int, num, or String representations.
/// Returns 0 for null or unrecognised types.
int parseIntSafe(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

/// Parses [value] as a [double], accepting double, num, or String
/// representations. Returns 0 for null or unrecognised types.
double parseDoubleSafe(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

// ---------------------------------------------------------------------------
// Sub-models
// ---------------------------------------------------------------------------

/// Core profile metadata fields from the Funnelcake `/api/users/:pubkey`
/// response — the `profile` sub-object.
@immutable
class UserProfileData {
  const UserProfileData({
    required this.pubkey,
    this.name,
    this.displayName,
    this.about,
    this.picture,
    this.banner,
    this.website,
    this.nip05,
    this.lud16,
  });

  factory UserProfileData.fromJson(String pubkey, Map<String, dynamic> json) {
    return UserProfileData(
      pubkey: pubkey,
      name: json['name'] as String?,
      displayName: json['display_name'] as String?,
      about: json['about'] as String?,
      picture: json['picture'] as String?,
      banner: json['banner'] as String?,
      website: json['website'] as String?,
      nip05: json['nip05'] as String?,
      lud16: json['lud16'] as String?,
    );
  }

  final String pubkey;
  final String? name;
  final String? displayName;
  final String? about;
  final String? picture;
  final String? banner;
  final String? website;
  final String? nip05;
  final String? lud16;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfileData &&
        other.pubkey == pubkey &&
        other.name == name &&
        other.displayName == displayName &&
        other.about == about &&
        other.picture == picture &&
        other.banner == banner &&
        other.website == website &&
        other.nip05 == nip05 &&
        other.lud16 == lud16;
  }

  @override
  int get hashCode => Object.hash(
    pubkey,
    name,
    displayName,
    about,
    picture,
    banner,
    website,
    nip05,
    lud16,
  );

  @override
  String toString() =>
      'UserProfileData(pubkey: $pubkey, name: $name, '
      'displayName: $displayName)';
}

/// Social graph counts (follower/following) from the `social` sub-object.
@immutable
class ProfileSocialData {
  const ProfileSocialData({
    required this.followerCount,
    required this.followingCount,
  });

  factory ProfileSocialData.fromJson(Map<String, dynamic> json) {
    return ProfileSocialData(
      followerCount: parseIntSafe(json['follower_count']),
      followingCount: parseIntSafe(json['following_count']),
    );
  }

  final int followerCount;
  final int followingCount;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProfileSocialData &&
        other.followerCount == followerCount &&
        other.followingCount == followingCount;
  }

  @override
  int get hashCode => Object.hash(followerCount, followingCount);

  @override
  String toString() =>
      'ProfileSocialData(followerCount: $followerCount, '
      'followingCount: $followingCount)';
}

/// Content statistics from the `stats` sub-object.
@immutable
class ProfileStatsData {
  const ProfileStatsData({
    required this.videoCount,
    required this.reactionCount,
  });

  factory ProfileStatsData.fromJson(Map<String, dynamic> json) {
    return ProfileStatsData(
      videoCount: parseIntSafe(json['video_count']),
      reactionCount: parseIntSafe(json['reaction_count']),
    );
  }

  final int videoCount;
  final int reactionCount;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProfileStatsData &&
        other.videoCount == videoCount &&
        other.reactionCount == reactionCount;
  }

  @override
  int get hashCode => Object.hash(videoCount, reactionCount);

  @override
  String toString() =>
      'ProfileStatsData(videoCount: $videoCount, '
      'reactionCount: $reactionCount)';
}

/// Engagement totals from the `engagement` sub-object.
@immutable
class ProfileEngagementData {
  const ProfileEngagementData({
    required this.totalReactions,
    required this.totalLoops,
    required this.totalViews,
  });

  factory ProfileEngagementData.fromJson(Map<String, dynamic> json) {
    return ProfileEngagementData(
      totalReactions: parseIntSafe(json['total_reactions']),
      totalLoops: parseDoubleSafe(json['total_loops']),
      totalViews: parseIntSafe(json['total_views']),
    );
  }

  final int totalReactions;
  final double totalLoops;
  final int totalViews;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProfileEngagementData &&
        other.totalReactions == totalReactions &&
        other.totalLoops == totalLoops &&
        other.totalViews == totalViews;
  }

  @override
  int get hashCode => Object.hash(totalReactions, totalLoops, totalViews);

  @override
  String toString() =>
      'ProfileEngagementData(totalReactions: $totalReactions, '
      'totalLoops: $totalLoops, totalViews: $totalViews)';
}
