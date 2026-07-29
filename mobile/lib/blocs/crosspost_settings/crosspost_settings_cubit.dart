// ABOUTME: Cubit for managing Bluesky crosspost toggle state
// ABOUTME: Loads status from keycast API and handles optimistic toggle updates

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:openvine/services/crosspost_api_client.dart';
import 'package:profile_repository/profile_repository.dart';

part 'crosspost_settings_state.dart';

/// Manages Bluesky crosspost settings for the current user.
///
/// Fetches the current crosspost state from keycast on creation
/// and provides optimistic toggle with rollback on failure.
class CrosspostSettingsCubit extends Cubit<CrosspostSettingsState> {
  CrosspostSettingsCubit({
    required CrosspostApiClient apiClient,
    required ProfileRepository profileRepository,
    required String pubkey,
  }) : _apiClient = apiClient,
       _profileRepository = profileRepository,
       _pubkey = pubkey,
       super(const CrosspostSettingsState()) {
    loadStatus();
  }

  final CrosspostApiClient _apiClient;
  final ProfileRepository _profileRepository;
  final String _pubkey;

  /// Load the current crosspost status from keycast.
  Future<void> loadStatus() async {
    emit(state.copyWith(status: CrosspostSettingsStatus.loading));
    final claimLookup = await _lookupUsernameClaimStatus();
    try {
      final result = await _apiClient.getStatus();
      final displayUsername = result.username ?? claimLookup.username;
      emit(
        CrosspostSettingsState(
          status: CrosspostSettingsStatus.loaded,
          enabled: result.crosspostEnabled,
          username: displayUsername,
          handle: _handleFor(displayUsername),
          provisioningState: result.provisioningState,
          usernameClaimStatus: claimLookup.status,
          attempt: state.attempt,
        ),
      );
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(
        CrosspostSettingsState(
          status: CrosspostSettingsStatus.failure,
          enabled: state.enabled,
          username: claimLookup.username,
          handle: _handleFor(claimLookup.username),
          provisioningState: state.provisioningState,
          usernameClaimStatus: claimLookup.status,
          error: CrosspostSettingsError.generic,
          attempt: state.attempt + 1,
        ),
      );
    }
  }

  /// Toggle crossposting with optimistic update.
  ///
  /// Enabling requires a confirmed missing `.divine.video` username to
  /// short-circuit. Unknown claim status is allowed through so the API can
  /// report the current crosspost precondition instead of sending users into a
  /// claim flow after a transient lookup failure.
  ///
  /// A confirmed missing username short-circuits to a
  /// [CrosspostSettingsError.usernameNotClaimed] failure and let the UI route
  /// the user into the claim flow instead of optimistically flipping a toggle
  /// that will snap back.
  ///
  /// Otherwise emits the new value optimistically, calls the API, and reverts
  /// with a categorized [CrosspostSettingsError] on failure.
  Future<void> toggleCrosspost({required bool enabled}) async {
    if (enabled &&
        state.usernameClaimStatus == UsernameClaimStatus.notClaimed) {
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
          username: result.username ?? state.username,
          handle: result.handle ?? state.handle,
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
          error: _errorFromException(e, previousState.usernameClaimStatus),
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

  Future<({UsernameClaimStatus status, String? username})>
  _lookupUsernameClaimStatus() async {
    final lookup = await _profileRepository.lookupUsernameByPubkey(
      pubkeyHex: _pubkey,
    );
    return switch (lookup) {
      DivineUsernameFound(:final canonical) => (
        status: UsernameClaimStatus.claimed,
        username: canonical,
      ),
      DivineUsernameNotFound() => (
        status: UsernameClaimStatus.notClaimed,
        username: null,
      ),
      DivineUsernameUnknown() => (
        status: UsernameClaimStatus.unknown,
        username: null,
      ),
    };
  }

  String? _handleFor(String? username) {
    if (username == null || username.isEmpty) return null;
    return '$username.divine.video';
  }

  CrosspostSettingsError _errorFromException(
    Object exception,
    UsernameClaimStatus claimStatus,
  ) {
    if (exception is CrosspostApiException) {
      switch (exception.kind) {
        case CrosspostApiErrorKind.usernameNotClaimed:
          return switch (claimStatus) {
            UsernameClaimStatus.claimed =>
              CrosspostSettingsError.usernameNotSynced,
            UsernameClaimStatus.notClaimed =>
              CrosspostSettingsError.usernameNotClaimed,
            UsernameClaimStatus.unknown => CrosspostSettingsError.unavailable,
          };
        case CrosspostApiErrorKind.unavailable:
          return CrosspostSettingsError.unavailable;
        case CrosspostApiErrorKind.generic:
          return CrosspostSettingsError.generic;
      }
    }
    return CrosspostSettingsError.generic;
  }
}
