// ABOUTME: Data model for NIP-01 user profile metadata from kind 0 events
// ABOUTME: Represents user information like display name, avatar, bio, and social links

import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:nostr_sdk/event.dart';

part 'user_profile.g.dart';

/// Model representing a Nostr user profile from kind 0 events
@HiveType(typeId: 3)
class UserProfile {
  @HiveField(0)
  final String pubkey;
  @HiveField(1)
  final String? name;
  @HiveField(2)
  final String? displayName;
  @HiveField(3)
  final String? about;
  @HiveField(4)
  final String? picture;
  @HiveField(5)
  final String? banner;
  @HiveField(6)
  final String? website;
  @HiveField(7)
  final String? nip05;
  @HiveField(8)
  final String? lud16; // Lightning address
  @HiveField(9)
  final String? lud06; // LNURL
  @HiveField(10)
  final Map<String, dynamic> rawData;
  @HiveField(11)
  final DateTime createdAt;
  @HiveField(12)
  final String eventId;
  
  const UserProfile({
    required this.pubkey,
    this.name,
    this.displayName,
    this.about,
    this.picture,
    this.banner,
    this.website,
    this.nip05,
    this.lud16,
    this.lud06,
    required this.rawData,
    required this.createdAt,
    required this.eventId,
  });
  
  /// Create UserProfile from a Nostr kind 0 event
  factory UserProfile.fromNostrEvent(Event event) {
    if (event.kind != 0) {
      throw ArgumentError('Event must be kind 0 (user metadata)');
    }
    
    try {
      // Parse the JSON content
      final Map<String, dynamic> content = jsonDecode(event.content);
      
      return UserProfile(
        pubkey: event.pubkey,
        name: content['name']?.toString(),
        displayName: content['display_name']?.toString() ?? content['displayName']?.toString(),
        about: content['about']?.toString(),
        picture: content['picture']?.toString(),
        banner: content['banner']?.toString(),
        website: content['website']?.toString(),
        nip05: content['nip05']?.toString(),
        lud16: content['lud16']?.toString(),
        lud06: content['lud06']?.toString(),
        rawData: content,
        createdAt: DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
        eventId: event.id,
      );
    } catch (e) {
      // If JSON parsing fails, create a minimal profile
      return UserProfile(
        pubkey: event.pubkey,
        rawData: {},
        createdAt: DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
        eventId: event.id,
      );
    }
  }
  
  /// Get the best available display name
  String get bestDisplayName {
    if (displayName?.isNotEmpty == true) return displayName!;
    if (name?.isNotEmpty == true) return name!;
    return shortPubkey;
  }
  
  /// Get shortened pubkey for display
  String get shortPubkey {
    if (pubkey.length <= 16) return pubkey;
    return '${pubkey.substring(0, 8)}...${pubkey.substring(pubkey.length - 8)}';
  }
  
  /// Get npub encoding of pubkey
  String get npub {
    // TODO: Implement bech32 encoding for npub format
    // For now, return shortened pubkey
    return shortPubkey;
  }
  
  /// Check if profile has basic information
  bool get hasBasicInfo {
    return name?.isNotEmpty == true || 
           displayName?.isNotEmpty == true || 
           picture?.isNotEmpty == true;
  }
  
  /// Check if profile has avatar
  bool get hasAvatar => picture?.isNotEmpty == true;
  
  /// Check if profile has bio
  bool get hasBio => about?.isNotEmpty == true;
  
  /// Check if profile has verified NIP-05 identifier
  bool get hasNip05 => nip05?.isNotEmpty == true;
  
  /// Check if profile has Lightning support
  bool get hasLightning => lud16?.isNotEmpty == true || lud06?.isNotEmpty == true;
  
  /// Get Lightning address (prefers lud16 over lud06)
  String? get lightningAddress {
    if (lud16?.isNotEmpty == true) return lud16;
    if (lud06?.isNotEmpty == true) return lud06;
    return null;
  }
  
  /// Convert profile to JSON
  Map<String, dynamic> toJson() {
    return {
      'pubkey': pubkey,
      'name': name,
      'display_name': displayName,
      'about': about,
      'picture': picture,
      'banner': banner,
      'website': website,
      'nip05': nip05,
      'lud16': lud16,
      'lud06': lud06,
      'created_at': createdAt.millisecondsSinceEpoch,
      'event_id': eventId,
      'raw_data': rawData,
    };
  }
  
  /// Create profile from JSON
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      pubkey: json['pubkey'] as String,
      name: json['name'] as String?,
      displayName: json['display_name'] as String?,
      about: json['about'] as String?,
      picture: json['picture'] as String?,
      banner: json['banner'] as String?,
      website: json['website'] as String?,
      nip05: json['nip05'] as String?,
      lud16: json['lud16'] as String?,
      lud06: json['lud06'] as String?,
      rawData: json['raw_data'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
      eventId: json['event_id'] as String,
    );
  }
  
  /// Create copy with updated fields
  UserProfile copyWith({
    String? name,
    String? displayName,
    String? about,
    String? picture,
    String? banner,
    String? website,
    String? nip05,
    String? lud16,
    String? lud06,
    Map<String, dynamic>? rawData,
  }) {
    return UserProfile(
      pubkey: pubkey,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      about: about ?? this.about,
      picture: picture ?? this.picture,
      banner: banner ?? this.banner,
      website: website ?? this.website,
      nip05: nip05 ?? this.nip05,
      lud16: lud16 ?? this.lud16,
      lud06: lud06 ?? this.lud06,
      rawData: rawData ?? this.rawData,
      createdAt: createdAt,
      eventId: eventId,
    );
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProfile && other.pubkey == pubkey && other.eventId == eventId;
  }
  
  @override
  int get hashCode => Object.hash(pubkey, eventId);
  
  @override
  String toString() {
    return 'UserProfile(pubkey: $shortPubkey, name: $bestDisplayName, hasAvatar: $hasAvatar)';
  }
}