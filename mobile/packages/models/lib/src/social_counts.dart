import 'package:meta/meta.dart';

/// Social counts for a user from the Funnelcake API.
///
/// Represents follower and following counts for a given pubkey.
@immutable
class SocialCounts {
  /// Creates a new [SocialCounts] instance.
  const SocialCounts({
    required this.pubkey,
    required this.followerCount,
    required this.followingCount,
  });

  /// Creates a [SocialCounts] from JSON response.
  factory SocialCounts.fromJson(Map<String, dynamic> json) {
    return SocialCounts(
      pubkey: json['pubkey']?.toString() ?? '',
      followerCount: json['follower_count'] as int? ?? 0,
      followingCount: json['following_count'] as int? ?? 0,
    );
  }

  /// The user's public key (hex format).
  final String pubkey;

  /// Number of followers.
  final int followerCount;

  /// Number of accounts this user follows.
  final int followingCount;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SocialCounts && other.pubkey == pubkey;
  }

  @override
  int get hashCode => pubkey.hashCode;

  @override
  String toString() =>
      'SocialCounts(pubkey: $pubkey, followers: $followerCount, '
      'following: $followingCount)';
}
