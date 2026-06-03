// ABOUTME: Screen-scoped Cubit for the BlossomSettingsScreen. Owns the
// ABOUTME: enable toggle and save status; the server-URL TextEditingController
// ABOUTME: stays in the View (the "first hybrid" pattern).

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/blossom_settings/blossom_settings_state.dart';

/// Cubit backing `BlossomSettingsScreen`.
///
/// "First hybrid" migration: the `TextEditingController` lives in the View,
/// not in this Cubit. The Cubit owns the **committed** server URL (snapshotted
/// once on `load()` so the View can seed its controller) and the **save
/// lifecycle** (loading / ready / saving / saveSuccess / saveFailure). The
/// View hands the controller's current text back to `save(serverUrl)` at the
/// moment of submission.
///
/// URL validation matches the pre-migration screen exactly:
///  - `Uri.tryParse` + `hasScheme` + `hasAuthority` are required.
///  - Scheme must be `https`, except for the documented loopback exception
///    (10.0.2.2, localhost, 127.0.0.1) that keeps the local Docker stack
///    working under release native transport security (#3358 / #3788).
class BlossomSettingsCubit extends Cubit<BlossomSettingsState> {
  BlossomSettingsCubit({required BlossomUploadService blossomUploadService})
    : _service = blossomUploadService,
      super(const BlossomSettingsState());

  final BlossomUploadService _service;

  /// Hosts on which a plain `http://` URL is accepted (release native
  /// transport security pins the same allowlist — see #3358 / #3788).
  static const Set<String> _loopbackHttpHosts = {
    '10.0.2.2',
    'localhost',
    '127.0.0.1',
  };

  /// Snapshots the persisted settings into state. The committed
  /// `serverUrl` is exposed as [BlossomSettingsState.initialServerUrl] so
  /// the View can seed its `TextEditingController` once on the
  /// `loading → ready` transition.
  Future<void> load() async {
    emit(state.copyWith(status: BlossomSettingsStatus.loading));
    try {
      final isEnabled = await _service.isBlossomEnabled();
      final serverUrl = await _service.getBlossomServer();
      emit(
        state.copyWith(
          status: BlossomSettingsStatus.ready,
          isBlossomEnabled: isEnabled,
          initialServerUrl: serverUrl ?? '',
        ),
      );
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(state.copyWith(status: BlossomSettingsStatus.ready));
    }
  }

  /// Toggle the "use custom Blossom server" flag locally. Not persisted
  /// until `save(...)` runs.
  void setEnabled(bool value) {
    emit(state.copyWith(isBlossomEnabled: value));
  }

  /// Persist [serverUrl] + the enable flag.
  ///
  /// On success: emits `saveSuccess`. The View handles snackbar + pop on
  /// that transition via `BlocListener`.
  /// On validation or service failure: emits `saveFailure` with a
  /// [BlossomSaveFailureKey] the View maps to a localized snackbar.
  Future<void> save(String serverUrl) async {
    final trimmed = serverUrl.trim();
    _resetPreviousSaveFailure();
    if (state.isBlossomEnabled && trimmed.isNotEmpty) {
      final validationError = _validateServerUrl(trimmed);
      if (validationError != null) {
        emit(
          state.copyWith(
            status: BlossomSettingsStatus.saveFailure,
            saveFailureMessageKey: validationError,
          ),
        );
        return;
      }
    }

    emit(state.copyWith(status: BlossomSettingsStatus.saving));
    try {
      await _service.setBlossomEnabled(state.isBlossomEnabled);
      if (state.isBlossomEnabled && trimmed.isNotEmpty) {
        await _service.setBlossomServer(trimmed);
      } else {
        await _service.setBlossomServer(null);
      }
      emit(state.copyWith(status: BlossomSettingsStatus.saveSuccess));
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(
        state.copyWith(
          status: BlossomSettingsStatus.saveFailure,
          saveFailureMessageKey: BlossomSaveFailureKey.genericFailure,
        ),
      );
    }
  }

  void _resetPreviousSaveFailure() {
    if (state.status != BlossomSettingsStatus.saveFailure &&
        state.saveFailureMessageKey == null) {
      return;
    }
    emit(
      state.copyWith(
        status: BlossomSettingsStatus.ready,
        saveFailureMessageKey: null,
      ),
    );
  }

  BlossomSaveFailureKey? _validateServerUrl(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return BlossomSaveFailureKey.invalidServerUrl;
    }
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    final isLoopbackHttp =
        scheme == 'http' && _loopbackHttpHosts.contains(host);
    if (scheme != 'https' && !isLoopbackHttp) {
      return BlossomSaveFailureKey.mustUseHttps;
    }
    return null;
  }
}
