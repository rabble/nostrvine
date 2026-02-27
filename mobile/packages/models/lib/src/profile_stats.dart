import 'package:meta/meta.dart';

/// Aggregated statistics for a user profile.
///
/// Contains video count, engagement metrics, and social counts
/// sourced from the local Drift cache.
@immutable
class ProfileStats {
  /// Creates a new [ProfileStats] instance.
  const ProfileStats({
    required this.pubkey,
    this.videoCount = 0,
    this.totalLikes = 0,
    this.followers = 0,
    this.following = 0,
    this.totalViews = 0,
    this.lastUpdated,
  });

  /// The user's public key (hex format).
  final String pubkey;

  /// Number of published videos.
  final int videoCount;

  /// Total likes across all videos.
  final int totalLikes;

  /// Number of followers.
  final int followers;

  /// Number of accounts this user follows.
  final int following;

  /// Total views across all videos.
  final int totalViews;

  /// When these stats were last cached.
  final DateTime? lastUpdated;

  /// Creates a copy with the given fields replaced.
  ProfileStats copyWith({
    String? pubkey,
    int? videoCount,
    int? totalLikes,
    int? followers,
    int? following,
    int? totalViews,
    DateTime? lastUpdated,
  }) {
    return ProfileStats(
      pubkey: pubkey ?? this.pubkey,
      videoCount: videoCount ?? this.videoCount,
      totalLikes: totalLikes ?? this.totalLikes,
      followers: followers ?? this.followers,
      following: following ?? this.following,
      totalViews: totalViews ?? this.totalViews,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProfileStats &&
        other.pubkey == pubkey &&
        other.videoCount == videoCount &&
        other.totalLikes == totalLikes &&
        other.followers == followers &&
        other.following == following &&
        other.totalViews == totalViews &&
        other.lastUpdated == lastUpdated;
  }

  @override
  int get hashCode => Object.hash(
    pubkey,
    videoCount,
    totalLikes,
    followers,
    following,
    totalViews,
    lastUpdated,
  );

  @override
  String toString() =>
      'ProfileStats(pubkey: $pubkey, videos: $videoCount, '
      'likes: $totalLikes, followers: $followers, '
      'following: $following, views: $totalViews)';
}
