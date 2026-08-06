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

  /// divine-name-server confirms a claimed username, but keycast has not
  /// synced that username yet.
  usernameNotSynced,

  /// Any other failure.
  generic,
}

class CrosspostSettingsState extends Equatable {
  const CrosspostSettingsState({
    this.status = CrosspostSettingsStatus.initial,
    this.enabled = false,
    this.username,
    this.handle,
    this.provisioningState = AtprotoProvisioningState.notLinked,
    this.did,
    this.usernameClaimStatus = UsernameClaimStatus.unknown,
    this.error,
    this.attempt = 0,
    this.userLoadInFlight = false,
    this.pollLoadInFlight = false,
    this.operationGeneration = 0,
    this.provisioningPollAttempts = 0,
    this.provisioningPollingTimedOut = false,
  });

  final CrosspostSettingsStatus status;
  final bool enabled;

  /// The bare local part of the user's `.divine.video` handle, or `null` when
  /// no username has been claimed.
  final String? username;
  final String? handle;
  final AtprotoProvisioningState provisioningState;
  final String? did;
  final UsernameClaimStatus usernameClaimStatus;

  /// The reason the last action failed, set only when [status] is
  /// [CrosspostSettingsStatus.failure].
  final CrosspostSettingsError? error;

  /// Monotonically increasing counter bumped on every failure emit, so that
  /// two identical consecutive failures (e.g. repeatedly tapping enable with
  /// no claimed username) produce distinct states and re-trigger the UI
  /// listener that shows the snackbar.
  final int attempt;

  final bool userLoadInFlight;
  final bool pollLoadInFlight;

  /// Epoch used by async completion guards to discard stale loads and toggles
  /// after a newer user operation has started.
  ///
  /// This is deliberately excluded from [props]. Every current bump also
  /// changes a props-visible field: `_beginUserLoad` sets [userLoadInFlight],
  /// and `toggleCrosspost` moves [status] to
  /// [CrosspostSettingsStatus.toggling]. That invariant is important because a
  /// bump-only emit would be swallowed by Equatable; the new operation would
  /// then discard its own completion when its local generation no longer
  /// matched the unchanged state.
  final int operationGeneration;
  final int provisioningPollAttempts;
  final bool provisioningPollingTimedOut;

  /// Whether the account has been fully provisioned on Bluesky.
  bool get isProvisioned => provisioningState == AtprotoProvisioningState.ready;

  /// Whether the user has claimed a `.divine.video` username, a precondition
  /// for enabling crossposting.
  bool get usernameClaimed =>
      usernameClaimStatus == UsernameClaimStatus.claimed;

  CrosspostSettingsState copyWith({
    CrosspostSettingsStatus? status,
    bool? enabled,
    String? username,
    String? handle,
    AtprotoProvisioningState? provisioningState,
    String? did,
    bool clearDid = false,
    UsernameClaimStatus? usernameClaimStatus,
    CrosspostSettingsError? error,
    bool clearError = false,
    int? attempt,
    bool? userLoadInFlight,
    bool? pollLoadInFlight,
    int? operationGeneration,
    int? provisioningPollAttempts,
    bool? provisioningPollingTimedOut,
  }) {
    return CrosspostSettingsState(
      status: status ?? this.status,
      enabled: enabled ?? this.enabled,
      username: username ?? this.username,
      handle: handle ?? this.handle,
      provisioningState: provisioningState ?? this.provisioningState,
      did: clearDid ? null : (did ?? this.did),
      usernameClaimStatus: usernameClaimStatus ?? this.usernameClaimStatus,
      error: clearError ? null : (error ?? this.error),
      attempt: attempt ?? this.attempt,
      userLoadInFlight: userLoadInFlight ?? this.userLoadInFlight,
      pollLoadInFlight: pollLoadInFlight ?? this.pollLoadInFlight,
      operationGeneration: operationGeneration ?? this.operationGeneration,
      provisioningPollAttempts:
          provisioningPollAttempts ?? this.provisioningPollAttempts,
      provisioningPollingTimedOut:
          provisioningPollingTimedOut ?? this.provisioningPollingTimedOut,
    );
  }

  @override
  List<Object?> get props => [
    status,
    enabled,
    username,
    handle,
    provisioningState,
    did,
    usernameClaimStatus,
    error,
    attempt,
    userLoadInFlight,
    pollLoadInFlight,
    // operationGeneration deliberately excluded; see the field doc.
    provisioningPollAttempts,
    provisioningPollingTimedOut,
  ];
}
