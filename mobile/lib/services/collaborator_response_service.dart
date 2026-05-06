// ABOUTME: Publishes collaborator acceptance events.
// ABOUTME: Acceptance mirrors Connect by copying the source video under the accepter.

import 'package:equatable/equatable.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/models/collaborator_invite.dart';
import 'package:openvine/services/auth_service.dart';

typedef SourceVideoLoader = Future<VideoEvent?> Function(String videoAddress);

class CollaboratorResponseResult extends Equatable {
  const CollaboratorResponseResult({
    required this.success,
    this.eventId,
    this.error,
  });

  const CollaboratorResponseResult.success(String eventId)
    : this(success: true, eventId: eventId);

  const CollaboratorResponseResult.failure(String error)
    : this(success: false, error: error);

  final bool success;
  final String? eventId;
  final String? error;

  @override
  List<Object?> get props => [success, eventId, error];
}

class CollaboratorResponseService {
  const CollaboratorResponseService({
    required AuthService authService,
    required NostrClient nostrClient,
    SourceVideoLoader? loadSourceVideo,
    this.defaultRelayHint = 'wss://relay.divine.video',
  }) : _authService = authService,
       _nostrClient = nostrClient,
       _loadSourceVideo = loadSourceVideo;

  final AuthService _authService;
  final NostrClient _nostrClient;
  final SourceVideoLoader? _loadSourceVideo;
  final String defaultRelayHint;

  Future<CollaboratorResponseResult> acceptInvite(
    CollaboratorInvite invite,
  ) async {
    try {
      final currentPubkey = _authService.currentPublicKeyHex;
      if (currentPubkey == null || currentPubkey.isEmpty) {
        return const CollaboratorResponseResult.failure(
          'Could not determine collaborator pubkey',
        );
      }

      final sourceVideo = await _loadSourceVideo?.call(invite.videoAddress);
      if (sourceVideo == null) {
        return const CollaboratorResponseResult.failure(
          'Could not load source video for collaborator acceptance',
        );
      }

      final event = await _authService.createAndSignEvent(
        kind: invite.videoKind,
        content: sourceVideo.content,
        tags: _buildAcceptanceTags(
          invite: invite,
          sourceVideo: sourceVideo,
          accepterPubkey: currentPubkey,
        ),
      );

      if (event == null) {
        return const CollaboratorResponseResult.failure(
          'Could not sign collaborator acceptance',
        );
      }

      final published = await _nostrClient.publishEvent(event);
      if (published == null) {
        return const CollaboratorResponseResult.failure(
          'Could not publish collaborator acceptance',
        );
      }

      return CollaboratorResponseResult.success(published.id);
    } on Object catch (error) {
      return CollaboratorResponseResult.failure(error.toString());
    }
  }

  List<List<String>> _buildAcceptanceTags({
    required CollaboratorInvite invite,
    required VideoEvent sourceVideo,
    required String accepterPubkey,
  }) {
    final relayHint = invite.relayHint ?? defaultRelayHint;
    final tags =
        (sourceVideo.nostrEventTags.isNotEmpty
                ? sourceVideo.nostrEventTags
                : _fallbackSourceTags(invite: invite, sourceVideo: sourceVideo))
            .where(
              (tag) => !_isCollaboratorTagFor(tag, accepterPubkey),
            )
            .map(List<String>.from)
            .toList();

    if (!tags.any((tag) => tag.isNotEmpty && tag[0] == 'd')) {
      tags.insert(0, ['d', invite.videoDTag]);
    }

    if (!_hasCollaboratorTag(tags, sourceVideo.pubkey)) {
      tags.add(['p', sourceVideo.pubkey, '', 'collaborator']);
    }

    if (sourceVideo.id.isNotEmpty) {
      tags.add(['e', sourceVideo.id, '', 'source']);
    }
    tags.add(['a', invite.videoAddress, relayHint, 'source']);

    return tags;
  }

  List<List<String>> _fallbackSourceTags({
    required CollaboratorInvite invite,
    required VideoEvent sourceVideo,
  }) {
    return [
      ['d', invite.videoDTag],
      if (sourceVideo.title != null && sourceVideo.title!.trim().isNotEmpty)
        ['title', sourceVideo.title!.trim()],
      if (sourceVideo.videoUrl != null &&
          sourceVideo.videoUrl!.trim().isNotEmpty)
        ['url', sourceVideo.videoUrl!.trim()],
      if (sourceVideo.thumbnailUrl != null &&
          sourceVideo.thumbnailUrl!.trim().isNotEmpty)
        ['thumb', sourceVideo.thumbnailUrl!.trim()],
    ];
  }

  bool _isCollaboratorTagFor(List<String> tag, String pubkey) {
    return tag.length >= 4 &&
        tag[0] == 'p' &&
        tag[1] == pubkey &&
        tag[3].toLowerCase() == 'collaborator';
  }

  bool _hasCollaboratorTag(List<List<String>> tags, String pubkey) {
    return tags.any((tag) => _isCollaboratorTagFor(tag, pubkey));
  }
}
