// ABOUTME: Cubit for managing Bluesky crosspost toggle state
// ABOUTME: Loads status from keycast API and handles optimistic toggle updates

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:openvine/models/atproto_provisioning_state.dart';
import 'package:openvine/repositories/bluesky_crosspost_repository.dart';
import 'package:openvine/services/crosspost_api_client.dart';

part 'crosspost_settings_state.dart';

/// Manages Bluesky crosspost settings for the current user.
///
/// Fetches the current crosspost state from keycast on creation
/// and provides optimistic toggle with rollback on failure.
class CrosspostSettingsCubit extends Cubit<CrosspostSettingsState> {
  CrosspostSettingsCubit({
    required BlueskyCrosspostRepository repository,
    required String pubkey,
    Duration provisioningPollInterval = _defaultProvisioningPollInterval,
  }) : _repository = repository,
       _pubkey = pubkey,
       _provisioningPollInterval = provisioningPollInterval,
       super(const CrosspostSettingsState()) {
    loadStatus();
  }

  static const _defaultProvisioningPollInterval = Duration(seconds: 5);

  final BlueskyCrosspostRepository _repository;
  final String _pubkey;
  final Duration _provisioningPollInterval;
  Timer? _provisioningPollTimer;
  var _userLoadInFlight = false;
  var _pollLoadInFlight = false;
  var _operationGeneration = 0;

  /// Load the current crosspost status from keycast.
  Future<void> loadStatus() => _loadStatus(kind: _StatusLoadKind.user);

  Future<void> _loadStatus({required _StatusLoadKind kind}) async {
    if (isClosed) return;
    final generation = switch (kind) {
      _StatusLoadKind.user => _beginUserLoad(),
      _StatusLoadKind.poll => _beginPollLoad(),
    };
    if (generation == null) return;
    if (kind == _StatusLoadKind.user && !isClosed) {
      emit(
        state.copyWith(
          status: CrosspostSettingsStatus.loading,
          clearError: true,
        ),
      );
    }
    try {
      final result = switch (kind) {
        _StatusLoadKind.user => await _repository.loadStatus(pubkey: _pubkey),
        _StatusLoadKind.poll => _mergeKeycastStatus(
          await _repository.loadKeycastStatus(),
        ),
      };
      if (isClosed || generation != _operationGeneration) return;
      _emitLoaded(result);
    } catch (e, stackTrace) {
      if (isClosed || generation != _operationGeneration) return;
      if (kind == _StatusLoadKind.poll) {
        return;
      }
      addError(e, stackTrace);
      _emitLoadFailure(e);
    } finally {
      switch (kind) {
        case _StatusLoadKind.user:
          _userLoadInFlight = false;
        case _StatusLoadKind.poll:
          _pollLoadInFlight = false;
      }
    }
  }

  int? _beginUserLoad() {
    if (_userLoadInFlight) return null;
    _userLoadInFlight = true;
    return ++_operationGeneration;
  }

  int? _beginPollLoad() {
    if (_pollLoadInFlight || _userLoadInFlight) return null;
    _pollLoadInFlight = true;
    return _operationGeneration;
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
    if (isClosed) return;
    if (state.status == CrosspostSettingsStatus.toggling) return;
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
    final generation = ++_operationGeneration;
    emit(
      state.copyWith(
        status: CrosspostSettingsStatus.toggling,
        enabled: enabled,
        clearError: true,
      ),
    );

    try {
      final result = await _repository.setCrosspost(
        pubkey: _pubkey,
        enabled: enabled,
      );
      if (isClosed || generation != _operationGeneration) return;
      _emitLoaded(result);
    } catch (e, stackTrace) {
      if (isClosed || generation != _operationGeneration) return;
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

  /// Retry provisioning after keycast reports a failed ATProto account setup.
  Future<void> retryProvisioning() => toggleCrosspost(enabled: true);

  /// Clear a surfaced error after the UI has acted on it, returning to a
  /// loaded state so the same error does not fire again.
  void acknowledgeError() {
    if (state.error == null) return;
    if (isClosed) return;
    emit(
      state.copyWith(status: CrosspostSettingsStatus.loaded, clearError: true),
    );
  }

  void _emitLoadFailure(Object error) {
    final claimFailure = error is BlueskyCrosspostStatusException
        ? error
        : null;
    emit(
      CrosspostSettingsState(
        status: CrosspostSettingsStatus.failure,
        enabled: state.enabled,
        username: claimFailure?.username ?? state.username,
        handle: claimFailure?.handle ?? state.handle,
        provisioningState: state.provisioningState,
        did: state.did,
        provisioningError: state.provisioningError,
        usernameClaimStatus:
            claimFailure?.usernameClaimStatus ?? state.usernameClaimStatus,
        error: CrosspostSettingsError.generic,
        attempt: state.attempt + 1,
      ),
    );
  }

  void _emitLoaded(BlueskyCrosspostAccountStatus result) {
    if (isClosed) return;
    emit(
      CrosspostSettingsState(
        status: CrosspostSettingsStatus.loaded,
        enabled: result.crosspostEnabled,
        username: result.username,
        handle: result.handle,
        provisioningState: result.provisioningState,
        did: result.did,
        provisioningError: result.provisioningError,
        usernameClaimStatus: result.usernameClaimStatus,
        attempt: state.attempt,
      ),
    );
    _syncProvisioningPoller(result.provisioningState);
  }

  void _syncProvisioningPoller(AtprotoProvisioningState provisioningState) {
    if (provisioningState == AtprotoProvisioningState.pending) {
      _provisioningPollTimer ??= Timer.periodic(
        _provisioningPollInterval,
        (_) => unawaited(_loadStatus(kind: _StatusLoadKind.poll)),
      );
      return;
    }
    _stopProvisioningPoller();
  }

  BlueskyCrosspostAccountStatus _mergeKeycastStatus(CrosspostStatus status) {
    final username = status.username ?? state.username;
    return BlueskyCrosspostAccountStatus(
      crosspostEnabled: status.crosspostEnabled,
      provisioningState: status.provisioningState,
      usernameClaimStatus: state.usernameClaimStatus,
      username: username,
      handle: status.handle ?? state.handle ?? _handleFor(username),
      did: status.did,
      provisioningError: status.provisioningError,
    );
  }

  String? _handleFor(String? username) {
    if (username == null || username.isEmpty) return null;
    return '$username.divine.video';
  }

  void _stopProvisioningPoller() {
    _provisioningPollTimer?.cancel();
    _provisioningPollTimer = null;
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

  @override
  Future<void> close() {
    _operationGeneration++;
    _stopProvisioningPoller();
    return super.close();
  }
}

enum _StatusLoadKind { user, poll }
