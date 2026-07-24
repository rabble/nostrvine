// ABOUTME: Orchestrates repository-backed crossposting settings actions
// ABOUTME: Serializes operations and validates native OAuth callbacks

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:openvine/repositories/crossposting_repository.dart';
import 'package:openvine/services/crossposting_api_client.dart';

part 'crossposting_settings_state.dart';

/// Opens an OAuth authorization URL and returns its HTTPS callback.
///
/// A `null` callback means the user closed or cancelled the browser session.
typedef CrosspostingOAuthLauncher = Future<Uri?> Function(Uri authorizationUrl);

class CrosspostingSettingsCubit extends Cubit<CrosspostingSettingsState> {
  CrosspostingSettingsCubit({
    required CrosspostingRepository repository,
    required CrosspostingOAuthLauncher launchOAuth,
  }) : _repository = repository,
       _launchOAuth = launchOAuth,
       super(CrosspostingSettingsState());

  static final Uri returnUrl = Uri.parse(
    'https://divine.video/app/callback',
  );

  final CrosspostingRepository _repository;
  final CrosspostingOAuthLauncher _launchOAuth;

  bool _operationInProgress = false;

  /// Loads settings unless another load, refresh, or mutation already owns the
  /// operation gate.
  Future<void> load() {
    if (!_tryAcquireOperation()) return Future<void>.value();
    return _load(showLoading: true);
  }

  /// Refreshes settings unless another load, refresh, or mutation is running.
  Future<void> refresh() {
    if (!_tryAcquireOperation()) return Future<void>.value();
    return _load(
      showLoading: state.status != CrosspostingSettingsStatus.loaded,
    );
  }

  Future<void> _load({required bool showLoading}) async {
    try {
      if (showLoading &&
          !_emitIfOpen(
            state.copyWith(
              status: CrosspostingSettingsStatus.loading,
              clearError: true,
              clearOutcome: true,
            ),
          )) {
        return;
      }

      final entries = await _repository.loadSettings();
      if (isClosed) return;
      _emitIfOpen(
        state.copyWith(
          status: CrosspostingSettingsStatus.loaded,
          entries: entries,
          clearError: true,
        ),
      );
    } catch (error, stackTrace) {
      _reportError(
        error,
        stackTrace,
        status: showLoading ? CrosspostingSettingsStatus.failure : null,
      );
    } finally {
      _releaseOperation();
    }
  }

  Future<void> connect(CrosspostingPlatform platform) {
    if (!_tryAcquireOperation()) return Future<void>.value();
    return _connect(platform);
  }

  Future<void> _connect(CrosspostingPlatform platform) async {
    _beginAction(CrosspostingPlatformAction.connecting, platform);
    try {
      final start = await _repository.startConnection(
        platform,
        returnUrl: returnUrl,
      );
      if (isClosed) return;

      final callback = await _launchOAuth(start.authorizationUrl);
      if (isClosed) return;

      CrosspostingOAuthOutcome? outcome;
      Object? callbackError;
      if (callback != null) {
        try {
          outcome = _parseCallback(callback, expectedPlatform: platform);
        } catch (error, stackTrace) {
          callbackError = error;
          if (isClosed) return;
          addError(error, stackTrace);
        }
      }

      final entries = await _repository.loadSettings();
      if (isClosed) return;
      if (callbackError != null) {
        _emitActionError(
          CrosspostingSettingsError.generic,
          entries: entries,
        );
        return;
      }

      if (callback == null) {
        _emitIfOpen(
          state.copyWith(
            entries: entries,
            clearPending: true,
            clearError: true,
            clearOutcome: true,
          ),
        );
        return;
      }

      _emitIfOpen(
        state.copyWith(
          entries: entries,
          outcome: outcome,
          outcomePlatform: platform,
          outcomeAttempt: state.outcomeAttempt + 1,
          clearPending: true,
          clearError: true,
        ),
      );
    } catch (error, stackTrace) {
      _reportError(error, stackTrace);
    } finally {
      _releaseOperation();
    }
  }

  Future<void> disconnect(CrosspostingPlatform platform) {
    if (!_tryAcquireOperation()) return Future<void>.value();
    return _disconnect(platform);
  }

  Future<void> _disconnect(CrosspostingPlatform platform) async {
    try {
      final connection = _entryFor(platform)?.connection;
      if (connection == null) return;

      _beginAction(CrosspostingPlatformAction.disconnecting, platform);
      await _repository.disconnect(platform, connection.id);
      if (isClosed) return;

      final entries = await _repository.loadSettings();
      if (isClosed) return;
      _emitIfOpen(
        state.copyWith(
          entries: entries,
          clearPending: true,
          clearError: true,
        ),
      );
    } catch (error, stackTrace) {
      _reportError(error, stackTrace);
    } finally {
      _releaseOperation();
    }
  }

