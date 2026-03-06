// ABOUTME: Cubit for server-driven invite gating before account creation
// ABOUTME: Loads onboarding mode, validates invite codes, and stores invite access grants

import 'package:bloc/bloc.dart';
import 'package:openvine/blocs/invite_gate/invite_gate_state.dart';
import 'package:openvine/models/invite_models.dart';
import 'package:openvine/services/api_service.dart';
import 'package:openvine/services/invite_api_service.dart';
import 'package:openvine/utils/unified_logger.dart';

class InviteGateCubit extends Cubit<InviteGateState> {
  InviteGateCubit({required InviteApiService inviteApiService})
    : _inviteApiService = inviteApiService,
      super(const InviteGateState());

  final InviteApiService _inviteApiService;

  Future<void> ensureConfigLoaded({bool force = false}) async {
    if (!force) {
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
      final config = await _inviteApiService.getClientConfig();
      emit(
        state.copyWith(
          configStatus: InviteGateConfigStatus.success,
          config: config,
        ),
      );
    } on ApiException catch (error) {
      Log.error(
        'Failed to load invite config: ${error.message}',
        name: 'InviteGateCubit',
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
        name: 'InviteGateCubit',
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

  void setGeneralError(String? error) {
    emit(
      state.copyWith(
        generalError: error,
        clearGeneralError: error == null || error.isEmpty,
      ),
    );
  }

  void clearTransientState() {
    if (state.inviteCodeError == null && state.generalError == null) {
      return;
    }

    emit(
      state.copyWith(clearInviteCodeError: true, clearGeneralError: true),
    );
  }

  void grantAccess(InviteAccessGrant grant) {
    emit(
      state.copyWith(
        accessGrant: grant,
        clearInviteCodeError: true,
        clearGeneralError: true,
      ),
    );
  }

  void clearAccessGrant() {
    if (!state.hasAccessGrant) {
      return;
    }

    emit(state.copyWith(clearAccessGrant: true));
  }

  Future<void> validateCode(String rawCode) async {
    if (state.isValidatingCode) {
      return;
    }

    final normalizedCode = InviteApiService.normalizeCode(rawCode);

    if (!InviteApiService.looksLikeInviteCode(normalizedCode)) {
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
      final result = await _inviteApiService.validateCode(normalizedCode);

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
    } on ApiException catch (error) {
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
}
