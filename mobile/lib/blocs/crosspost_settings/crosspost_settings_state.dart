// ABOUTME: State for CrosspostSettingsCubit
// ABOUTME: Tracks crosspost toggle, handle, provisioning status, and loading

part of 'crosspost_settings_cubit.dart';

enum CrosspostSettingsStatus { initial, loading, loaded, toggling, failure }

/// The actionable reason a crosspost action failed, so the UI can guide the
/// user instead of silently reverting the toggle.
enum CrosspostSettingsError {
  /// Crossposting cannot be enabled until the user claims a `.divine.video`
  /// username. The UI should route the user into the username-claim flow.
  usernameNotClaimed,

  /// Bluesky publishing is temporarily unavailable; the UI should invite a
  /// retry.
  unavailable,

  /// Any other failure.
  generic,
}

class CrosspostSettingsState extends Equatable {
  const CrosspostSettingsState({
    this.status = CrosspostSettingsStatus.initial,
    this.enabled = false,
    this.username,
    this.handle,
    this.provisioningState,
    this.error,
    this.attempt = 0,
  });

  final CrosspostSettingsStatus status;
  final bool enabled;

  /// The bare local part of the user's `.divine.video` handle, or `null` when
  /// no username has been claimed.
  final String? username;
  final String? handle;
  final String? provisioningState;

  /// The reason the last action failed, set only when [status] is
  /// [CrosspostSettingsStatus.failure].
  final CrosspostSettingsError? error;

  /// Monotonically increasing counter bumped on every failure emit, so that
  /// two identical consecutive failures (e.g. repeatedly tapping enable with
  /// no claimed username) produce distinct states and re-trigger the UI
  /// listener that shows the snackbar.
  final int attempt;

  /// Whether the account has been fully provisioned on Bluesky.
  bool get isProvisioned => provisioningState == 'ready';

  /// Whether the user has claimed a `.divine.video` username, a precondition
  /// for enabling crossposting.
  bool get usernameClaimed => username != null && username!.isNotEmpty;

  CrosspostSettingsState copyWith({
    CrosspostSettingsStatus? status,
    bool? enabled,
    String? username,
    String? handle,
    String? provisioningState,
    CrosspostSettingsError? error,
    bool clearError = false,
    int? attempt,
  }) {
    return CrosspostSettingsState(
      status: status ?? this.status,
      enabled: enabled ?? this.enabled,
      username: username ?? this.username,
      handle: handle ?? this.handle,
      provisioningState: provisioningState ?? this.provisioningState,
      error: clearError ? null : (error ?? this.error),
      attempt: attempt ?? this.attempt,
    );
  }

  @override
  List<Object?> get props => [
    status,
    enabled,
    username,
    handle,
    provisioningState,
    error,
    attempt,
  ];
}
