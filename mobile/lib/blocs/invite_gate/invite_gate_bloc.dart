// ABOUTME: Bloc for server-driven invite gating before account creation
// ABOUTME: Validates invite codes and stores invite access grants

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:invite_api_client/invite_api_client.dart';
import 'package:openvine/blocs/invite_gate/invite_gate_event.dart';
import 'package:openvine/blocs/invite_gate/invite_gate_state.dart';
import 'package:openvine/utils/invite_error_utils.dart';

class InviteGateBloc extends Bloc<InviteGateEvent, InviteGateState> {
  InviteGateBloc({required InviteApiClient inviteApiClient})
    : _inviteApiClient = inviteApiClient,
      super(const InviteGateState()) {
    on<InviteGateCodeSubmitted>(_onCodeSubmitted, transformer: droppable());
    on<InviteGateGeneralErrorSet>(_onGeneralErrorSet);
    on<InviteGateTransientCleared>(_onTransientCleared);
    on<InviteGateAccessGranted>(_onAccessGranted);
    on<InviteGateAccessCleared>(_onAccessCleared);
  }

  final InviteApiClient _inviteApiClient;

  Future<void> _onCodeSubmitted(
    InviteGateCodeSubmitted event,
    Emitter<InviteGateState> emit,
  ) async {
    final normalizedCode = InviteApiClient.normalizeCode(event.rawCode);

    if (!InviteApiClient.looksLikeInviteCode(normalizedCode)) {
      emit(
        state.copyWith(
          inviteCodeError: InviteCodeError.malformed,
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
              creatorSlug: result.creatorSlug,
              creatorDisplayName: result.creatorDisplayName,
              remaining: result.remaining,
            ),
            clearInviteCodeError: true,
            clearGeneralError: true,
          ),
        );
        return;
      }

      final inviteCodeError = _inviteCodeErrorForResult(result);
      final generalError = _generalErrorForResult(result);
      emit(
        state.copyWith(
          isValidatingCode: false,
          inviteCodeError: inviteCodeError,
          generalError: generalError,
          clearInviteCodeError: inviteCodeError == null,
          clearGeneralError: generalError == null,
        ),
      );
    } on InviteApiException catch (error, stackTrace) {
      // Invite API rejection — matrix-NO (API/domain row), so a bare
      // addError. The exception's own `message` can be arbitrary text lifted
      // straight out of the server's response body, which is exactly why it
      // is classified here instead of shown.
      addError(error, stackTrace);
      emit(
        state.copyWith(
          isValidatingCode: false,
          generalError: _generalErrorForException(error),
          clearInviteCodeError: true,
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(
        state.copyWith(
          isValidatingCode: false,
          generalError: InviteGateError.checkFailed,
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
        clearGeneralError: event.error == null,
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

    emit(state.copyWith(clearInviteCodeError: true, clearGeneralError: true));
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

  /// The server already answers with a reason code, so classify from that and
  /// let the UI localize. Rejections that are not about the typed code
  /// (a full or disabled creator page) belong in the block message instead,
  /// and return null here.
  InviteCodeError? _inviteCodeErrorForResult(InviteValidationResult result) {
    switch (result.errorCode) {
      case InviteApiErrorCode.creatorPageFull:
      case InviteApiErrorCode.inviteRevoked:
      case InviteApiErrorCode.inviteCodeRotated:
      case InviteApiErrorCode.creatorPageDisabled:
        return null;
      case InviteApiErrorCode.inviteNotFound:
      case InviteApiErrorCode.inviteInvalidFormat:
        return InviteCodeError.notFound;
    }

    return result.used ? InviteCodeError.alreadyUsed : InviteCodeError.notFound;
  }

  InviteGateError? _generalErrorForResult(InviteValidationResult result) {
    switch (result.errorCode) {
      case InviteApiErrorCode.creatorPageFull:
        return InviteGateError.creatorFull;
      case InviteApiErrorCode.inviteRevoked:
      case InviteApiErrorCode.inviteCodeRotated:
      case InviteApiErrorCode.creatorPageDisabled:
        return InviteGateError.inviteUnavailable;
    }
    return null;
  }

  /// Reuses [InviteErrorUtils.activationFailureReason], which already maps the
  /// whole [InviteApiErrorCode] family — plus status-code and keyword
  /// fallbacks for exceptions that carry no structured code.
  InviteGateError _generalErrorForException(InviteApiException error) {
    switch (InviteErrorUtils.activationFailureReason(error)) {
      case InviteActivationFailureReason.creatorFull:
        return InviteGateError.creatorFull;
      case InviteActivationFailureReason.alreadyUsed:
      case InviteActivationFailureReason.invalid:
        return InviteGateError.inviteUnavailable;
      case InviteActivationFailureReason.authFailure:
      case InviteActivationFailureReason.temporary:
      case InviteActivationFailureReason.unknown:
        return InviteGateError.checkFailed;
    }
  }
}
