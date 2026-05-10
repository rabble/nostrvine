// ABOUTME: State class for the ProfileEditorBloc
// ABOUTME: Represents status and errors for profile save operations

part of 'profile_editor_bloc.dart';

/// Sentinel for [ProfileEditorState.copyWith] to distinguish "field not
/// supplied" from "field explicitly set to null". Picture URLs default to
/// null but need an explicit way to be cleared back to null without
/// resorting to magic-string conventions.
const Object _kUnset = Object();

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
  /// Failed to publish profile to Nostr relays (relay rejected or send error).
  publishFailed,

  /// Failed to publish profile because no relays are currently connected.
  ///
  /// This is distinct from [publishFailed]: the device has no active relay
  /// connections at all, rather than a relay actively rejecting the event.
  /// The UI should show a connectivity-specific message and offer a retry.
  noRelaysConnected,

  /// Failed to claim username (network error or other issue).
  claimFailed,

  /// Username was already taken by another user.
  usernameTaken,

  /// Username is reserved - user should contact support.
  usernameReserved,
}

/// Categorization of avatar upload failures for l10n-friendly UI messaging.
///
/// The bloc maps the upload-service failure reason to one of these cases, and
/// the UI layer maps each case to a localized snackbar string. Enum cases
/// rather than error strings keep state l10n-clean (per `error_handling.md`)
/// while preserving the granular failure messaging the existing UI shows.
enum AvatarUploadError {
  /// Network or connection error (timeout, connection refused, DNS, etc).
  network,

  /// Authentication error (401/403, signer rejection).
  auth,

  /// File too large (413, size limit exceeded).
  fileTooLarge,

  /// Server error (500/502/503/504, upstream unavailable).
  server,

  /// Generic / uncategorized failure.
  generic,
}

/// Categorization of banner upload failures for l10n-friendly UI messaging.
///
/// Mirrors [AvatarUploadError] so the UI can map both upload paths to the
/// same localized snackbar strings via the existing
/// `profileSetupUploadErrorMessage` helper.
enum BannerUploadError {
  /// Network or connection error.
  network,

  /// Authentication error (401/403).
  auth,

  /// File too large (413).
  fileTooLarge,

  /// Server error (500/502/503/504).
  server,

  /// Generic / uncategorized failure.
  generic,
}

/// Status of the staged banner upload for the current edit session.
///
/// Parallels [PendingAvatarStatus]. The banner shown on the edit screen
/// resolves to `pendingBannerUrl ?? pendingBannerColor ?? persistedBanner`.
enum PendingBannerStatus {
  /// No upload in flight and no staged change for this session.
  idle,

  /// An upload is in flight.
  uploading,

  /// An upload finished and produced a new banner URL.
  staged,

  /// An upload failed. `pendingBannerUrl` is preserved so a retry doesn't
  /// blank a previously-staged banner.
  failed,
}

/// Status of the staged avatar upload for the current edit session.
///
/// The avatar shown on the edit screen resolves to
/// `pendingPictureUrl ?? persistedPictureUrl`. The status enum lets the UI
/// drive a spinner (uploading), a success snackbar (transition to staged),
/// or the existing error snackbar (transition to failed) without inferring
/// behavior from nullable URL values.
enum PendingAvatarStatus {
  /// No upload in flight and no staged picture for this session. The avatar
  /// renders the persisted picture (or placeholder).
  idle,

  /// An upload is in flight. The widget should show a spinner overlay; the
  /// avatar continues to render whatever was visible before (the local
  /// pick preview, the previously staged URL, or the persisted picture).
  uploading,

  /// An upload finished and produced a new picture URL. The avatar renders
  /// the staged URL until the user taps Save (which persists it) or
  /// discards the edit.
  staged,

  /// An upload failed. `pendingPictureUrl` is preserved (so a retry path
  /// doesn't blank a previously-staged picture). The bloc's error stream
  /// fires alongside this transition; the UI surfaces the localized
  /// message via the existing error snackbar.
  failed,
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

  /// Username has been permanently burned and is no longer available.
  burned,

  /// Username has invalid format for divine.video (e.g. dots, underscores).
  invalidFormat,

  /// Validation error (network or other error).
  error,
}

/// Validation errors for username input.
///
/// The UI layer should map these to localized strings.
enum UsernameValidationError {
  /// Username contains invalid characters or hyphen placement.
  ///
  /// Valid characters for a divine.video username are lowercase letters,
  /// digits, and non-edge hyphens (single DNS label under *.divine.video).
  invalidFormat,

  /// Username length is outside allowed range (3–63 characters).
  invalidLength,

  /// Failed to check username availability due to network error.
  networkError,
}

/// Status of the in-app verifier WebView launch flow.
///
/// Used as a one-shot signal — the UI listens for [launchRequested], pushes
/// the WebView, and dispatches [VerifierWebViewDismissed] on return so the
/// status flips to [dismissed]. The bloc never navigates itself.
enum VerifierStatus {
  /// No launch pending.
  idle,

  /// User tapped "Get verified" — UI should push the WebView.
  launchRequested,

  /// WebView was popped — UI should refresh kind 0 to pick up new claims.
  dismissed,
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
///
/// The avatar shown on the edit screen resolves to
/// `pendingPictureUrl ?? persistedPictureUrl`. `pendingPictureUrl` is set
/// when the user has uploaded or pasted a new picture in the current edit
/// session but has not yet tapped Save. `persistedPictureUrl` mirrors the
/// kind 0 currently on the relays. Save publishes the effective value of
/// the two; Save remains the only publish point.
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
    this.pendingAvatarStatus = PendingAvatarStatus.idle,
    this.pendingPictureUrl,
    this.persistedPictureUrl,
    this.avatarUploadError,
    this.pendingBannerStatus = PendingBannerStatus.idle,
    this.pendingBannerUrl,
    this.pendingBannerColor,
    this.persistedBanner,
    this.bannerUploadError,
    this.verifierStatus = VerifierStatus.idle,
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

