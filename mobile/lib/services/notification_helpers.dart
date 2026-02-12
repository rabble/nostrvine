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
