// ABOUTME: Bloc for server-driven invite gating before account creation
// ABOUTME: Loads onboarding mode, validates invite codes, and stores invite access grants

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:invite_api_client/invite_api_client.dart';
import 'package:openvine/blocs/invite_gate/invite_gate_event.dart';
import 'package:openvine/blocs/invite_gate/invite_gate_state.dart';
import 'package:openvine/utils/unified_logger.dart';

class InviteGateBloc extends Bloc<InviteGateEvent, InviteGateState> {
  InviteGateBloc({required InviteApiClient inviteApiClient})
    : _inviteApiClient = inviteApiClient,
      super(const InviteGateState()) {
    on<InviteGateConfigRequested>(
      _onConfigRequested,
      transformer: droppable(),
    );
    on<InviteGateCodeSubmitted>(
      _onCodeSubmitted,
      transformer: droppable(),
    );
    on<InviteGateGeneralErrorSet>(_onGeneralErrorSet);
    on<InviteGateTransientCleared>(_onTransientCleared);
    on<InviteGateAccessGranted>(_onAccessGranted);
    on<InviteGateAccessCleared>(_onAccessCleared);
  }

  final InviteApiClient _inviteApiClient;

  Future<void> _onConfigRequested(
    InviteGateConfigRequested event,
    Emitter<InviteGateState> emit,
  ) async {
    if (!event.force) {
      if (state.configStatus == InviteGateConfigStatus.loading) {
        return;
      }
      if (state.configStatus == InviteGateConfigStatus.success &&
          state.config != null) {
        return;
      }
    }

    emit(
      state.copyWith(
        configStatus: InviteGateConfigStatus.loading,
        clearGeneralError: true,
      ),
    );

    try {
      final config = await _inviteApiClient.getClientConfig();
      emit(
        state.copyWith(
          configStatus: InviteGateConfigStatus.success,
          config: config,
        ),
      );
    } on InviteApiException catch (error) {
      Log.error(
        'Failed to load invite config: ${error.message}',
        name: 'InviteGateBloc',
        category: LogCategory.auth,
      );
      emit(
        state.copyWith(
          configStatus: InviteGateConfigStatus.failure,
          clearConfig: true,
        ),
      );
    } catch (error) {
      Log.error(
        'Unexpected invite config error: $error',
        name: 'InviteGateBloc',
        category: LogCategory.auth,
      );
      emit(
        state.copyWith(
          configStatus: InviteGateConfigStatus.failure,
          clearConfig: true,
        ),
      );
    }
  }

  Future<void> _onCodeSubmitted(
    InviteGateCodeSubmitted event,
    Emitter<InviteGateState> emit,
  ) async {
    final normalizedCode = InviteApiClient.normalizeCode(event.rawCode);

    if (!InviteApiClient.looksLikeInviteCode(normalizedCode)) {
      emit(
        state.copyWith(
          inviteCodeError: 'Enter an invite code like ABCD-EFGH.',
          clearGeneralError: true,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        isValidatingCode: true,
        clearInviteCodeError: true,
        clearGeneralError: true,
      ),
    );

    try {
      final result = await _inviteApiClient.validateCode(normalizedCode);

      if (result.canContinue) {
        emit(
          state.copyWith(
            isValidatingCode: false,
            accessGrant: InviteAccessGrant(
              code: result.code ?? normalizedCode,
              validatedAt: DateTime.now(),
            ),
            clearInviteCodeError: true,
            clearGeneralError: true,
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          isValidatingCode: false,
          inviteCodeError: result.used
              ? 'That invite code has already been used or revoked.'
              : 'That invite code does not look valid.',
          clearGeneralError: true,
        ),
      );
    } on InviteApiException catch (error) {
      emit(
        state.copyWith(
          isValidatingCode: false,
          generalError: error.message,
          clearInviteCodeError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isValidatingCode: false,
          generalError: 'Failed to validate invite code',
          clearInviteCodeError: true,
        ),
      );
    }
  }

  void _onGeneralErrorSet(
    InviteGateGeneralErrorSet event,
    Emitter<InviteGateState> emit,
  ) {
    emit(
      state.copyWith(
        generalError: event.error,
        clearGeneralError: event.error == null || event.error!.isEmpty,
      ),
    );
  }

  void _onTransientCleared(
    InviteGateTransientCleared event,
    Emitter<InviteGateState> emit,
  ) {
    if (state.inviteCodeError == null && state.generalError == null) {
      return;
    }

    emit(
      state.copyWith(clearInviteCodeError: true, clearGeneralError: true),
    );
  }

  void _onAccessGranted(
    InviteGateAccessGranted event,
    Emitter<InviteGateState> emit,
  ) {
    emit(
      state.copyWith(
        accessGrant: event.grant,
        clearInviteCodeError: true,
        clearGeneralError: true,
      ),
    );
  }

  void _onAccessCleared(
    InviteGateAccessCleared event,
    Emitter<InviteGateState> emit,
  ) {
    if (!state.hasAccessGrant) {
      return;
    }

    emit(state.copyWith(clearAccessGrant: true));
  }
}
