// ABOUTME: Cubit for managing Bluesky crosspost toggle state
// ABOUTME: Loads status from keycast API and handles optimistic toggle updates

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:openvine/services/crosspost_api_client.dart';

part 'crosspost_settings_state.dart';

/// Manages Bluesky crosspost settings for the current user.
///
/// Fetches the current crosspost state from keycast on creation
/// and provides optimistic toggle with rollback on failure.
class CrosspostSettingsCubit extends Cubit<CrosspostSettingsState> {
  CrosspostSettingsCubit({
    required CrosspostApiClient apiClient,
    required String pubkey,
  }) : _apiClient = apiClient,
       _pubkey = pubkey,
       super(const CrosspostSettingsState()) {
    loadStatus();
  }

  final CrosspostApiClient _apiClient;
  final String _pubkey;

  /// Load the current crosspost status from keycast.
  Future<void> loadStatus() async {
    emit(state.copyWith(status: CrosspostSettingsStatus.loading));
    try {
      final result = await _apiClient.getStatus();
      emit(
        state.copyWith(
          status: CrosspostSettingsStatus.loaded,
          enabled: result.crosspostEnabled,
          username: result.username,
          handle: result.handle,
          provisioningState: result.provisioningState,
          clearError: true,
        ),
      );
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(
        state.copyWith(
          status: CrosspostSettingsStatus.failure,
          error: CrosspostSettingsError.generic,
          attempt: state.attempt + 1,
        ),
      );
    }
  }

  /// Toggle crossposting with optimistic update.
  ///
  /// Enabling requires a claimed `.divine.video` username; without one, the
  /// keycast call is guaranteed to fail, so short-circuit to a
  /// [CrosspostSettingsError.usernameNotClaimed] failure and let the UI route
  /// the user into the claim flow instead of optimistically flipping a toggle
  /// that will snap back.
  ///
  /// Otherwise emits the new value optimistically, calls the API, and reverts
  /// with a categorized [CrosspostSettingsError] on failure.
  Future<void> toggleCrosspost({required bool enabled}) async {
    if (enabled && !state.usernameClaimed) {
      emit(
        state.copyWith(
          status: CrosspostSettingsStatus.failure,
          error: CrosspostSettingsError.usernameNotClaimed,
          attempt: state.attempt + 1,
        ),
      );
      return;
    }

    final previousState = state;
    emit(
      state.copyWith(
        status: CrosspostSettingsStatus.toggling,
        enabled: enabled,
        clearError: true,
      ),
    );

    try {
      final result = await _apiClient.setCrosspost(
        pubkey: _pubkey,
        enabled: enabled,
      );
      emit(
        state.copyWith(
          status: CrosspostSettingsStatus.loaded,
          enabled: result.crosspostEnabled,
          username: result.username,
          handle: result.handle,
          provisioningState: result.provisioningState,
          clearError: true,
        ),
      );
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      // Revert to previous state on failure, tagging the reason.
      emit(
        previousState.copyWith(
          status: CrosspostSettingsStatus.failure,
          error: _errorFromException(e),
          attempt: previousState.attempt + 1,
        ),
      );
    }
  }

  /// Clear a surfaced error after the UI has acted on it, returning to a
  /// loaded state so the same error does not fire again.
  void acknowledgeError() {
    if (state.error == null) return;
    emit(
      state.copyWith(status: CrosspostSettingsStatus.loaded, clearError: true),
    );
  }

  CrosspostSettingsError _errorFromException(Object exception) {
    if (exception is CrosspostApiException) {
      switch (exception.kind) {
        case CrosspostApiErrorKind.usernameNotClaimed:
          return CrosspostSettingsError.usernameNotClaimed;
        case CrosspostApiErrorKind.unavailable:
          return CrosspostSettingsError.unavailable;
        case CrosspostApiErrorKind.generic:
          return CrosspostSettingsError.generic;
      }
    }
    return CrosspostSettingsError.generic;
  }
}
