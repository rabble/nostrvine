// ABOUTME: Converts between Nostr events and UserList models.
// ABOUTME: Handles NIP-51 kind 30000 parsing including p-tags for pubkeys.

import 'package:models/models.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show Event;

/// Utility for converting between Nostr events and [UserList] models.
///
/// Handles NIP-51 kind 30000 event parsing, including:
/// - `p` tags for pubkey members
/// - Metadata tags: title, description, image
abstract final class UserListConverter {
  /// Parses a Nostr [Event] into a [UserList].
  ///
  /// Returns `null` if the event cannot be parsed (e.g. missing d-tag).
  static UserList? fromEvent(Event event) {
    try {
      final dTag = _extractDTag(event);
      if (dTag == null) return null;

      String? title;
      String? description;
      String? imageUrl;
      final pubkeys = <String>[];

      for (final dynamic rawTag in event.tags) {
        final tag = (rawTag as List<dynamic>).cast<String>();
        if (tag.isEmpty) continue;

        switch (tag[0]) {
          case 'title':
            if (tag.length > 1) title = tag[1];
          case 'name':
            // Some clients use 'name' instead of 'title'
            if (tag.length > 1) title ??= tag[1];
          case 'description':
            if (tag.length > 1) description = tag[1];
          case 'image':
            if (tag.length > 1) imageUrl = tag[1];
          case 'p':
            if (tag.length > 1) pubkeys.add(tag[1]);
        }
      }

      // Use title, fall back to first line of content, then default.
      final contentFirstLine = event.content.split('\n').first;
      final name =
          title ??
          (contentFirstLine.isNotEmpty ? contentFirstLine : 'Untitled List');

      final timestamp = DateTime.fromMillisecondsSinceEpoch(
        event.createdAt * 1000,
      );

      return UserList(
        id: dTag,
        name: name,
        pubkeys: pubkeys,
        createdAt: timestamp,
        updatedAt: timestamp,
        description:
            description ?? (event.content.isNotEmpty ? event.content : null),
        imageUrl: imageUrl,
        nostrEventId: event.id,
      );
    } on Object catch (_) {
      return null;
    }
  }

  /// Extracts the `d` tag value from an [event].
  ///
  /// Returns `null` if no d-tag is present.
  static String? _extractDTag(Event event) {
    for (final dynamic rawTag in event.tags) {
      final tag = (rawTag as List<dynamic>).cast<String>();
      if (tag.length >= 2 && tag[0] == 'd') {
        return tag[1];
      }
    }
    return null;
  }
}
