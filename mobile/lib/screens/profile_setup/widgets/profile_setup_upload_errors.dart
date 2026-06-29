import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/l10n/l10n.dart';

/// Maps an [AvatarUploadError] case to its localized snackbar string.
///
/// The bloc classifies upload failures; the UI just picks the right l10n key.
/// Keeping this here colocates UI copy with the screen that shows it.
String profileSetupUploadErrorMessage(
  AppLocalizations l10n,
  AvatarUploadError error,
) {
  return switch (error) {
    AvatarUploadError.network => l10n.profileSetupUploadNetworkError,
    AvatarUploadError.auth => l10n.profileSetupUploadAuthError,
    AvatarUploadError.fileTooLarge => l10n.profileSetupUploadFileTooLarge,
    AvatarUploadError.server => l10n.profileSetupUploadServerError,
    AvatarUploadError.generic => l10n.profileSetupUploadFailedGeneric,
  };
}

/// Maps a [BannerUploadError] case to its localized snackbar string.
///
/// Reuses the same upload-error copy as the avatar — the failure modes
/// are identical from the user's point of view.
String profileSetupBannerUploadErrorMessage(
  AppLocalizations l10n,
  BannerUploadError error,
) {
  return switch (error) {
    BannerUploadError.network => l10n.profileSetupUploadNetworkError,
    BannerUploadError.auth => l10n.profileSetupUploadAuthError,
    BannerUploadError.fileTooLarge => l10n.profileSetupUploadFileTooLarge,
    BannerUploadError.server => l10n.profileSetupUploadServerError,
    BannerUploadError.generic => l10n.profileSetupUploadFailedGeneric,
  };
}
