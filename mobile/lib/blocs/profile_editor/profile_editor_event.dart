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
    this.externalNip05,
    this.picture,
    this.banner,
  });

  /// User's public key in hex format.
  final String pubkey;

  /// Display name (required).
  final String displayName;

  /// Bio/about text (optional).
  final String? about;

  /// Username to claim as `_@username.divine.video` (optional, divine mode).
  final String? username;

  /// Full external NIP-05 identifier (optional, external mode).
  ///
  /// When provided, this is used directly as the NIP-05 value without
  /// constructing a divine.video identifier. No username claiming is performed.
  final String? externalNip05;

  /// Profile picture URL (optional).
  final String? picture;

  /// Banner field - can be a hex color (e.g., "0x33ccbf") or URL (optional).
  final String? banner;
}

/// Confirmation to proceed with saving profile despite warnings.
final class ProfileSaveConfirmed extends ProfileEditorEvent {
  const ProfileSaveConfirmed();
}

/// Sets the user's existing claimed username after profile load.
final class InitialUsernameSet extends ProfileEditorEvent {
  const InitialUsernameSet(this.username);

  /// The user's current claimed username extracted from their NIP-05.
  final String username;
}

/// Event triggered when username text changes.
final class UsernameChanged extends ProfileEditorEvent {
  const UsernameChanged(this.username);

  /// The new username value from the text field.
  final String username;
}

/// Event triggered when the NIP-05 mode changes.
final class Nip05ModeChanged extends ProfileEditorEvent {
  const Nip05ModeChanged(this.mode);

  /// The new NIP-05 mode (divine.video or external).
  final Nip05Mode mode;
}

/// Event triggered when external NIP-05 text changes.
final class ExternalNip05Changed extends ProfileEditorEvent {
  const ExternalNip05Changed(this.nip05);

  /// The new external NIP-05 value from the text field.
  final String nip05;
}

/// Sets the user's existing external NIP-05 after profile load.
final class InitialExternalNip05Set extends ProfileEditorEvent {
  const InitialExternalNip05Set(this.nip05);

  /// The user's current external NIP-05 identifier.
  final String nip05;
}
