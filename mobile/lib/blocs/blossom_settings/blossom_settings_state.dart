// ABOUTME: State for BlossomSettingsCubit — the enable toggle, the persisted
// ABOUTME: server URL snapshot used to seed the View's TextEditingController,
// ABOUTME: and the save lifecycle status.

import 'package:equatable/equatable.dart';

const _unset = Object();

/// Lifecycle of the blossom settings screen.
///
/// `saveSuccess` and `saveFailure` are terminal-for-this-attempt states the
/// View listens to via `BlocListener` to drive a snackbar + back-navigation.
enum BlossomSettingsStatus {
  initial,
  loading,
  ready,
  saving,
  saveSuccess,
  saveFailure,
}

/// State for `BlossomSettingsCubit`.
///
/// "First hybrid" migration: the `TextEditingController` for the server URL
/// stays in the View (controllers are UI plumbing, not Cubit state). This
/// state only carries the **committed** server URL ([initialServerUrl]) —
/// the value the View should seed the controller with when entering the
/// `ready` state. Once the user types, the in-flight URL lives only in the
/// controller until the View hands it back to `save(...)`.
class BlossomSettingsState extends Equatable {
  const BlossomSettingsState({
    this.status = BlossomSettingsStatus.initial,
    this.isBlossomEnabled = false,
    this.initialServerUrl = '',
    this.saveFailureMessageKey,
  });

  final BlossomSettingsStatus status;
  final bool isBlossomEnabled;

  /// Persisted server URL snapshotted at `load()` time.
  ///
  /// The View uses this to seed its `TextEditingController` once when the
  /// status transitions to `ready` — after that, the controller is the
  /// source of truth until the user taps Save.
  final String initialServerUrl;

  /// Identifies which l10n key the View should show on `saveFailure`.
  ///
  /// State doesn't carry error strings (per `state_management.md`) — this is
  /// a closed set of three keys (`invalidServerUrl`, `mustUseHttps`,
  /// `genericFailure`) that the View maps to `context.l10n.xxx`.
  final BlossomSaveFailureKey? saveFailureMessageKey;

  BlossomSettingsState copyWith({
    BlossomSettingsStatus? status,
    bool? isBlossomEnabled,
    String? initialServerUrl,
    Object? saveFailureMessageKey = _unset,
  }) {
    return BlossomSettingsState(
      status: status ?? this.status,
      isBlossomEnabled: isBlossomEnabled ?? this.isBlossomEnabled,
      initialServerUrl: initialServerUrl ?? this.initialServerUrl,
      saveFailureMessageKey: identical(saveFailureMessageKey, _unset)
          ? this.saveFailureMessageKey
          : saveFailureMessageKey as BlossomSaveFailureKey?,
    );
  }

  @override
  List<Object?> get props => [
    status,
    isBlossomEnabled,
    initialServerUrl,
    saveFailureMessageKey,
  ];
}

/// Reasons a `save(...)` attempt failed.
///
/// Closed set so the View can map to `context.l10n.xxx` without holding
/// error strings in state.
enum BlossomSaveFailureKey {
  /// URL failed `Uri.tryParse` / missing scheme/authority.
  invalidServerUrl,

  /// URL parsed but uses non-loopback `http://` — release native transport
  /// security would block the upload at the OS layer (#3358 / #3788).
  mustUseHttps,

  /// Service call threw.
  genericFailure,
}
