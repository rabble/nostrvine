// ABOUTME: Cubit for local collaborator invite accept/ignore UI actions.
// ABOUTME: Accept publishes a response; ignore only updates local UX state.

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:openvine/models/collaborator_invite.dart';
import 'package:openvine/services/collaborator_invite_state_store.dart';
import 'package:openvine/services/collaborator_response_service.dart';

class CollaboratorInviteActionsState extends Equatable {
  const CollaboratorInviteActionsState({
    this.inviteStates = const {},
  });

  final Map<String, CollaboratorInviteState> inviteStates;

  CollaboratorInviteState stateFor(CollaboratorInvite invite) {
    return inviteStates[_keyFor(invite)] ?? CollaboratorInviteState.pending;
  }

  CollaboratorInviteActionsState copyWith({
    Map<String, CollaboratorInviteState>? inviteStates,
  }) {
    return CollaboratorInviteActionsState(
      inviteStates: inviteStates ?? this.inviteStates,
    );
  }

  static String _keyFor(CollaboratorInvite invite) {
    return '${invite.videoAddress}|${invite.creatorPubkey}';
  }

  @override
  List<Object?> get props => [inviteStates];
}

class CollaboratorInviteActionsCubit
    extends Cubit<CollaboratorInviteActionsState> {
  CollaboratorInviteActionsCubit({
    required CollaboratorInviteStateStore stateStore,
    required CollaboratorResponseService responseService,
    required String currentUserPubkey,
  }) : _stateStore = stateStore,
       _responseService = responseService,
       _currentUserPubkey = currentUserPubkey,
       super(const CollaboratorInviteActionsState());

  final CollaboratorInviteStateStore _stateStore;
  final CollaboratorResponseService _responseService;
  final String _currentUserPubkey;

  void loadInvites(Iterable<CollaboratorInvite> invites) {
    if (_currentUserPubkey.isEmpty) return;

    final updated = Map<String, CollaboratorInviteState>.of(
      state.inviteStates,
    );
    for (final invite in invites) {
      updated[CollaboratorInviteActionsState._keyFor(invite)] = _stateStore
          .getState(
            videoAddress: invite.videoAddress,
            creatorPubkey: invite.creatorPubkey,
            collaboratorPubkey: _currentUserPubkey,
          );
    }
    emit(state.copyWith(inviteStates: updated));
  }

  Future<void> acceptInvite(CollaboratorInvite invite) async {
    assert(
      _currentUserPubkey != invite.creatorPubkey,
      'CollaboratorInviteCard should not surface accept for sender-side '
      'invites (#3559)',
    );
    if (_currentUserPubkey.isEmpty) return;
    if (_currentUserPubkey == invite.creatorPubkey) return;

    await _setInviteState(invite, CollaboratorInviteState.accepting);

    final result = await _responseService.acceptInvite(invite);
    await _setInviteState(
      invite,
      result.success
          ? CollaboratorInviteState.accepted
          : CollaboratorInviteState.failed,
    );
  }

  Future<void> ignoreInvite(CollaboratorInvite invite) async {
    assert(
      _currentUserPubkey != invite.creatorPubkey,
      'CollaboratorInviteCard should not surface ignore for sender-side '
      'invites (#3559)',
    );
    if (_currentUserPubkey.isEmpty) return;
    if (_currentUserPubkey == invite.creatorPubkey) return;
    await _setInviteState(invite, CollaboratorInviteState.ignored);
  }

  Future<void> _setInviteState(
    CollaboratorInvite invite,
    CollaboratorInviteState inviteState,
  ) async {
    await _stateStore.setState(
      videoAddress: invite.videoAddress,
      creatorPubkey: invite.creatorPubkey,
      collaboratorPubkey: _currentUserPubkey,
      state: inviteState,
    );

    emit(
      state.copyWith(
        inviteStates: {
          ...state.inviteStates,
          CollaboratorInviteActionsState._keyFor(invite): inviteState,
        },
      ),
    );
  }
}
