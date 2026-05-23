// ABOUTME: Cubit for fetching and caching invite status from the invite server.
// ABOUTME: Used by settings invites screen and notifications tab.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:invite_api_client/invite_api_client.dart';

part 'invite_status_state.dart';

class InviteStatusCubit extends Cubit<InviteStatusState> {
  InviteStatusCubit({
    required InviteApiClient inviteApiClient,
    bool Function()? isInviteAuthReady,
  }) : _inviteApiClient = inviteApiClient,
       _isInviteAuthReady = isInviteAuthReady ?? (() => true),
       super(const InviteStatusState());

  final InviteApiClient _inviteApiClient;
  final bool Function() _isInviteAuthReady;

  Future<void> load() async {
    if (state.status == InviteStatusLoadingStatus.loading) return;
    if (!_isInviteAuthReady()) return;

    final previousState = state;
    emit(state.copyWith(status: InviteStatusLoadingStatus.loading));
    try {
      final inviteStatus = await _inviteApiClient.getInviteStatus();
      _emitIfOpen(
        state.copyWith(
          status: InviteStatusLoadingStatus.loaded,
          inviteStatus: inviteStatus,
        ),
      );
    } on InviteApiException catch (e, stackTrace) {
      _handleInviteApiException(
        previousState: previousState,
        error: e,
        stackTrace: stackTrace,
      );
    } catch (e, stackTrace) {
      _emitErrorState(error: e, stackTrace: stackTrace);
    }
  }

  Future<void> generateInvite() async {
    if (state.status == InviteStatusLoadingStatus.loading) return;
    if (!_isInviteAuthReady()) return;

    final previousState = state;
    emit(state.copyWith(status: InviteStatusLoadingStatus.loading));
    try {
      await _inviteApiClient.generateInvite();
      final inviteStatus = await _inviteApiClient.getInviteStatus();
      _emitIfOpen(
        state.copyWith(
          status: InviteStatusLoadingStatus.loaded,
          inviteStatus: inviteStatus,
        ),
      );
    } on InviteApiException catch (e, stackTrace) {
      _handleInviteApiException(
        previousState: previousState,
        error: e,
        stackTrace: stackTrace,
      );
    } catch (e, stackTrace) {
      _emitErrorState(error: e, stackTrace: stackTrace);
    }
  }

  void _emitIfOpen(InviteStatusState nextState) {
    if (isClosed) return;
    emit(nextState);
  }

  void _handleInviteApiException({
    required InviteStatusState previousState,
    required InviteApiException error,
    required StackTrace stackTrace,
  }) {
    if (error.statusCode == 401) {
      _emitIfOpen(previousState);
      return;
    }

    _emitErrorState(error: error, stackTrace: stackTrace);
  }

  void _emitErrorState({
    required Object error,
    required StackTrace stackTrace,
  }) {
    addError(error, stackTrace);
    _emitIfOpen(state.copyWith(status: InviteStatusLoadingStatus.error));
  }
}
