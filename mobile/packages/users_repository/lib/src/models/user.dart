// ABOUTME: User model representing Nostr profile metadata from Kind 0 events.
// ABOUTME: Contains fields used for displaying user info on video feeds.

import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

/// Model representing a Nostr user profile from Kind 0 events.
///
/// Contains the essential fields needed for displaying user information
/// in video feeds and other UI components.
@immutable
class User {
  /// Creates a new [User] instance.
  const User({
    required this.pubkey,
    this.name,
    this.displayName,
    this.nip05,
  });

  /// Creates a [User] from a Nostr Kind 0 (metadata) event.
  ///
  /// Parses the JSON content of the event to extract profile fields.
  /// If JSON parsing fails, returns a user with only the pubkey.
  factory User.fromNostrEvent(Event event) {
    try {
      final content = jsonDecode(event.content) as Map<String, dynamic>;

      return User(
        pubkey: event.pubkey,
        name: content['name']?.toString(),
        displayName:
            content['display_name']?.toString() ??
            content['displayName']?.toString(),
        nip05: content['nip05']?.toString(),
      );
    } on FormatException {
      // If JSON parsing fails, return a minimal user
      return User(pubkey: event.pubkey);
    }
  }

  /// The user's public key in hex format.
  final String pubkey;

  /// The user's name field from their profile.
  final String? name;

  /// The user's display name field from their profile.
  final String? displayName;

  /// The user's NIP-05 identifier (e.g., "user@example.com").
  final String? nip05;

  /// Returns the best available display name.
  ///
  /// Priority: displayName > name > truncated pubkey
  String get bestDisplayName {
    if (displayName?.isNotEmpty ?? false) return displayName!;
    if (name?.isNotEmpty ?? false) return name!;
    return truncatedPubkey;
  }

  /// Returns truncated pubkey for display (first 8 chars + "...").
  String get truncatedPubkey => '${pubkey.substring(0, 8)}...';

  /// Whether this user has a NIP-05 identifier set.
  bool get hasNip05 => nip05?.isNotEmpty ?? false;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User && other.pubkey == pubkey;
  }

  @override
  int get hashCode => pubkey.hashCode;

  @override
  String toString() => 'User(pubkey: $truncatedPubkey, name: $bestDisplayName)';
}
