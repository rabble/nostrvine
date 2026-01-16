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
}

/// Error types for l10n-friendly error handling.
///
/// The UI layer should map these to localized strings.
enum ProfileEditorError {
  /// Failed to publish profile to Nostr relays.
  publishFailed,

  /// Username was already taken by another user.
  usernameTaken,

  /// Username is reserved - user should contact support.
  usernameReserved,
}

/// State for the ProfileEditorBloc.
final class ProfileEditorState extends Equatable {
  const ProfileEditorState({
    this.status = ProfileEditorStatus.initial,
    this.error,
  });

  /// Current status of the operation.
  final ProfileEditorStatus status;

  /// Error type when [status] is [ProfileEditorStatus.failure].
  final ProfileEditorError? error;

  /// Creates a copy with updated values.
  ProfileEditorState copyWith({
    ProfileEditorStatus? status,
    ProfileEditorError? error,
  }) {
    return ProfileEditorState(status: status ?? this.status, error: error);
  }

  @override
  List<Object?> get props => [status, error];
}
