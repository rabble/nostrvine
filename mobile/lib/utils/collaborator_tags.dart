// ABOUTME: Shared Divine collaborator p-tag builder used by both the
// ABOUTME: direct-upload and edit-video publish paths.

import 'package:models/models.dart' show NostrHexUtils;

/// Default relay hint embedded in Divine collaborator p-tags.
const collaboratorInviteRelayHint = 'wss://relay.divine.video';

/// Builds the Divine collaborator-marked `p` tag for [pubkey].
List<String> buildCollaboratorPTag(String pubkey) => [
  'p',
  pubkey,
  collaboratorInviteRelayHint,
  'collaborator',
];

/// Builds Divine collaborator-marked `p` tags for each [pubkey].
///
/// Equivalent to `pubkeys.map(buildCollaboratorPTag).toList()`. Accepts any
/// [Iterable] so callers can pass a `List`, a `Set`, or another iterable
/// without converting.
List<List<String>> buildCollaboratorPTags(Iterable<String> pubkeys) => [
  for (final pubkey in pubkeys) buildCollaboratorPTag(pubkey),
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
