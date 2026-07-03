// ABOUTME: Cubit for local collaborator invite accept/ignore UI actions.
// ABOUTME: Accept publishes a response; ignore only updates local UX state.

import 'package:bloc/bloc.dart';
import 'package:collaborator_repository/collaborator_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:models/models.dart';
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
    CollaboratorConfirmationRepository? confirmationRepository,
  }) : _stateStore = stateStore,
       _responseService = responseService,
       _currentUserPubkey = currentUserPubkey,
       _confirmationRepository = confirmationRepository,
       super(const CollaboratorInviteActionsState());

  final CollaboratorInviteStateStore _stateStore;
  final CollaboratorResponseService _responseService;
  final String _currentUserPubkey;
  final CollaboratorConfirmationRepository? _confirmationRepository;

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
      !_isCurrentUserInviteCreator(invite),
      'CollaboratorInviteCard should not surface accept for sender-side '
      'invites (#3559)',
    );
    if (_currentUserPubkey.isEmpty) return;
    if (_isCurrentUserInviteCreator(invite)) return;

    await _setInviteState(invite, CollaboratorInviteState.accepting);

    final result = await _responseService.acceptInvite(invite);
    await _setInviteState(
      invite,
      result.success
          ? CollaboratorInviteState.accepted
          : CollaboratorInviteState.failed,
    );
    if (result.success) {
      _confirmationRepository?.markLocal(
        videoAddress: invite.videoAddress,
        collaboratorPubkey: _currentUserPubkey,
        status: CollaboratorStatus.confirmed,
      );
    }
  }

  Future<void> ignoreInvite(CollaboratorInvite invite) async {
    assert(
      !_isCurrentUserInviteCreator(invite),
      'CollaboratorInviteCard should not surface ignore for sender-side '
      'invites (#3559)',
    );
    if (_currentUserPubkey.isEmpty) return;
    if (_isCurrentUserInviteCreator(invite)) return;
    await _setInviteState(invite, CollaboratorInviteState.ignored);
    _confirmationRepository?.markLocal(
      videoAddress: invite.videoAddress,
      collaboratorPubkey: _currentUserPubkey,
      status: CollaboratorStatus.ignored,
    );
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

    if (!isClosed) {
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

  bool _isCurrentUserInviteCreator(CollaboratorInvite invite) =>
      _currentUserPubkey.toLowerCase() == invite.creatorPubkey.toLowerCase();
}
