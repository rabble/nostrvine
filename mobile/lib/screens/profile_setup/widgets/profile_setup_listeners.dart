import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/my_profile/my_profile_bloc.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/profile_setup/widgets/profile_setup_upload_errors.dart';
import 'package:openvine/screens/profile_setup/widgets/verifier_flow.dart';
import 'package:openvine/widgets/profile_editor/username_status_indicator.dart';

/// Wraps the profile-setup form with all of its [BlocListener] side effects
/// (profile load -> controllers, save status snackbars/dialogs/navigation,
/// avatar/banner upload status, and the verifier launch). Kept separate from
/// the view so the view body stays a thin composition.
class ProfileSetupListeners extends ConsumerWidget {
  const ProfileSetupListeners({
    required this.isNewUser,
    required this.nameController,
    required this.bioController,
    required this.websiteController,
    required this.nip05Controller,
    required this.onNativeVerifierLaunched,
    required this.child,
    super.key,
  });

  final bool isNewUser;
  final TextEditingController nameController;
  final TextEditingController bioController;
  final TextEditingController websiteController;
  final TextEditingController nip05Controller;

  /// Called after a native (non-web) verifier launch so the view can refresh
  /// the profile when the app resumes.
  final VoidCallback onNativeVerifierLaunched;

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pubkey = ref.watch(authServiceProvider).currentPublicKeyHex;
    return MultiBlocListener(
      listeners: [
        BlocListener<MyProfileBloc, MyProfileState>(
          listenWhen: (prev, curr) => curr is MyProfileLoaded,
          listener: (context, myProfileState) {
            if (myProfileState is! MyProfileLoaded) return;

            final profile = myProfileState.profile;
            final extractedUsername = myProfileState.extractedUsername;
            final externalNip05 = myProfileState.externalNip05;

            nameController.text = profile.displayName ?? profile.name ?? '';
            bioController.text = profile.about ?? '';
            websiteController.text = profile.website ?? '';

            if (extractedUsername != null) {
              nip05Controller.text = extractedUsername;
            }

            final editorBloc = context.read<ProfileEditorBloc>();
            // Seed bloc with the persisted picture so the avatar widget can
            // render `pendingPictureUrl ?? persistedPictureUrl` purely from
            // state, no widget-local fallback for the existing avatar.
            editorBloc
              ..add(InitialPersistedPictureSet(profile.picture))
              ..add(InitialPersistedBannerSet(profile.banner));
            if (extractedUsername != null) {
              editorBloc.add(InitialUsernameSet(extractedUsername));
            }
            if (externalNip05 != null) {
              // External NIP-05 now lives on Settings -> Nostr -> NIP-05.
              // Seed editor state here so Save from Edit Profile preserves it.
              editorBloc
                ..add(InitialExternalNip05Set(externalNip05))
                ..add(const Nip05ModeChanged(Nip05Mode.external_))
                ..add(ExternalNip05Changed(externalNip05));
            }
          },
        ),
        BlocListener<ProfileEditorBloc, ProfileEditorState>(
          listenWhen: (prev, curr) => prev.status != curr.status,
          listener: (context, state) {
            if (state.status == ProfileEditorStatus.success) {
              // Invalidate profile providers so profile screen refetches
              final currentPubkey = ref
                  .read(authServiceProvider)
                  .currentPublicKeyHex;
              if (currentPubkey != null) {
                ref.invalidate(fetchUserProfileProvider(currentPubkey));
                ref.invalidate(userProfileReactiveProvider(currentPubkey));
              }

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: VineTheme.vineGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const DivineIcon(
                          icon: DivineIconName.check,
                          color: VineTheme.whiteText,
                          size: 17,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        context.l10n.profileSetupProfilePublished,
                        style: const TextStyle(color: VineTheme.vineGreen),
                      ),
                    ],
                  ),
                  backgroundColor: VineTheme.whiteText,
                ),
              );
              if (isNewUser) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              } else {
                if (context.canPop()) {
                  context.pop(true);
                } else {
                  context.go('/');
                }
              }
            } else if (state.status ==
                ProfileEditorStatus.confirmationRequired) {
              // Show confirmation dialog for blank profile overwrite
              showDialog<void>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  backgroundColor: VineTheme.cardBackground,
                  title: Text(
                    context.l10n.profileSetupCreateNewProfile,
                    style: const TextStyle(color: VineTheme.whiteText),
                  ),
                  content: Text(
                    context.l10n.profileSetupNoExistingProfile,
                    style: const TextStyle(color: VineTheme.secondaryText),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(
                        context.l10n.profileCancelButton,
                        style: const TextStyle(color: VineTheme.lightText),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        context.read<ProfileEditorBloc>().add(
                          const ProfileSaveConfirmed(),
                        );
                      },
                      child: Text(
                        context.l10n.profileSetupPublishButton,
                        style: const TextStyle(color: VineTheme.vineGreen),
                      ),
                    ),
                  ],
                ),
              );
            } else if (state.status == ProfileEditorStatus.failure) {
              // Invalidate profile providers after rollback
              final currentPubkey = ref
                  .read(authServiceProvider)
                  .currentPublicKeyHex;
              if (currentPubkey != null) {
                ref.invalidate(fetchUserProfileProvider(currentPubkey));
                ref.invalidate(userProfileReactiveProvider(currentPubkey));
              }
              switch (state.error) {
                case ProfileEditorError.usernameTaken:
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.l10n.profileSetupUsernameTaken),
                      backgroundColor: VineTheme.error,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                case ProfileEditorError.usernameReserved:
                  final username = state.username;
                  showDialog<void>(
                    context: context,
                    builder: (context) => UsernameReservedDialog(username),
                  );
                case ProfileEditorError.claimFailed:
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.l10n.profileSetupClaimFailed),
                      backgroundColor: VineTheme.error,
                    ),
                  );
                case ProfileEditorError.publishFailed:
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.l10n.profileSetupPublishFailed),
                      backgroundColor: VineTheme.error,
                    ),
                  );
                case ProfileEditorError.noRelaysConnected:
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.l10n.profileSetupNoRelaysConnected),
                      backgroundColor: VineTheme.error,
                      duration: const Duration(seconds: 6),
                      action: pubkey == null
                          ? null
                          : SnackBarAction(
                              label: context.l10n.profileSetupRetryLabel,
                              textColor: VineTheme.whiteText,
                              onPressed: () => _retryAfterRelayReconnect(
                                context,
                                ref,
                                pubkey,
                              ),
                            ),
                    ),
                  );
                case null:
                  break;
              }
            }
          },
        ),
        BlocListener<ProfileEditorBloc, ProfileEditorState>(
          listenWhen: (prev, curr) =>
              prev.pendingAvatarStatus != curr.pendingAvatarStatus,
          listener: (context, state) {
            switch (state.pendingAvatarStatus) {
              case PendingAvatarStatus.staged:
                // Avatar preview has already swapped (BlocBuilder is rebuilding
                // from `effectivePictureUrl`). The snackbar makes the staged
                // contract explicit: bytes uploaded, not yet published.
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.l10n.profileSetupUploadStaged),
                    backgroundColor: VineTheme.vineGreen,
                  ),
                );
              case PendingAvatarStatus.failed:
                final classified =
                    state.avatarUploadError ?? AvatarUploadError.generic;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      profileSetupUploadErrorMessage(context.l10n, classified),
                    ),
                    backgroundColor: VineTheme.error,
                  ),
                );
              case PendingAvatarStatus.idle:
              case PendingAvatarStatus.uploading:
                break;
            }
          },
        ),
        BlocListener<ProfileEditorBloc, ProfileEditorState>(
          listenWhen: (prev, curr) =>
              prev.pendingBannerStatus != curr.pendingBannerStatus,
          listener: (context, state) {
            switch (state.pendingBannerStatus) {
              case PendingBannerStatus.staged:
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context.l10n.profileSetupBannerUploadSuccess,
                    ),
                    backgroundColor: VineTheme.vineGreen,
                  ),
                );
              case PendingBannerStatus.failed:
                final classified =
                    state.bannerUploadError ?? BannerUploadError.generic;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      profileSetupBannerUploadErrorMessage(
                        context.l10n,
                        classified,
                      ),
                    ),
                    backgroundColor: VineTheme.error,
                  ),
                );
              case PendingBannerStatus.idle:
              case PendingBannerStatus.uploading:
                break;
            }
          },
        ),
        BlocListener<ProfileEditorBloc, ProfileEditorState>(
          listenWhen: (prev, curr) =>
              prev.verifierStatus != curr.verifierStatus &&
              curr.verifierStatus == VerifierStatus.launchRequested,
          listener: (context, state) async {
            final launched = await launchVerifierFlow(
              editorBloc: context.read<ProfileEditorBloc>(),
              myProfileBloc: context.read<MyProfileBloc>(),
              pushVerifierRoute: (location, {extra}) async {
                await context.push(location, extra: extra);
              },
            );
            if (launched && !kIsWeb && context.mounted) {
              onNativeVerifierLaunched();
            }
            if (!launched && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.l10n.relaySettingsCouldNotOpenBrowser),
                  backgroundColor: VineTheme.error,
                ),
              );
            }
          },
        ),
      ],
      child: child,
    );
  }

  Future<void> _retryAfterRelayReconnect(
    BuildContext context,
    WidgetRef ref,
    String pubkey,
  ) async {
    await ref.read(nostrServiceProvider).retryDisconnectedRelays();
    if (!context.mounted) return;
    context.read<ProfileEditorBloc>().add(
      ProfileSaved(
        pubkey: pubkey,
        displayName: nameController.text,
        about: bioController.text,
        website: websiteController.text,
        username: nip05Controller.text,
        // Picture and banner sourced from bloc state (see ProfileSaved
        // dispatch above) via `effectiveBanner` / `effectivePictureUrl`.
      ),
    );
  }
}
