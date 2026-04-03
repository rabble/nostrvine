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
      final result = await _apiClient.getStatus(_pubkey);
      emit(
        state.copyWith(
          status: CrosspostSettingsStatus.loaded,
          enabled: result.crosspostEnabled,
          handle: result.handle,
          provisioningState: result.provisioningState,
        ),
      );
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(state.copyWith(status: CrosspostSettingsStatus.failure));
    }
  }

  /// Toggle crossposting with optimistic update.
  ///
  /// Immediately emits the new value, then calls the API.
  /// Reverts on failure.
  Future<void> toggleCrosspost({required bool enabled}) async {
    final previousState = state;
    emit(
      state.copyWith(
        status: CrosspostSettingsStatus.toggling,
        enabled: enabled,
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
          handle: result.handle,
          provisioningState: result.provisioningState,
        ),
      );
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      // Revert to previous state on failure
      emit(previousState.copyWith(status: CrosspostSettingsStatus.failure));
    }
  }
}
