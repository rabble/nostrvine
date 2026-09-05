// ABOUTME: Shared Divine collaborator p-tag builder used by both the
// ABOUTME: direct-upload and edit-video publish paths.

import 'package:models/models.dart' show NostrHexUtils;
import 'package:openvine/utils/public_identifier_normalizer.dart';

/// Default relay hint embedded in Divine collaborator p-tags.
const collaboratorInviteRelayHint = 'wss://relay.divine.video';

/// Resolves collaborator identifiers to canonical lowercase-hex pubkeys.
///
/// Invalid identifiers are omitted. The creator is excluded after
/// canonicalization, and duplicate representations retain input order.
Set<String> canonicalCollaboratorPubkeys({
  required Iterable<String> identifiers,
  String? creatorIdentifier,
}) {
  final creatorPubkey = creatorIdentifier == null
      ? null
      : normalizeToHex(creatorIdentifier.trim());
  final pubkeys = <String>{};

  for (final identifier in identifiers) {
    final pubkey = normalizeToHex(identifier.trim());
    if (pubkey == null ||
        !NostrHexUtils.isValidPubkey(pubkey) ||
        pubkey == creatorPubkey) {
      continue;
    }
    pubkeys.add(pubkey);
  }

  return pubkeys;
}

/// Builds the Divine collaborator-marked `p` tag for [identifier].
///
/// Throws when [identifier] cannot resolve to a valid public key. Publishing
/// callers with untrusted collections should use [buildCollaboratorPTags],
/// which omits invalid values.
List<String> buildCollaboratorPTag(String identifier) {
  final pubkey = normalizeToHex(identifier.trim());
  if (pubkey == null || !NostrHexUtils.isValidPubkey(pubkey)) {
    throw ArgumentError.value(identifier, 'identifier', 'Invalid pubkey');
  }
  return ['p', pubkey, collaboratorInviteRelayHint, 'collaborator'];
}

/// Builds Divine collaborator-marked `p` tags for each [pubkey].
///
/// Invalid identifiers are omitted and equivalent representations are
/// deduplicated. Accepts any [Iterable] so callers need not convert first.
List<List<String>> buildCollaboratorPTags(Iterable<String> identifiers) => [
  for (final pubkey in canonicalCollaboratorPubkeys(identifiers: identifiers))
    buildCollaboratorPTag(pubkey),
];

List<List<String>> buildMentionPTags(
  Iterable<String> pubkeys, {
  Iterable<String> excludedPubkeys = const [],
}) {
  final excluded = excludedPubkeys
      .map((pubkey) => pubkey.trim().toLowerCase())
      .where(NostrHexUtils.isValidPubkey)
      .toSet();
  final seen = <String>{};
  final tags = <List<String>>[];

  for (final pubkey in pubkeys) {
    final normalizedPubkey = pubkey.trim().toLowerCase();
    if (!NostrHexUtils.isValidPubkey(normalizedPubkey) ||
        excluded.contains(normalizedPubkey) ||
        !seen.add(normalizedPubkey)) {
      continue;
    }

    tags.add(['p', normalizedPubkey, collaboratorInviteRelayHint, 'mention']);
  }

  return tags;
}
