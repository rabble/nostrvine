// ABOUTME: Publishes collaborator acceptance events.
// ABOUTME: Acceptance is a collaborator-authored public response to a video address.

import 'package:equatable/equatable.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/constants/collaboration_event_kinds.dart';
import 'package:openvine/models/collaborator_invite.dart';
import 'package:openvine/services/auth_service.dart';

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
    this.defaultRelayHint = 'wss://relay.divine.video',
  }) : _authService = authService,
       _nostrClient = nostrClient;

  final AuthService _authService;
  final NostrClient _nostrClient;
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

      final event = await _authService.createAndSignEvent(
        kind: CollaborationEventKinds.collaboratorResponse,
        content: '',
        tags: _buildAcceptanceTags(invite),
      );

      if (event == null) {
        return const CollaboratorResponseResult.failure(
          'Could not sign collaborator acceptance',
        );
      }

      final published = await _nostrClient.publishEvent(event);
      if (published case PublishSuccess(:final event)) {
        return CollaboratorResponseResult.success(event.id);
      }
      return const CollaboratorResponseResult.failure(
        'Could not publish collaborator acceptance',
      );
    } on Object catch (error) {
      return CollaboratorResponseResult.failure(error.toString());
    }
  }

  List<List<String>> _buildAcceptanceTags(CollaboratorInvite invite) {
    final relayHint = invite.relayHint ?? defaultRelayHint;
    return [
      ['d', invite.videoAddress],
      ['a', invite.videoAddress, relayHint, 'root'],
      ['p', invite.creatorPubkey],
      ['role', invite.role],
      ['status', 'accepted'],
    ];
  }
}