  Future<void> setMode(
    CrosspostingPlatform platform,
    CrosspostingMode mode,
  ) {
    if (!_tryAcquireOperation()) return Future<void>.value();
    return _setMode(platform, mode);
  }

  Future<void> _setMode(
    CrosspostingPlatform platform,
    CrosspostingMode mode,
  ) async {
    try {
      if (_entryFor(platform) == null) return;

      final previousEntries = state.entries;
      _beginAction(
        CrosspostingPlatformAction.savingMode,
        platform,
        entries: [
          for (final entry in state.entries)
            if (entry.platform == platform)
              entry.copyWith(mode: mode)
            else
              entry,
        ],
      );

      try {
        await _repository.setMode(platform, mode);
        if (isClosed) return;
        _emitIfOpen(state.copyWith(clearPending: true, clearError: true));
      } on CrosspostingApiException catch (error, stackTrace) {
        if (isClosed) return;
        addError(error, stackTrace);
        _emitActionError(
          error.kind == CrosspostingApiErrorKind.notConnected
              ? CrosspostingSettingsError.notConnected
              : CrosspostingSettingsError.generic,
          entries: previousEntries,
        );
      } catch (error, stackTrace) {
        if (isClosed) return;
        addError(error, stackTrace);
        _emitActionError(
          CrosspostingSettingsError.generic,
          entries: previousEntries,
        );
      }
    } finally {
      _releaseOperation();
    }
  }

  void acknowledgeError() {
    if (isClosed || state.error == null) return;
    _emitIfOpen(state.copyWith(clearError: true));
  }

  void acknowledgeOutcome() {
    if (isClosed || state.outcome == null) return;
    _emitIfOpen(state.copyWith(clearOutcome: true));
  }

  bool _tryAcquireOperation() {
    if (isClosed || _operationInProgress) return false;
    _operationInProgress = true;
    return true;
  }

  void _releaseOperation() {
    _operationInProgress = false;
  }

  bool _emitIfOpen(CrosspostingSettingsState nextState) {
    if (isClosed) return false;
    emit(nextState);
    return true;
  }

  void _beginAction(
    CrosspostingPlatformAction action,
    CrosspostingPlatform platform, {
    List<CrosspostingPlatformSettings>? entries,
  }) {
    if (isClosed) return;
    _emitIfOpen(
      state.copyWith(
        entries: entries,
        pendingAction: action,
        pendingPlatform: platform,
        clearError: true,
        clearOutcome: true,
      ),
    );
  }

  void _reportError(
    Object error,
    StackTrace stackTrace, {
    CrosspostingSettingsStatus? status,
  }) {
    if (isClosed) return;
    addError(error, stackTrace);
    if (isClosed) return;
    _emitIfOpen(
      state.copyWith(
        status: status,
        error: CrosspostingSettingsError.generic,
        errorAttempt: state.errorAttempt + 1,
        clearPending: true,
        clearOutcome: true,
      ),
    );
  }

  void _emitActionError(
    CrosspostingSettingsError error, {
    List<CrosspostingPlatformSettings>? entries,
  }) {
    if (isClosed) return;
    _emitIfOpen(
      state.copyWith(
        entries: entries,
        error: error,
        errorAttempt: state.errorAttempt + 1,
        clearPending: true,
        clearOutcome: true,
      ),
    );
  }

  CrosspostingPlatformSettings? _entryFor(CrosspostingPlatform platform) {
    for (final entry in state.entries) {
      if (entry.platform == platform) return entry;
    }
    return null;
  }

  CrosspostingOAuthOutcome _parseCallback(
    Uri callback, {
    required CrosspostingPlatform expectedPlatform,
  }) {
    if (callback.scheme != returnUrl.scheme ||
        callback.host != returnUrl.host ||
        callback.path != returnUrl.path ||
        callback.hasPort ||
        callback.userInfo.isNotEmpty ||
        callback.hasFragment) {
      throw const FormatException('Unexpected crossposting callback URL');
    }

    final platformValues = callback.queryParametersAll['platform'];
    final connectionValues = callback.queryParametersAll['connection'];
    final reasonValues = callback.queryParametersAll['reason'];
    if (platformValues?.length != 1 ||
        connectionValues?.length != 1 ||
        (reasonValues != null && reasonValues.length != 1)) {
      throw const FormatException('Invalid crossposting callback parameters');
    }

    final platform = CrosspostingPlatform.fromWireName(platformValues!.single);
    if (platform == null || platform != expectedPlatform) {
      throw const FormatException('Unexpected crossposting callback platform');
    }

    switch (connectionValues!.single) {
      case 'connected':
        return CrosspostingOAuthOutcome.connected;
      case 'failed':
        return reasonValues?.single == 'provider_denied'
            ? CrosspostingOAuthOutcome.denied
            : CrosspostingOAuthOutcome.failed;
      default:
        throw const FormatException('Unexpected crossposting callback result');
    }
  }
}
