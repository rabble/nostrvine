// ABOUTME: Converts between Nostr events and CuratedList models.
// ABOUTME: Handles NIP-51 kind 30005 parsing including e-tags and
// ABOUTME: a-tags for addressable video references (NIP-71).

import 'package:models/models.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show Event;

/// NIP-71 video kind numbers accepted in `a` tags.
const _nip71VideoKinds = {'34235', '34236', '34237'};

/// Utility for converting between Nostr events and [CuratedList] models.
///
/// Handles NIP-51 kind 30005 event parsing, including:
/// - `e` tags for event ID video references
/// - `a` tags for addressable video references (NIP-71 kinds)
/// - Metadata tags: title, description, image, thumbnail, playorder
/// - Collaboration tags: collaborative, collaborator
abstract final class CuratedListConverter {
  /// Parses a Nostr [Event] into a [CuratedList].
  ///
  /// Returns `null` if the event cannot be parsed (e.g. missing d-tag).
  static CuratedList? fromEvent(Event event) {
    try {
      final dTag = extractDTag(event);
      if (dTag == null) return null;

      String? title;
      String? description;
      String? imageUrl;
      String? thumbnailEventId;
      String? playOrderStr;
      final tags = <String>[];
      final videoEventIds = <String>[];
      var isCollaborative = false;
      final allowedCollaborators = <String>[];

      for (final dynamic rawTag in event.tags) {
        final tag = (rawTag as List<dynamic>).cast<String>();
        if (tag.isEmpty) continue;

        switch (tag[0]) {
          case 'title':
            if (tag.length > 1) title = tag[1];
          case 'description':
            if (tag.length > 1) description = tag[1];
          case 'image':
            if (tag.length > 1) imageUrl = tag[1];
          case 'thumbnail':
            if (tag.length > 1) thumbnailEventId = tag[1];
          case 'playorder':
            if (tag.length > 1) playOrderStr = tag[1];
          case 't':
            if (tag.length > 1) tags.add(tag[1]);
          case 'e':
            if (tag.length > 1) videoEventIds.add(tag[1]);
          case 'a':
            if (tag.length > 1) {
              final parts = tag[1].split(':');
              if (parts.length >= 3 && _nip71VideoKinds.contains(parts[0])) {
                videoEventIds.add(tag[1]);
              }
            }
          case 'collaborative':
            if (tag.length > 1 && tag[1] == 'true') {
              isCollaborative = true;
            }
          case 'collaborator':
            if (tag.length > 1) allowedCollaborators.add(tag[1]);
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

      return CuratedList(
        id: dTag,
        name: name,
        pubkey: event.pubkey,
        description: description ?? event.content,
        imageUrl: imageUrl,
        videoEventIds: videoEventIds,
        createdAt: timestamp,
        updatedAt: timestamp,
        nostrEventId: event.id,
        tags: tags,
        isCollaborative: isCollaborative,
        allowedCollaborators: allowedCollaborators,
        thumbnailEventId: thumbnailEventId,
        playOrder: playOrderStr != null
            ? PlayOrderExtension.fromString(playOrderStr)
            : PlayOrder.chronological,
      );
    } on Object catch (_) {
      return null;
    }
  }

  /// Converts a [CuratedList] to Nostr event tags for publishing.
  ///
  /// Returns a list of tag arrays suitable for creating a kind 30005
  /// event.
  static List<List<String>> toEventTags(CuratedList list) {
    final tags = <List<String>>[
      ['d', list.id],
      ['title', list.name],
      ['client', 'diVine'],
    ];

    if (list.description != null && list.description!.isNotEmpty) {
      tags.add(['description', list.description!]);
    }

    if (list.imageUrl != null && list.imageUrl!.isNotEmpty) {
      tags.add(['image', list.imageUrl!]);
    }

    for (final tag in list.tags) {
      tags.add(['t', tag]);
    }

    if (list.isCollaborative) {
      tags.add(['collaborative', 'true']);
      for (final collaborator in list.allowedCollaborators) {
        tags.add(['collaborator', collaborator]);
      }
    }

    if (list.thumbnailEventId != null) {
      tags.add(['thumbnail', list.thumbnailEventId!]);
    }

    tags.add(['playorder', list.playOrder.value]);

    for (final videoEventId in list.videoEventIds) {
      tags.add(['e', videoEventId]);
    }

    return tags;
  }

  /// Extracts the `d` tag value from an [event].
  ///
  /// Returns `null` if no d-tag is present.
  static String? extractDTag(Event event) {
    for (final dynamic rawTag in event.tags) {
      final tag = (rawTag as List<dynamic>).cast<String>();
      if (tag.length >= 2 && tag[0] == 'd') {
        return tag[1];
      }
    }
    return null;
  }
}
