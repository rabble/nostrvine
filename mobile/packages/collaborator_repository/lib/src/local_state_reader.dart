// ABOUTME: Abstraction for reading current user's local invite response state.
// ABOUTME: Lets the repository depend on a contract instead of mobile/lib code.

import 'package:models/models.dart';

/// Read-only contract over the local invite-response store. The concrete
/// implementation lives in the app layer (`mobile/lib`) and is wired into
/// the repository through dependency injection.
///
/// Returns `null` when the local store has no entry for the
/// `(videoAddress, creatorPubkey, collaboratorPubkey)` triple — meaning the
/// invite has neither been accepted nor ignored locally.
// One-method port by design: the app layer `implements` this named contract
// (collaborator_invite_local_state_adapter.dart) and injects it; a function
// typedef would erase the named seam this package's boundary relies on.
// ignore: one_member_abstracts
abstract class CollaboratorInviteLocalStateReader {
  CollaboratorStatus? readLocalState({
    required String videoAddress,
    required String creatorPubkey,
    required String collaboratorPubkey,
  });
}
