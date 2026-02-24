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

  /// Username has invalid format (e.g. contains dots, underscores).
  invalidFormat,

  /// Validation error (network or other error).
  error,
}

/// Validation errors for username input.
///
/// The UI layer should map these to localized strings.
enum UsernameValidationError {
  /// Username contains invalid characters.
  ///
  /// Valid characters: lowercase letters, numbers, hyphens, underscores,
  /// periods. Per NIP-05, local parts are lowercase-only (a-z0-9-_.).
  invalidFormat,

  /// Username length is outside allowed range (3-20 characters).
  invalidLength,

  /// Failed to check username availability due to network error.
  networkError,
}

/// Whether the profile editor is in divine.video username or external NIP-05
/// mode.
enum Nip05Mode {
  /// Using divine.video username (default). The username is claimed via API.
  divine,

  /// Using an external NIP-05 identifier (e.g., `alice@example.com`).
  /// No username claiming is performed.
  external_,
}

/// Validation errors for external NIP-05 input.
///
/// The UI layer should map these to localized strings.
enum ExternalNip05ValidationError {
  /// NIP-05 format is invalid (must be `local-part@domain`).
  ///
  /// Valid local-part characters: a-z, 0-9, -, _, . (lowercase only per
  /// NIP-05 spec). Domain must be a valid DNS name.
  invalidFormat,

  /// Domain belongs to divine.video or openvine.co — use divine mode instead.
  divineDomain,
}

/// State for the ProfileEditorBloc.
final class ProfileEditorState extends Equatable {
  const ProfileEditorState({
    this.status = ProfileEditorStatus.initial,
    this.error,
    this.pendingEvent,
    this.username = '',
    this.initialUsername,
    this.usernameStatus = UsernameStatus.idle,
    this.usernameError,
    this.usernameFormatMessage,
    this.reservedUsernames = const {},
    this.nip05Mode = Nip05Mode.divine,
    this.externalNip05 = '',
    this.initialExternalNip05,
    this.externalNip05Error,
  });

  /// Current status of the operation.
  final ProfileEditorStatus status;

  /// Error type when [status] is [ProfileEditorStatus.failure].
  final ProfileEditorError? error;

  /// Pending event awaiting confirmation (for blank profile overwrite warning).
  final ProfileSaved? pendingEvent;

  /// Current username being edited (divine.video mode).
  final String username;

  /// The user's existing claimed username, set once at BLoC creation.
  final String? initialUsername;

  /// Status of username validation.
  final UsernameStatus usernameStatus;

  /// Error message for username validation (when status is error).
  final UsernameValidationError? usernameError;

  /// Human-readable reason when [usernameStatus] is [UsernameStatus.invalidFormat].
  final String? usernameFormatMessage;

  /// Cache of reserved usernames (403 responses from claim API).
  final Set<String> reservedUsernames;

  /// Whether the editor is in divine.video or external NIP-05 mode.
  final Nip05Mode nip05Mode;

  /// Current external NIP-05 being edited (e.g., `alice@example.com`).
  final String externalNip05;

  /// The user's existing external NIP-05, set once at profile load.
  final String? initialExternalNip05;

  /// Validation error for external NIP-05 input.
  final ExternalNip05ValidationError? externalNip05Error;

  /// Whether the username state allows saving the profile (divine.video mode).
  bool get isUsernameSaveReady {
    if (usernameStatus == UsernameStatus.checking) return false;
    if (username.isEmpty) return true;
    if (usernameStatus == UsernameStatus.available) return true;
    if (initialUsername != null &&
        username.toLowerCase() == initialUsername!.toLowerCase()) {
      return true;
    }
    return false;
  }

  /// Whether the external NIP-05 state allows saving the profile.
  bool get isExternalNip05SaveReady {
    if (externalNip05.isEmpty) return true;
    return externalNip05Error == null;
  }

  /// Whether the profile can be saved in the current mode.
  bool get isSaveReady {
    return switch (nip05Mode) {
      Nip05Mode.divine => isUsernameSaveReady,
      Nip05Mode.external_ => isExternalNip05SaveReady,
    };
  }

  /// Creates a copy with updated values.
  ProfileEditorState copyWith({
    ProfileEditorStatus? status,
    ProfileEditorError? error,
    ProfileSaved? pendingEvent,
    String? username,
    String? initialUsername,
    UsernameStatus? usernameStatus,
    UsernameValidationError? usernameError,
    String? usernameFormatMessage,
    Set<String>? reservedUsernames,
    Nip05Mode? nip05Mode,
    String? externalNip05,
    String? initialExternalNip05,
    ExternalNip05ValidationError? externalNip05Error,
  }) {
    return ProfileEditorState(
      status: status ?? this.status,
      error: error,
      pendingEvent: pendingEvent,
      username: username ?? this.username,
      initialUsername: initialUsername ?? this.initialUsername,
      usernameStatus: usernameStatus ?? this.usernameStatus,
      usernameError: usernameError,
      usernameFormatMessage: usernameFormatMessage,
      reservedUsernames: reservedUsernames ?? this.reservedUsernames,
      nip05Mode: nip05Mode ?? this.nip05Mode,
      externalNip05: externalNip05 ?? this.externalNip05,
      initialExternalNip05: initialExternalNip05 ?? this.initialExternalNip05,
      externalNip05Error: externalNip05Error,
    );
  }

  @override
  List<Object?> get props => [
    status,
    error,
    pendingEvent,
    username,
    initialUsername,
    usernameStatus,
    usernameError,
    usernameFormatMessage,
    nip05Mode,
    externalNip05,
    initialExternalNip05,
    externalNip05Error,
  ];
}
