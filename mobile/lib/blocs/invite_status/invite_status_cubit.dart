// ABOUTME: Cubit for fetching and caching invite status from the invite server.
// ABOUTME: Used by settings invites screen and notifications tab.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:invite_api_client/invite_api_client.dart';

part 'invite_status_state.dart';

class InviteStatusCubit extends Cubit<InviteStatusState> {
  InviteStatusCubit({required InviteApiClient inviteApiClient})
    : _inviteApiClient = inviteApiClient,
      super(const InviteStatusState());

  final InviteApiClient _inviteApiClient;

  Future<void> load() async {
    if (state.status == InviteStatusLoadingStatus.loading) return;

    emit(state.copyWith(status: InviteStatusLoadingStatus.loading));
    try {
      final inviteStatus = await _inviteApiClient.getInviteStatus();
      emit(
        state.copyWith(
          status: InviteStatusLoadingStatus.loaded,
          inviteStatus: inviteStatus,
        ),
      );
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(state.copyWith(status: InviteStatusLoadingStatus.error));
    }
  }
}