  /// Status of the staged avatar upload for this edit session.
  final PendingAvatarStatus pendingAvatarStatus;

  /// URL of the staged picture (uploaded or pasted) that has not yet been
  /// persisted via Save. `null` means no staged change for this session.
  final String? pendingPictureUrl;

  /// URL of the picture currently persisted on the user's kind 0. `null`
  /// when the user has no profile yet (new user) or no picture set.
  final String? persistedPictureUrl;

  /// Categorization of the most recent avatar upload failure, set on the
  /// transition to [PendingAvatarStatus.failed]. Cleared on every other
  /// state emit (matches the existing transient `error` field pattern).
  final AvatarUploadError? avatarUploadError;

  /// The picture URL that should be written when Save is tapped: prefer
  /// the staged value over the persisted one. Returns `null` when neither
  /// is set, signalling "no picture".
  String? get effectivePictureUrl => pendingPictureUrl ?? persistedPictureUrl;

  /// Status of the staged banner upload for this edit session.
  final PendingBannerStatus pendingBannerStatus;

  /// URL of the staged banner image (uploaded) that has not yet been
  /// persisted via Save. Mutually exclusive with [pendingBannerColor].
  final String? pendingBannerUrl;

  /// Staged banner color (user picked a swatch) that has not yet been
  /// persisted via Save. Mutually exclusive with [pendingBannerUrl].
  final Color? pendingBannerColor;

  /// Banner value currently persisted on the user's kind 0. Can be either
  /// a URL or a hex color string (e.g. `0x33ccbf`); see
  /// `UserProfileUtils.profileBackgroundColor` for the parse contract.
  final String? persistedBanner;

  /// Categorization of the most recent banner upload failure.
  final BannerUploadError? bannerUploadError;

  /// The banner value that should be written when Save is tapped:
  /// staged image URL > staged color (encoded as `0xRRGGBB`) > persisted
  /// banner. Returns `null` when none are set.
  String? get effectiveBanner {
    final url = pendingBannerUrl;
    if (url != null && url.isNotEmpty) return url;
    final color = pendingBannerColor;
    if (color != null) {
      return '0x${color.toARGB32().toRadixString(16).substring(2)}';
    }
    return persistedBanner;
  }

  /// One-shot signal driving the in-app verifier WebView launch + dismiss.
  final VerifierStatus verifierStatus;

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
  ///
  /// Returns false while an avatar upload is in flight: saving in that
  /// window would publish kind 0 with `persistedPictureUrl` (the old
  /// picture) and force the user to Save a second time once the staged
  /// URL lands. The [_SaveButton] reads this via `canSave`, and the bloc
  /// enforces the same invariant defensively in `_onProfileSaved`.
  bool get isSaveReady {
    if (pendingAvatarStatus == PendingAvatarStatus.uploading) return false;
    if (pendingBannerStatus == PendingBannerStatus.uploading) return false;
    return switch (nip05Mode) {
      Nip05Mode.divine => isUsernameSaveReady,
      Nip05Mode.external_ => isExternalNip05SaveReady,
    };
  }

  /// Creates a copy with updated values.
  ///
  /// `pendingPictureUrl` and `persistedPictureUrl` use a sentinel default so
  /// callers can explicitly pass `null` to clear them. Omitting the argument
  /// preserves the existing value.
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
    PendingAvatarStatus? pendingAvatarStatus,
    Object? pendingPictureUrl = _kUnset,
    Object? persistedPictureUrl = _kUnset,
    AvatarUploadError? avatarUploadError,
    PendingBannerStatus? pendingBannerStatus,
    Object? pendingBannerUrl = _kUnset,
    Object? pendingBannerColor = _kUnset,
    Object? persistedBanner = _kUnset,
    BannerUploadError? bannerUploadError,
    VerifierStatus? verifierStatus,
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
      pendingAvatarStatus: pendingAvatarStatus ?? this.pendingAvatarStatus,
      pendingPictureUrl: identical(pendingPictureUrl, _kUnset)
          ? this.pendingPictureUrl
          : pendingPictureUrl as String?,
      persistedPictureUrl: identical(persistedPictureUrl, _kUnset)
          ? this.persistedPictureUrl
          : persistedPictureUrl as String?,
      avatarUploadError: avatarUploadError,
      pendingBannerStatus: pendingBannerStatus ?? this.pendingBannerStatus,
      pendingBannerUrl: identical(pendingBannerUrl, _kUnset)
          ? this.pendingBannerUrl
          : pendingBannerUrl as String?,
      pendingBannerColor: identical(pendingBannerColor, _kUnset)
          ? this.pendingBannerColor
          : pendingBannerColor as Color?,
      persistedBanner: identical(persistedBanner, _kUnset)
          ? this.persistedBanner
          : persistedBanner as String?,
      bannerUploadError: bannerUploadError,
      verifierStatus: verifierStatus ?? this.verifierStatus,
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
    reservedUsernames,
    nip05Mode,
    externalNip05,
    initialExternalNip05,
    externalNip05Error,
    pendingAvatarStatus,
    pendingPictureUrl,
    persistedPictureUrl,
    avatarUploadError,
    pendingBannerStatus,
    pendingBannerUrl,
    pendingBannerColor,
    persistedBanner,
    bannerUploadError,
    verifierStatus,
  ];
}
