// ABOUTME: Parses collaborator invite DMs from structured NIP-17 tags.
// ABOUTME: Ignores plaintext fallback copy to avoid ambiguous invite parsing.

import 'package:dm_repository/dm_repository.dart';
import 'package:models/models.dart';
import 'package:openvine/models/collaborator_invite.dart';

class CollaboratorInviteParser {
  const CollaboratorInviteParser._();

  static CollaboratorInvite? parse(DmMessage message) {
    final metadata = parseCollaboratorInviteRumorTags(message.tags);
    if (metadata == null) return null;

    return CollaboratorInvite(
      messageId: message.id,
      videoAddress: metadata.videoAddress,
      videoKind: metadata.videoKind,
      creatorPubkey: metadata.creatorPubkey,
      videoDTag: metadata.videoDTag,
      role: metadata.role,
      relayHint: metadata.relayHint,
      title: metadata.title,
      thumbnailUrl: metadata.thumbnailUrl,
    );
  }
}
