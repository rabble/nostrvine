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
