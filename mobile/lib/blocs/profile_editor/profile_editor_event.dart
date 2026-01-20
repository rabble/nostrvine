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
}
