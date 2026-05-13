// ABOUTME: Shared Divine collaborator p-tag builder used by both the
// ABOUTME: direct-upload and edit-video publish paths.

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
