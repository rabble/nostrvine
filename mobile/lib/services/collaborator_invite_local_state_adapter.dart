// ABOUTME: Adapts CollaboratorInviteStateStore to the repository's reader.
// ABOUTME: Keeps the collaborator_repository package free of mobile/lib deps.

import 'package:collaborator_repository/collaborator_repository.dart';
import 'package:models/models.dart';
import 'package:openvine/services/collaborator_invite_state_store.dart';

/// Maps the local SharedPreferences-backed invite state store onto the
/// reader contract consumed by `CollaboratorConfirmationRepository`.
///
/// `pending`, `accepting`, and `failed` map to `null` so the repository
/// treats them as "not yet acted" and the render falls back to the
/// pending decoration. Only the terminal states (`accepted`, `ignored`)
/// flip the render.
class CollaboratorInviteLocalStateAdapter
    implements CollaboratorInviteLocalStateReader {
  const CollaboratorInviteLocalStateAdapter(this._store);

  final CollaboratorInviteStateStore _store;

  @override
  CollaboratorStatus? readLocalState({
    required String videoAddress,
    required String creatorPubkey,
    required String collaboratorPubkey,
  }) {
    final raw = _store.getState(
      videoAddress: videoAddress,
      creatorPubkey: creatorPubkey,
      collaboratorPubkey: collaboratorPubkey,
    );
    switch (raw) {
      case CollaboratorInviteState.accepted:
        return CollaboratorStatus.confirmed;
      case CollaboratorInviteState.ignored:
        return CollaboratorStatus.ignored;
      case CollaboratorInviteState.pending:
      case CollaboratorInviteState.accepting:
      case CollaboratorInviteState.failed:
        return null;
    }
  }
}
