// ABOUTME: Data model for Funnelcake API profile search response.
// ABOUTME: Represents user profile data returned from the search endpoint.

import 'package:meta/meta.dart';
import 'package:models/src/user_profile.dart';

/// Profile result from Funnelcake search API.
///
/// This model represents the profile data returned by the Funnelcake
/// `/api/search/profiles` endpoint. It can be converted to a [UserProfile]
/// for use throughout the application.
@immutable
class ProfileSearchResult {
  /// Creates a new [ProfileSearchResult] instance.
  const ProfileSearchResult({
    required this.pubkey,
    this.name,
    this.displayName,
    this.about,
    this.picture,
    this.banner,
    this.nip05,
    this.lud16,
    this.website,
    this.createdAt,
    this.eventId,
    this.followerCount,
    this.videoCount,
  });

  /// Creates a [ProfileSearchResult] from JSON response.
  ///
  /// Handles the Funnelcake API response format with flexible field parsing:
  /// - Pubkey can be returned as byte array (ASCII codes) or string
  /// - created_at can be Unix timestamp or ISO string
  /// - All profile fields are optional except pubkey
  factory ProfileSearchResult.fromJson(Map<String, dynamic> json) {
    // Parse pubkey - funnelcake may return as byte array (ASCII codes)
    String pubkey;
    final rawPubkey = json['pubkey'];
    if (rawPubkey is List) {
      pubkey = String.fromCharCodes(rawPubkey.cast<int>());
    } else {
      pubkey = rawPubkey?.toString() ?? '';
    }
    // Normalize to lowercase per NIP-01 (Funnelcake may return uppercase hex)
    pubkey = pubkey.toLowerCase();

    // Parse created_at - funnelcake returns Unix timestamp (int), not ISO
    DateTime? createdAt;
    final rawCreatedAt = json['created_at'];
    if (rawCreatedAt is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(rawCreatedAt * 1000);
    } else if (rawCreatedAt is String) {
      createdAt = DateTime.tryParse(rawCreatedAt);
    }

    // Parse event_id - may be returned as byte array
    String? eventId;
    final rawEventId = json['event_id'] ?? json['id'];
    if (rawEventId is List) {
      eventId = String.fromCharCodes(rawEventId.cast<int>());
    } else if (rawEventId != null) {
      eventId = rawEventId.toString();
    }
    // Normalize to lowercase per NIP-01 (Funnelcake may return uppercase hex)
    eventId = eventId?.toLowerCase();

    // Parse follower_count and video_count
    int? followerCount;
    final rawFollowers = json['follower_count'];
    if (rawFollowers is int) {
      followerCount = rawFollowers;
    } else if (rawFollowers is String) {
      followerCount = int.tryParse(rawFollowers);
    }

    int? videoCount;
    final rawVideos = json['video_count'];
    if (rawVideos is int) {
      videoCount = rawVideos;
    } else if (rawVideos is String) {
      videoCount = int.tryParse(rawVideos);
    }

    return ProfileSearchResult(
      pubkey: pubkey,
      name: json['name']?.toString(),
      displayName:
          json['display_name']?.toString() ?? json['displayName']?.toString(),
      about: json['about']?.toString(),
      picture: json['picture']?.toString(),
      banner: json['banner']?.toString(),
      nip05: json['nip05']?.toString(),
      lud16: json['lud16']?.toString(),
      website: json['website']?.toString(),
      createdAt: createdAt,
      eventId: eventId,
      followerCount: followerCount,
      videoCount: videoCount,
    );
  }

  /// User's public key (hex format).
  final String pubkey;

  /// Username/handle.
  final String? name;

  /// Display name.
  final String? displayName;

  /// Profile bio/description.
  final String? about;

  /// Profile picture URL.
  final String? picture;

  /// Banner image URL.
  final String? banner;

  /// NIP-05 identifier (e.g., user@domain.com).
  final String? nip05;

  /// Lightning address.
  final String? lud16;

  /// Website URL.
  final String? website;

  /// When the profile was created/updated.
  final DateTime? createdAt;

  /// Nostr event ID of the profile.
  final String? eventId;

  /// Number of followers for this profile.
  final int? followerCount;

  /// Number of videos published by this profile.
  final int? videoCount;

  /// Get the best display name available.
  String get bestDisplayName =>
      displayName ?? name ?? pubkey.substring(0, 8).toUpperCase();

  /// Converts this [ProfileSearchResult] to a [UserProfile] for app use.
  ///
  /// Maps the Funnelcake API response fields to the corresponding
  /// [UserProfile] fields used throughout the application.
  UserProfile toUserProfile() {
    return UserProfile(
      pubkey: pubkey,
      name: name,
      displayName: displayName,
      about: about,
      picture: picture,
      banner: banner,
      website: website,
      nip05: nip05,
      lud16: lud16,
      rawData: {
        if (followerCount != null) 'follower_count': followerCount,
        if (videoCount != null) 'video_count': videoCount,
      },
      createdAt: createdAt ?? DateTime.now(),
      eventId: eventId ?? '',
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProfileSearchResult && other.pubkey == pubkey;
  }

  @override
  int get hashCode => pubkey.hashCode;

  @override
  String toString() =>
      'ProfileSearchResult(pubkey: $pubkey, name: $displayName)';
}
