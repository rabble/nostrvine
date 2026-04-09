// ABOUTME: Cubit for fetching and caching invite status from the invite server.
// ABOUTME: Used by settings invites screen and notifications tab.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/models/invite_models.dart';
import 'package:openvine/services/invite_api_service.dart';

part 'invite_status_state.dart';

class InviteStatusCubit extends Cubit<InviteStatusState> {
  InviteStatusCubit({
    required InviteApiService inviteApiService,
  }) : _inviteApiService = inviteApiService,
       super(const InviteStatusState());

  final InviteApiService _inviteApiService;

  Future<void> load() async {
    if (state.status == InviteStatusLoadingStatus.loading) return;

    emit(state.copyWith(status: InviteStatusLoadingStatus.loading));
    try {
      final inviteStatus = await _inviteApiService.getInviteStatus();
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
