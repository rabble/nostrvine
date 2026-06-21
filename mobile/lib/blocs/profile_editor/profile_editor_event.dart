// ABOUTME: Events for the ProfileEditorBloc
// ABOUTME: Defines actions for saving profile, claiming username, and
// ABOUTME: staging avatar / banner uploads for the current edit session.

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
    this.website,
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

  /// Website URL from the Kind-0 `website` field (optional).
  final String? website;

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

/// Request to save only the NIP-05-related profile identity fields.
///
/// The BLoC composes the final kind-0 payload from the current profile plus its
/// own NIP-05 editor state so settings screens do not need to mirror
/// unrelated profile fields.
final class ProfileNip05Saved extends ProfileEditorEvent {
  const ProfileNip05Saved({required this.currentProfile});

  final UserProfile currentProfile;
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

/// Re-check a previously reserved username to see if support has released it.
final class UsernameRechecked extends ProfileEditorEvent {
  const UsernameRechecked();
}

/// Sets the user's existing persisted profile picture URL after profile load.
///
/// Mirrors what the user's kind 0 currently advertises. The avatar widget
/// renders this when no staged change is present for the session.
final class InitialPersistedPictureSet extends ProfileEditorEvent {
  const InitialPersistedPictureSet(this.pictureUrl);

  /// The picture URL from the user's currently persisted kind 0, or `null`
  /// if the user has no profile yet or no picture set.
  final String? pictureUrl;
}

/// Request to upload a new profile picture for the current edit session.
///
/// Exactly one of [file] or [bytes] must be supplied. The bloc handles the
/// upload via the injected `BlossomUploadService` and stages the resulting
/// CDN URL on success. Save remains the only path that publishes a kind 0
/// — this event does **not** trigger publish.
final class ProfilePictureUploadRequested extends ProfileEditorEvent {
  const ProfilePictureUploadRequested({
    required this.pubkey,
    this.file,
    this.bytes,
    this.filename,
    this.mimeType = 'image/jpeg',
  }) : assert(
         (file == null) != (bytes == null),
         'Exactly one of file or bytes must be supplied',
       );

  /// User's public key in hex format. Required by the upload service for
  /// the BUD-01 auth event.
  final String pubkey;

  /// Native file payload (iOS / Android / desktop).
  final File? file;

  /// In-memory bytes payload (web).
  final Uint8List? bytes;

  /// Filename for the bytes payload (web only). Used by the metadata
  /// stripper to preserve / normalize the extension.
  final String? filename;

  /// MIME type. Defaults to `image/jpeg`.
  final String mimeType;
}

/// Clears any staged profile picture for the current edit session.
///
/// Used when the user explicitly removes their pick before saving. After
/// this fires, the avatar reverts to the persisted picture (or
/// placeholder) and a subsequent Save publishes whatever the persisted
/// value already was.
final class ProfilePictureUploadCleared extends ProfileEditorEvent {
  const ProfilePictureUploadCleared();
}

/// Stages a profile picture URL the user pasted manually.
///
/// Used by the manual-URL entry sheet. Bypasses the upload step because
/// the bytes are already hosted somewhere; we just need to stage the URL
/// for the Save step to write into kind 0.
final class ProfilePictureUrlSet extends ProfileEditorEvent {
  const ProfilePictureUrlSet(this.url);

  /// The picture URL the user entered. Empty string clears the staged
  /// picture (effectively the same as [ProfilePictureUploadCleared]).
  final String url;
}

/// User tapped the "Get verified" CTA. The UI listens for this and opens the
/// verifier. The bloc only flips a status; no navigation here.
final class VerifierLaunchRequested extends ProfileEditorEvent {
  const VerifierLaunchRequested();
}

/// UI handled the one-shot verifier launch request.
///
/// The UI owns navigation/browser launch and any follow-up profile refresh.
/// The bloc only resets the launch signal so future taps can emit again.
final class VerifierLaunchHandled extends ProfileEditorEvent {
  const VerifierLaunchHandled();
}

/// Sets the user's existing persisted banner value after profile load.
///
/// Mirrors what the user's kind 0 currently advertises. The banner string
/// can be either a CDN URL or a hex color (e.g. `0x33ccbf`); the bloc
/// classifies it and seeds [ProfileEditorState.pendingBannerColor] when it
/// looks like a color so the color picker pre-selects.
final class InitialPersistedBannerSet extends ProfileEditorEvent {
  const InitialPersistedBannerSet(this.banner);

  /// The banner value from the user's currently persisted kind 0, or
  /// `null` if the user has no profile yet or no banner set.
  final String? banner;
}

/// Request to upload a new banner image for the current edit session.
///
/// Exactly one of [file] or [bytes] must be supplied. The bloc handles the
/// upload via the injected `BlossomUploadService` and stages the resulting
/// CDN URL on success. Save remains the only path that publishes a kind 0
/// — this event does **not** trigger publish.
final class ProfileBannerUploadRequested extends ProfileEditorEvent {
  const ProfileBannerUploadRequested({
    required this.pubkey,
    this.file,
    this.bytes,
    this.filename,
    this.mimeType = 'image/jpeg',
  }) : assert(
         (file == null) != (bytes == null),
         'Exactly one of file or bytes must be supplied',
       );

  /// User's public key in hex format.
  final String pubkey;

  /// Native file payload (iOS / Android / desktop).
  final File? file;

  /// In-memory bytes payload (web).
  final Uint8List? bytes;

  /// Filename for the bytes payload (web only).
  final String? filename;

  /// MIME type. Defaults to `image/jpeg`.
  final String mimeType;
}

/// User picked a banner color. Mutually exclusive with an uploaded image —
/// selecting a color clears any staged banner image URL.
final class ProfileBannerColorSelected extends ProfileEditorEvent {
  const ProfileBannerColorSelected(this.color);

  /// The selected color. The bloc serializes this into a hex string when
  /// publishing kind 0 via [ProfileEditorState.effectiveBanner].
  final Color color;
}

/// User explicitly cleared the banner. Drops both the staged image URL and
/// the staged color; Save will publish `null` for the banner field.
final class ProfileBannerCleared extends ProfileEditorEvent {
  const ProfileBannerCleared();
}
