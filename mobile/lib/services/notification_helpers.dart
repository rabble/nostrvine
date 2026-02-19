// ABOUTME: Pure helper functions for notification event processing
// ABOUTME: Extracted from NotificationServiceEnhanced to reduce duplication and improve testability

import 'package:nostr_sdk/event.dart';
import 'package:models/models.dart';

/// Extracts the video event ID from a Nostr event's tags
/// For NIP-22 comments (kind 1111), looks for uppercase 'E' tag (root scope)
/// Falls back to lowercase 'e' tag for other event types (reactions, reposts)
/// Returns null if no matching tag exists or if the tag has no value
String? extractVideoEventId(Event event) {
  // First try uppercase 'E' tag (NIP-22 root scope for comments)
  for (final tag in event.tags) {
    if (tag.isNotEmpty && tag[0] == 'E' && tag.length > 1) {
      return tag[1];
    }
  }
  // Fall back to lowercase 'e' tag (for reactions, reposts, etc.)
  for (final tag in event.tags) {
    if (tag.isNotEmpty && tag[0] == 'e' && tag.length > 1) {
      return tag[1];
    }
  }
  return null;
}

/// Extracts the addressable event reference from a Nostr event's tags
/// For NIP-22 comments on addressable events (kind 30000+), looks for
/// uppercase 'A' tag (root scope) first, then falls back to lowercase 'a'
/// Returns the addressable ID string (format: "kind:pubkey:d-tag") or null
String? extractAddressableId(Event event) {
  // First try uppercase 'A' tag (NIP-22 root scope for addressable events)
  for (final tag in event.tags) {
    if (tag.isNotEmpty && tag[0] == 'A' && tag.length > 1) {
      return tag[1];
    }
  }
  // Fall back to lowercase 'a' tag (parent scope)
  for (final tag in event.tags) {
    if (tag.isNotEmpty && tag[0] == 'a' && tag.length > 1) {
      return tag[1];
    }
  }
  return null;
}

/// Parses an addressable event ID into its components
/// Format: "kind:pubkey:d-tag"
/// Returns (kind, pubkey, dTag) or null if the format is invalid
({int kind, String pubkey, String dTag})? parseAddressableId(
  String addressableId,
) {
  final parts = addressableId.split(':');
  if (parts.length < 3) return null;

  final kind = int.tryParse(parts[0]);
  if (kind == null) return null;

  final pubkey = parts[1];
  // d-tag may contain colons, so rejoin remaining parts
  final dTag = parts.sublist(2).join(':');

  return (kind: kind, pubkey: pubkey, dTag: dTag);
}

/// Resolves the actor name from a user profile with fallback priority:
/// 1. name field
/// 2. displayName field
/// 3. nip05 username (part before @)
/// 4. "Unknown user" as final fallback
String resolveActorName(UserProfile? profile) {
  if (profile == null) {
    return 'Unknown user';
  }

  // Try name first
  if (profile.name != null) {
    return profile.name!;
  }

  // Try displayName second
  if (profile.displayName != null) {
    return profile.displayName!;
  }

  // Try nip05 username third
  if (profile.displayNip05 != null) {
    final nip05Parts = profile.displayNip05!.split('@');
    // For subdomain-style NIP-05 like @loganpaul.divine.video,
    // the first part is empty and username is in the subdomain
    if (nip05Parts.length > 1 && nip05Parts.first.isEmpty) {
      return nip05Parts[1].split('.').first;
    }
    // Traditional NIP-05 like alice@example.com - username is before @
    return nip05Parts.first;
  }

  // Final fallback
  return 'Unknown user';
}
