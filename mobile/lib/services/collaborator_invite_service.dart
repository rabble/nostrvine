// ABOUTME: Sends encrypted collaborator invites via NIP-17 direct messages.
// ABOUTME: Builds readable fallback content plus structured collab tags.

import 'package:dm_repository/dm_repository.dart';
import 'package:equatable/equatable.dart';

class CollaboratorInviteResult extends Equatable {
  const CollaboratorInviteResult({
    required this.success,
    this.messageEventId,
    this.error,
  });

  final bool success;
  final String? messageEventId;
  final String? error;

  @override
  List<Object?> get props => [success, messageEventId, error];
}

class CollaboratorInviteBatchResult extends Equatable {
  const CollaboratorInviteBatchResult({
    required this.results,
  });

  final Map<String, CollaboratorInviteResult> results;

  bool get hasFailures => results.values.any((result) => !result.success);

  @override
  List<Object?> get props => [results];
}

class CollaboratorInviteService {
  const CollaboratorInviteService({
    required DmRepository dmRepository,
    this.defaultRelayHint = 'wss://relay.divine.video',
  }) : _dmRepository = dmRepository;

  final DmRepository _dmRepository;
  final String defaultRelayHint;

  /// Suffix that uniquely identifies the plaintext fallback body of a
  /// collaborator invite DM — kept in sync with [_buildContent]. The
  /// conversation view uses this to suppress legacy NIP-04 invite
  /// duplicates that cannot be turned into actionable cards (#3559).
  static const String invitePlaintextSuffix =
      'Open diVine to review and accept.';

  Future<CollaboratorInviteResult> sendInvite({
    required String collaboratorPubkey,
    required String creatorPubkey,
    required String videoAddress,
    String? title,
    String? thumbnailUrl,
    String? relayHint,
  }) async {
    final content = _buildContent(title);
    final tags = _buildTags(
      creatorPubkey: creatorPubkey,
      videoAddress: videoAddress,
      title: title,
      thumbnailUrl: thumbnailUrl,
      relayHint: relayHint ?? defaultRelayHint,
    );

    final result = await _dmRepository.sendMessage(
      recipientPubkey: collaboratorPubkey,
      content: content,
      additionalTags: tags,
      // Structured invites cannot be represented in NIP-04; the legacy
      // fallback would publish a duplicate plaintext message that reads
      // "Open diVine to review and accept" inside diVine itself (#3559).
      skipNip04Fallback: true,
    );

    return CollaboratorInviteResult(
      success: result.success,
      messageEventId: result.messageEventId,
      error: result.error,
    );
  }

  Future<CollaboratorInviteBatchResult> sendInvites({
    required Iterable<String> collaboratorPubkeys,
    required String creatorPubkey,
    required String videoAddress,
    String? title,
    String? thumbnailUrl,
    String? relayHint,
  }) async {
    final results = <String, CollaboratorInviteResult>{};
    for (final pubkey in collaboratorPubkeys) {
      results[pubkey] = await sendInvite(
        collaboratorPubkey: pubkey,
        creatorPubkey: creatorPubkey,
        videoAddress: videoAddress,
        title: title,
        thumbnailUrl: thumbnailUrl,
        relayHint: relayHint,
      );
    }
    return CollaboratorInviteBatchResult(results: results);
  }

  String _buildContent(String? title) {
    final videoLabel = title == null || title.trim().isEmpty
        ? 'a diVine video'
        : title.trim();
    return 'You were invited to collaborate on $videoLabel. '
        '$invitePlaintextSuffix';
  }

  List<List<String>> _buildTags({
    required String creatorPubkey,
    required String videoAddress,
    required String relayHint,
    String? title,
    String? thumbnailUrl,
  }) {
    return [
      ['divine', 'collab-invite'],
      ['a', videoAddress, relayHint, 'root'],
      ['p', creatorPubkey],
      ['role', 'Collaborator'],
      if (title != null && title.trim().isNotEmpty) ['title', title.trim()],
      if (thumbnailUrl != null && thumbnailUrl.trim().isNotEmpty)
        ['thumb', thumbnailUrl.trim()],
    ];
  }
}
