// ABOUTME: Events for the ProfileEditorBloc
// ABOUTME: Defines actions for saving profile and claiming username

part of 'profile_editor_bloc.dart';

/// Base class for all profile editor events.
sealed class ProfileEditorEvent {
  const ProfileEditorEvent();
}

/// Request to save profile and optionally claim a username.
final class ProfileSaved extends ProfileEditorEvent {
  const ProfileSaved({
    required this.pubkey,
    required this.displayName,
    this.about,
    this.username,
    this.picture,
    this.banner,
  });

  /// User's public key in hex format.
  final String pubkey;

  /// Display name (required).
  final String displayName;

  /// Bio/about text (optional).
  final String? about;

  /// Username to claim as `username@divine.video` (optional).
  final String? username;

  /// Profile picture URL (optional).
  final String? picture;

  /// Banner field - can be a hex color (e.g., "0x33ccbf") or URL (optional).
  final String? banner;
}

/// Confirmation to proceed with saving profile despite warnings.
final class ProfileSaveConfirmed extends ProfileEditorEvent {
  const ProfileSaveConfirmed();
}

/// Event triggered when username text changes.
final class UsernameChanged extends ProfileEditorEvent {
  const UsernameChanged(this.username);

  /// The new username value from the text field.
  final String username;
}
