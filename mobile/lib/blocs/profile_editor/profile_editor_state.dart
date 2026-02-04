// ABOUTME: State class for the ProfileEditorBloc
// ABOUTME: Represents status and errors for profile save operations

part of 'profile_editor_bloc.dart';

/// Status of the profile editor operation.
enum ProfileEditorStatus {
  /// Initial state, no operation in progress.
  initial,

  /// Profile save operation in progress.
  loading,

  /// Profile saved successfully (including username if provided).
  success,

  /// Operation failed - check [ProfileEditorState.error] for details.
  failure,

  /// Waiting for user confirmation before saving.
  confirmationRequired,
}

/// Error types for l10n-friendly error handling.
///
/// The UI layer should map these to localized strings.
enum ProfileEditorError {
  /// Failed to publish profile to Nostr relays.
  publishFailed,

  /// Failed to claim username (network error or other issue).
  claimFailed,

  /// Username was already taken by another user.
  usernameTaken,

  /// Username is reserved - user should contact support.
  usernameReserved,
}

/// Status of username validation/checking.
enum UsernameStatus {
  /// No validation in progress (initial or cleared state).
  idle,

  /// Checking username availability with API.
  checking,

  /// Username is available for registration.
  available,

  /// Username is already taken by another user.
  taken,

  /// Username is reserved - user should contact support.
  reserved,

  /// Validation error (format or network error).
  error,
}

/// Validation errors for username input.
///
/// The UI layer should map these to localized strings.
enum UsernameValidationError {
  /// Username contains invalid characters.
  ///
  /// Valid characters: letters, numbers, hyphens, underscores, periods.
  invalidFormat,

  /// Username length is outside allowed range (3-20 characters).
  invalidLength,

  /// Failed to check username availability due to network error.
  networkError,
}

/// State for the ProfileEditorBloc.
final class ProfileEditorState extends Equatable {
  const ProfileEditorState({
    this.status = ProfileEditorStatus.initial,
    this.error,
    this.pendingEvent,
    this.username = '',
    this.usernameStatus = UsernameStatus.idle,
    this.usernameError,
    this.reservedUsernames = const {},
  });

  /// Current status of the operation.
  final ProfileEditorStatus status;

  /// Error type when [status] is [ProfileEditorStatus.failure].
  final ProfileEditorError? error;

  /// Pending event awaiting confirmation (for blank profile overwrite warning).
  final ProfileSaved? pendingEvent;

  /// Current username being edited.
  final String username;

  /// Status of username validation.
  final UsernameStatus usernameStatus;

  /// Error message for username validation (when status is error).
  final UsernameValidationError? usernameError;

  /// Cache of reserved usernames (403 responses from claim API).
  final Set<String> reservedUsernames;

  /// Creates a copy with updated values.
  ProfileEditorState copyWith({
    ProfileEditorStatus? status,
    ProfileEditorError? error,
    ProfileSaved? pendingEvent,
    String? username,
    UsernameStatus? usernameStatus,
    UsernameValidationError? usernameError,
    Set<String>? reservedUsernames,
  }) {
    return ProfileEditorState(
      status: status ?? this.status,
      error: error,
      pendingEvent: pendingEvent,
      username: username ?? this.username,
      usernameStatus: usernameStatus ?? this.usernameStatus,
      usernameError: usernameError,
      reservedUsernames: reservedUsernames ?? this.reservedUsernames,
    );
  }

  @override
  List<Object?> get props => [
    status,
    error,
    pendingEvent,
    username,
    usernameStatus,
    usernameError,
  ];
}
