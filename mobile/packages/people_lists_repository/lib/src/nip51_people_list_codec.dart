// ABOUTME: Encodes and decodes NIP-51 kind 30000 people (follow set) events.
// ABOUTME: Preserves full Nostr pubkeys and skips app-managed reserved d tags.

import 'package:equatable/equatable.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

/// Raw Nostr event payload produced by [Nip51PeopleListCodec.encode].
///
/// The publisher owns signing and relay selection, so the codec only returns
/// the kind, tags, and content fields required to build the final [Event].
class PeopleListEventPayload extends Equatable {
  /// Creates a new payload.
  const PeopleListEventPayload({
    required this.kind,
    required this.tags,
    this.content = '',
  });

  /// Nostr event kind. Always [Nip51PeopleListCodec.kind] for people lists.
  final int kind;

  /// Ordered tags for the event, including the `d`, `title`, optional
  /// `description` and `image`, and one `p` tag per member pubkey.
  final List<List<String>> tags;

  /// Event content. Always an empty string for NIP-51 follow sets.
  final String content;

  @override
  List<Object?> get props => [kind, tags, content];
}

/// Codec for NIP-51 kind 30000 people (follow set) events.
///
/// Follow sets are parameterised replaceable events. Each event is identified
/// by the combination of pubkey + kind + `d` tag. This codec:
///
/// * Encodes a [UserList] into a [PeopleListEventPayload].
/// * Decodes a kind 30000 [Event] into a [UserList], or `null` when the event
///   does not describe a user-editable people list (missing `d`, wrong kind,
///   or one of the reserved app-managed lists in [reservedDTags]).
abstract final class Nip51PeopleListCodec {
  /// NIP-51 kind for people / follow sets.
  static const int kind = 30000;

  /// Reserved `d` tag value used by the app's block list.
  static const String blockedDTag = 'block';

  /// Reserved `d` tag value used by the app's new-post notification
  /// subscription list ("bells").
  static const String notifyDTag = 'notify';

  /// Reserved `d` tag values for app-managed kind 30000 lists.
  ///
  /// Events with these identifiers are filtered out of the user-facing list
  /// collection so app-managed lists cannot be renamed, edited, or deleted as
  /// ordinary people lists. Deleting the notify list would silently clear
  /// every bell the user has set.
  static const Set<String> reservedDTags = {blockedDTag, notifyDTag};

  /// Encodes [list] into a [PeopleListEventPayload].
  ///
  /// The payload always includes `d` and `title` tags. `description` and
  /// `image` are only added when non-empty after trimming. One `p` tag is
  /// emitted per non-empty pubkey in [UserList.pubkeys]; pubkeys are never
  /// truncated.
  static PeopleListEventPayload encode(UserList list) {
    final tags = <List<String>>[
      ['d', list.id],
      ['title', list.name],
    ];

    final description = list.description?.trim();
    if (description != null && description.isNotEmpty) {
      tags.add(['description', description]);
    }

    final imageUrl = list.imageUrl?.trim();
    if (imageUrl != null && imageUrl.isNotEmpty) {
      tags.add(['image', imageUrl]);
    }

    for (final pubkey in list.pubkeys) {
      if (pubkey.isNotEmpty) {
        tags.add(['p', pubkey]);
      }
    }

    return PeopleListEventPayload(kind: kind, tags: tags);
  }

  /// Encodes an app-managed reserved list into a [PeopleListEventPayload].
  ///
  /// Reserved lists (see [reservedDTags]) never become a [UserList], so they
  /// cannot go through [encode]. Emits one `p` tag per non-empty pubkey,
  /// never truncated.
  ///
  /// An empty [pubkeys] is legitimate — it is how the user clears the list —
  /// and produces an event with `d` and `title` but no `p` tags.
  static PeopleListEventPayload encodeReserved({
    required String dTag,
    required String title,
    required Iterable<String> pubkeys,
  }) {
    assert(
      reservedDTags.contains(dTag),
      'encodeReserved is only for app-managed lists in reservedDTags',
    );
    return PeopleListEventPayload(
      kind: kind,
      tags: [
        ['d', dTag],
        ['title', title],
        for (final pubkey in pubkeys)
          if (pubkey.isNotEmpty) ['p', pubkey],
      ],
    );
  }

  /// Decodes the member pubkeys of the app-managed reserved list [dTag].
  ///
  /// Returns `null` when [event] is not a kind [kind] event carrying that
  /// exact `d` tag, so callers can filter a mixed relay response. An empty
  /// list means the event exists and has no members — distinct from `null`.
  ///
  /// Full pubkeys are preserved; duplicates are collapsed while keeping first
  /// occurrence order.
  static List<String>? decodeReservedMembers(
    Event event, {
    required String dTag,
  }) {
    if (event.kind != kind) return null;
    if (_firstTagValue(event.tags, 'd') != dTag) return null;
    return _memberPubkeys(event.tags).toSet().toList(growable: false);
  }

  /// Decodes [event] into a [UserList], or returns `null` when the event is
  /// not a user-facing people list.
  ///
  /// Returns `null` when:
  /// * [Event.kind] is not [kind].
  /// * The event has no non-empty `d` tag.
  /// * The `d` tag is one of [reservedDTags] (app-managed lists).
  ///
  /// The returned [UserList.name] prefers the `title` tag and falls back to
  /// the `d` tag when `title` is missing. Full 64-char pubkeys are preserved
  /// on every `p` tag.
  static UserList? decode(Event event) {
    if (event.kind != kind) {
      return null;
    }

    final dTag = _firstTagValue(event.tags, 'd');
    if (dTag == null || reservedDTags.contains(dTag)) {
      return null;
    }

    final pubkeys = _memberPubkeys(event.tags).toList(growable: false);

    final timestamp = DateTime.fromMillisecondsSinceEpoch(
      event.createdAt * 1000,
      isUtc: true,
    );

    return UserList(
      id: dTag,
      name: _firstTagValue(event.tags, 'title') ?? dTag,
      description: _firstTagValue(event.tags, 'description'),
      imageUrl: _firstTagValue(event.tags, 'image'),
      pubkeys: pubkeys,
      createdAt: timestamp,
      updatedAt: timestamp,
      nostrEventId: event.id.isEmpty ? null : event.id,
    );
  }

  /// Member pubkeys from every non-empty `p` tag, in tag order.
  static Iterable<String> _memberPubkeys(List<List<String>> tags) => tags
      .where((tag) => tag.length >= 2 && tag[0] == 'p' && tag[1].isNotEmpty)
      .map((tag) => tag[1]);

  static String? _firstTagValue(List<List<String>> tags, String name) {
    for (final tag in tags) {
      if (tag.length >= 2 && tag[0] == name && tag[1].isNotEmpty) {
        return tag[1];
      }
    }
    return null;
  }
}
