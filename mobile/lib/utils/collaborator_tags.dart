// ABOUTME: Shared NIP-71 collaborator p-tag builder used by both the
// ABOUTME: direct-upload and edit-video publish paths.

/// Default relay hint embedded in collaborator invite p-tags.
const collaboratorInviteRelayHint = 'wss://relay.divine.video';

/// Builds the standard NIP-71 collaborator p-tag for [pubkey].
List<String> buildCollaboratorPTag(String pubkey) => [
  'p',
  pubkey,
  collaboratorInviteRelayHint,
  'collaborator',
];
