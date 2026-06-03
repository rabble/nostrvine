// ABOUTME: Profile setup screen for new users to configure their display name, bio, and avatar
// ABOUTME: Publishes initial profile metadata to Nostr after setup is complete

import 'dart:async';
import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:openvine/blocs/my_profile/my_profile_bloc.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/apps/nostr_app_sandbox_screen.dart';
import 'package:openvine/screens/apps/web_iframe_sandbox_screen.dart';
import 'package:openvine/screens/key_management_screen.dart';
import 'package:openvine/utils/nostr_apps_platform_support.dart';
import 'package:openvine/widgets/branded_loading_scaffold.dart';
import 'package:openvine/widgets/profile/nostr_info_sheet_content.dart';
import 'package:openvine/widgets/profile/verified_accounts_row.dart';
import 'package:openvine/widgets/profile_editor/username_status_indicator.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:url_launcher/url_launcher.dart';

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

class ProfileSetupScreen extends ConsumerWidget {
  /// Route name for editing existing profile.
  static const editRouteName = 'edit-profile';

  /// Path for editing existing profile.
  static const editPath = '/edit-profile';

  /// Route name for setting up new profile.
  static const setupRouteName = 'setup-profile';

  /// Path for setting up new profile.
  static const setupPath = '/setup-profile';

  const ProfileSetupScreen({required this.isNewUser, super.key});

  final bool isNewUser;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileRepository = ref.watch(profileRepositoryProvider);
    final blossomUploadService = ref.watch(blossomUploadServiceProvider);
    final authService = ref.watch(authServiceProvider);
    final identityClaimsRepository = ref.watch(
      identityClaimsRepositoryProvider,
    );

    final pubkey = authService.currentPublicKeyHex;

    // Show loading until NostrClient has keys
    if (profileRepository == null || pubkey == null) {
      return const BrandedLoadingScaffold();
    }

    return MultiBlocProvider(
      providers: [
        BlocProvider<ProfileEditorBloc>(
          // Riverpod-into-BlocProvider bridge: rebuild the bloc when any
          // captured dependency's identity changes (auth flip, account
          // switch). Record-typed key compares per-field with `==`; the
          // captured classes do not override `==`, so equality falls
          // through to identity — exactly the semantics this needs.
          // See `state_management.md`.
          key: ValueKey((profileRepository, blossomUploadService, pubkey)),
          create: (context) => ProfileEditorBloc(
            profileRepository: profileRepository,
            blossomUploadService: blossomUploadService,
            hasExistingProfile: authService.hasExistingProfile,
            currentUserPubkey: pubkey,
          ),
        ),
        BlocProvider<MyProfileBloc>(
          create: (context) {
            final bloc = MyProfileBloc(
              profileRepository: profileRepository,
              pubkey: pubkey,
              identityClaimsRepository: identityClaimsRepository,
            );
            if (!isNewUser) bloc.add(const MyProfileLoadRequested());
            return bloc;
          },
        ),
      ],
      child: ProfileSetupScreenView(isNewUser: isNewUser),
    );
  }
}

class ProfileSetupScreenView extends ConsumerStatefulWidget {
  const ProfileSetupScreenView({required this.isNewUser, super.key});
  final bool isNewUser;

  @override
  ConsumerState<ProfileSetupScreenView> createState() =>
      _ProfileSetupScreenViewState();
}

class _ProfileSetupScreenViewState
    extends ConsumerState<ProfileSetupScreenView> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _pictureController = TextEditingController();
  final _nip05Controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  // Focus nodes for tracking field focus state
  final _nameFocusNode = FocusNode();
  final _bioFocusNode = FocusNode();
  final _usernameFocusNode = FocusNode();

  // Local-preview state for the brief window between picking and the
  // bloc receiving the staged URL. The bloc's `pendingPictureUrl` takes
  // over once `pendingAvatarStatus == staged`. Cleared on the next pick
  // or on `ProfilePictureUploadCleared`.
  //
  // Native picks: file path flows through the platform-channel EXIF
  // stripper inside the upload service. Web picks: `image_picker` returns
  // a blob URL `dart:io File` cannot open, so the bytes drive both the
  // preview and the bytes-based upload path.
  File? _selectedImage;
  Uint8List? _selectedImageBytes;

  @override
  void initState() {
    super.initState();
    // Rebuild when display name changes so save button updates.
    _nameController.addListener(_onFocusChange);
    // Add focus listeners to update label colors
    _nameFocusNode.addListener(_onFocusChange);
    _bioFocusNode.addListener(_onFocusChange);
    _usernameFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFocusChange);
    _nameController.dispose();
    _bioController.dispose();
    _pictureController.dispose();
    _nip05Controller.dispose();
    _nameFocusNode.removeListener(_onFocusChange);
    _bioFocusNode.removeListener(_onFocusChange);
    _usernameFocusNode.removeListener(_onFocusChange);
    _nameFocusNode.dispose();
    _bioFocusNode.dispose();
    _usernameFocusNode.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

            setState(() {
              _nameController.text = profile.displayName ?? profile.name ?? '';
              _bioController.text = profile.about ?? '';
              _pictureController.text = profile.picture ?? '';

              if (extractedUsername != null) {
                _nip05Controller.text = extractedUsername;
              }
            });

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
              if (widget.isNewUser) {
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
                              onPressed: () =>
                                  _retryAfterRelayReconnect(context, pubkey),
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
            final editorBloc = context.read<ProfileEditorBloc>();
            final myProfileBloc = context.read<MyProfileBloc>();
            final verifyer = preloadedNostrApps.firstWhere(
              (app) => app.slug == 'verifyer',
            );
            if (nostrAppsSandboxSupported) {
              // Native (iOS / Android / macOS): full webview_flutter
              // sandbox with NIP-07 bridge injection.
              await context.push(
                NostrAppSandboxScreen.pathForAppId(verifyer.id),
                extra: verifyer,
              );
            } else if (kIsWeb) {
              // Flutter web: webview_flutter is unavailable, but we can
              // host the verifyer in an <iframe> with a postMessage
              // NIP-07 bridge to Divine's web signer.
              await context.push(
                WebIframeSandboxScreen.pathForAppId(verifyer.id),
                extra: verifyer,
              );
            } else {
              // Last-resort fallback for any future platform without
              // either capability — open in the system browser.
              await launchUrl(
                Uri.parse(verifyer.launchUrl),
                mode: LaunchMode.externalApplication,
              );
            }
            editorBloc.add(const VerifierWebViewDismissed());
            myProfileBloc.add(const MyProfileFetchRequested());
          },
        ),
      ],
      child: BlocBuilder<ProfileEditorBloc, ProfileEditorState>(
        builder: (context, profileEditorState) {
          return Scaffold(
            backgroundColor: VineTheme.surfaceContainerHigh,
            appBar: DiVineAppBar(
              title: context.l10n.profileSetupEditProfileTitle,
              backgroundMode: DiVineAppBarBackgroundMode.transparent,
              showBackButton: true,
              backButtonSemanticLabel: context.l10n.profileSetupBackLabel,
              onBackPressed: () {
                if (context.canPop()) {
                  context.pop();
                  return;
                }
                final authService = ref.read(authServiceProvider);
                final currentPubkey = authService.currentPublicKeyHex;
                if (currentPubkey != null) {
                  final npub = authService.currentNpub;
                  context.go('/profile/$npub');
                } else {
                  context.go('/home/0');
                }
              },
              style: const DiVineAppBarStyle(
                iconButtonBackgroundColor: VineTheme.scrim15,
              ),
              actions: [
                DiVineAppBarAction(
                  icon: SvgIconSource(DivineIconName.info.assetPath),
                  onPressed: () => _showNostrInfoSheet(context),
                  tooltip: context.l10n.profileSetupAboutNostr,
                  semanticLabel: context.l10n.profileSetupAboutNostr,
                ),
              ],
            ),
            body: GestureDetector(
              onTap: () {
                // Dismiss keyboard when tapping outside text fields
                FocusScope.of(context).unfocus();
              },
              child: SafeArea(
                bottom:
                    false, // Don't add bottom padding - let content extend to bottom
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            textSelectionTheme: const TextSelectionThemeData(
                              cursorColor: VineTheme.primary,
                              selectionColor: Color(0xFF1C4430),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Profile Picture Section with overlapping buttons
                              Center(
                                child: SizedBox(
                                  // 144 avatar + 20 (half of 40px buttons extending below)
                                  height: 164,
                                  width: 144,
                                  child: BlocBuilder<ProfileEditorBloc, ProfileEditorState>(
                                    buildWhen: (prev, curr) =>
                                        prev.pendingAvatarStatus !=
                                            curr.pendingAvatarStatus ||
                                        prev.pendingPictureUrl !=
                                            curr.pendingPictureUrl ||
                                        prev.persistedPictureUrl !=
                                            curr.persistedPictureUrl,
                                    builder: (context, editorState) {
                                      final isUploadingImage =
                                          editorState.pendingAvatarStatus ==
                                          PendingAvatarStatus.uploading;
                                      return Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          // Profile picture preview
                                          UserAvatar(
                                            imageProvider:
                                                _buildProfilePictureProvider(
                                                  editorState,
                                                ),
                                            name: _nameController.text.trim(),
                                            placeholderSeed: pubkey,
                                            size: 144,
                                            semanticLabel: context
                                                .l10n
                                                .profileSetupProfilePicturePreview,
                                          ),
                                          // Upload progress indicator
                                          if (isUploadingImage)
                                            Positioned(
                                              top: 0,
                                              left: 0,
                                              width: 144,
                                              height: 144,
                                              child: DecoratedBox(
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(56),
                                                  color: VineTheme
                                                      .backgroundColor
                                                      .withValues(alpha: 0.7),
                                                ),
                                                child: const Center(
                                                  child:
                                                      CircularProgressIndicator(
                                                        color:
                                                            VineTheme.vineGreen,
                                                        strokeWidth: 3,
                                                      ),
                                                ),
                                              ),
                                            ),
                                          // Image source buttons - overlapping bottom of avatar
                                          Positioned(
                                            bottom: 0,
                                            left: 0,
                                            right: 0,
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                // Show camera button on mobile only
                                                if (!_isDesktopPlatform()) ...[
                                                  GestureDetector(
                                                    onTap: isUploadingImage
                                                        ? null
                                                        : () => _pickImage(
                                                            ImageSource.camera,
                                                          ),
                                                    child: Container(
                                                      width: 40,
                                                      height: 40,
                                                      decoration: BoxDecoration(
                                                        color: VineTheme
                                                            .surfaceContainer,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              16,
                                                            ),
                                                        border: Border.all(
                                                          color: VineTheme
                                                              .outlineMuted,
                                                          width: 2,
                                                        ),
                                                      ),
                                                      child: Center(
                                                        child: SvgPicture.asset(
                                                          DivineIconName
                                                              .cameraPlus
                                                              .assetPath,
                                                          width: 24,
                                                          height: 24,
                                                          colorFilter:
                                                              const ColorFilter.mode(
                                                                VineTheme
                                                                    .primary,
                                                                BlendMode.srcIn,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                ],
                                                GestureDetector(
                                                  onTap: isUploadingImage
                                                      ? null
                                                      : () => _pickImage(
                                                          ImageSource.gallery,
                                                        ),
                                                  child: Container(
                                                    width: 40,
                                                    height: 40,
                                                    decoration: BoxDecoration(
                                                      color: VineTheme
                                                          .surfaceContainer,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            16,
                                                          ),
                                                      border: Border.all(
                                                        color: VineTheme
                                                            .outlineMuted,
                                                        width: 2,
                                                      ),
                                                    ),
                                                    child: Center(
                                                      child: SvgPicture.asset(
                                                        DivineIconName
                                                            .imagesSquare
                                                            .assetPath,
                                                        width: 24,
                                                        height: 24,
                                                        colorFilter:
                                                            const ColorFilter.mode(
                                                              VineTheme.primary,
                                                              BlendMode.srcIn,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                // URL input button
                                                GestureDetector(
                                                  onTap: isUploadingImage
                                                      ? null
                                                      : () =>
                                                            _showImageUrlSheet(
                                                              context,
                                                            ),
                                                  child: Container(
                                                    width: 40,
                                                    height: 40,
                                                    decoration: BoxDecoration(
                                                      color: VineTheme
                                                          .surfaceContainer,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            16,
                                                          ),
                                                      border: Border.all(
                                                        color: VineTheme
                                                            .outlineMuted,
                                                        width: 2,
                                                      ),
                                                    ),
                                                    child: Center(
                                                      child: SvgPicture.asset(
                                                        DivineIconName
                                                            .linkSimple
                                                            .assetPath,
                                                        width: 24,
                                                        height: 24,
                                                        colorFilter:
                                                            const ColorFilter.mode(
                                                              VineTheme.primary,
                                                              BlendMode.srcIn,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Display Name
                              Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  start: 16,
                                ),
                                child: Text(
                                  context.l10n.profileSetupDisplayNameLabel,
                                  style: VineTheme.labelMediumFont(
                                    color: _nameFocusNode.hasFocus
                                        ? VineTheme.primary
                                        : VineTheme.onSurfaceMuted,
                                  ),
                                ),
                              ),
                              TextFormField(
                                controller: _nameController,
                                focusNode: _nameFocusNode,
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                style: VineTheme.bodyLargeFont(
                                  color: VineTheme.onSurface,
                                ),
                                decoration: InputDecoration(
                                  isCollapsed: true,
                                  hintText:
                                      context.l10n.profileSetupDisplayNameHint,
                                  helperText: context
                                      .l10n
                                      .profileSetupDisplayNameHelper,
                                  helperStyle: const TextStyle(
                                    color: VineTheme.onSurfaceMuted,
                                    fontSize: 12,
                                  ),
                                  hintStyle: const TextStyle(
                                    color: VineTheme.lightText,
                                  ),
                                  border: const UnderlineInputBorder(
                                    borderRadius: BorderRadius.zero,
                                    borderSide: BorderSide(
                                      color: VineTheme.neutral10,
                                    ),
                                  ),
                                  enabledBorder: const UnderlineInputBorder(
                                    borderRadius: BorderRadius.zero,
                                    borderSide: BorderSide(
                                      color: VineTheme.neutral10,
                                    ),
                                  ),
                                  focusedBorder: const UnderlineInputBorder(
                                    borderRadius: BorderRadius.zero,
                                    borderSide: BorderSide(
                                      color: VineTheme.neutral10,
                                    ),
                                  ),
                                  errorBorder: const UnderlineInputBorder(
                                    borderRadius: BorderRadius.zero,
                                    borderSide: BorderSide(
                                      color: VineTheme.neutral10,
                                    ),
                                  ),
                                  focusedErrorBorder:
                                      const UnderlineInputBorder(
                                        borderRadius: BorderRadius.zero,
                                        borderSide: BorderSide(
                                          color: VineTheme.neutral10,
                                        ),
                                      ),
                                  contentPadding: const EdgeInsets.all(16),
                                ),
                                textInputAction: TextInputAction.next,
                                onFieldSubmitted: (_) =>
                                    FocusScope.of(context).nextFocus(),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return context
                                        .l10n
                                        .profileSetupDisplayNameRequired;
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Bio
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      context.l10n.profileSetupBioLabel,
                                      style: VineTheme.labelMediumFont(
                                        color: _bioFocusNode.hasFocus
                                            ? VineTheme.primary
                                            : VineTheme.onSurfaceMuted,
                                      ),
                                    ),
                                    Text(
                                      '${_bioController.text.length}/360',
                                      style: VineTheme.labelMediumFont(
                                        color: VineTheme.onSurfaceMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextFormField(
                                controller: _bioController,
                                focusNode: _bioFocusNode,
                                style: VineTheme.bodyLargeFont(
                                  color: VineTheme.onSurface,
                                ),
                                decoration: InputDecoration(
                                  isCollapsed: true,
                                  hintText: context.l10n.profileSetupBioHint,
                                  hintStyle: const TextStyle(
                                    color: VineTheme.lightText,
                                  ),
                                  border: const UnderlineInputBorder(
                                    borderRadius: BorderRadius.zero,
                                    borderSide: BorderSide(
                                      color: VineTheme.neutral10,
                                    ),
                                  ),
                                  enabledBorder: const UnderlineInputBorder(
                                    borderRadius: BorderRadius.zero,
                                    borderSide: BorderSide(
                                      color: VineTheme.neutral10,
                                    ),
                                  ),
                                  focusedBorder: const UnderlineInputBorder(
                                    borderRadius: BorderRadius.zero,
                                    borderSide: BorderSide(
                                      color: VineTheme.neutral10,
                                    ),
                                  ),
                                  errorBorder: const UnderlineInputBorder(
                                    borderRadius: BorderRadius.zero,
                                    borderSide: BorderSide(
                                      color: VineTheme.neutral10,
                                    ),
                                  ),
                                  focusedErrorBorder:
                                      const UnderlineInputBorder(
                                        borderRadius: BorderRadius.zero,
                                        borderSide: BorderSide(
                                          color: VineTheme.neutral10,
                                        ),
                                      ),
                                  contentPadding: const EdgeInsets.all(16),
                                  counterText: '',
                                ),
                                maxLines: null,
                                minLines: 1,
                                maxLength: 360,
                                textInputAction: TextInputAction.next,
                                onFieldSubmitted: (_) =>
                                    FocusScope.of(context).nextFocus(),
                                onChanged: (_) => setState(() {}),
                              ),
                              const SizedBox(height: 16),

                              const _VerifiedAccountsSection(),

                              const _PublicKeyLink(),
                              const SizedBox(height: 16),

                              // NIP-05 Username (optional)
                              BlocBuilder<
                                ProfileEditorBloc,
                                ProfileEditorState
                              >(
                                buildWhen: (prev, curr) =>
                                    prev.nip05Mode != curr.nip05Mode,
                                builder: (context, editorState) {
                                  final isExternal =
                                      editorState.nip05Mode ==
                                      Nip05Mode.external_;
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 16,
                                        ),
                                        child: Text(
                                          context
                                              .l10n
                                              .profileSetupUsernameLabel,
                                          style: VineTheme.labelMediumFont(
                                            color:
                                                _usernameFocusNode.hasFocus &&
                                                    !isExternal
                                                ? VineTheme.primary
                                                : VineTheme.onSurfaceMuted,
                                          ),
                                        ),
                                      ),
                                      TextFormField(
                                        controller: _nip05Controller,
                                        focusNode: _usernameFocusNode,
                                        enabled: !isExternal,
                                        style: VineTheme.bodyLargeFont(
                                          color: isExternal
                                              ? VineTheme.onSurfaceMuted
                                              : VineTheme.onSurface,
                                        ),
                                        autovalidateMode:
                                            AutovalidateMode.onUserInteraction,
                                        decoration: InputDecoration(
                                          isCollapsed: true,
                                          hintText: context
                                              .l10n
                                              .profileSetupUsernameHint,
                                          helperText: context
                                              .l10n
                                              .profileSetupUsernameHelper,
                                          helperStyle: const TextStyle(
                                            color: VineTheme.onSurfaceMuted,
                                            fontSize: 12,
                                          ),
                                          hintStyle: const TextStyle(
                                            color: VineTheme.onSurfaceMuted,
                                          ),
                                          border: const UnderlineInputBorder(
                                            borderRadius: BorderRadius.zero,
                                            borderSide: BorderSide(
                                              color: VineTheme.neutral10,
                                            ),
                                          ),
                                          enabledBorder:
                                              const UnderlineInputBorder(
                                                borderRadius: BorderRadius.zero,
                                                borderSide: BorderSide(
                                                  color: VineTheme.neutral10,
                                                ),
                                              ),
                                          disabledBorder:
                                              const UnderlineInputBorder(
                                                borderRadius: BorderRadius.zero,
                                                borderSide: BorderSide(
                                                  color: VineTheme.neutral10,
                                                ),
                                              ),
                                          focusedBorder:
                                              const UnderlineInputBorder(
                                                borderRadius: BorderRadius.zero,
                                                borderSide: BorderSide(
                                                  color: VineTheme.neutral10,
                                                ),
                                              ),
                                          errorBorder:
                                              const UnderlineInputBorder(
                                                borderRadius: BorderRadius.zero,
                                                borderSide: BorderSide(
                                                  color: VineTheme.neutral10,
                                                ),
                                              ),
                                          focusedErrorBorder:
                                              const UnderlineInputBorder(
                                                borderRadius: BorderRadius.zero,
                                                borderSide: BorderSide(
                                                  color: VineTheme.neutral10,
                                                ),
                                              ),
                                          contentPadding: const EdgeInsets.all(
                                            16,
                                          ),
                                          prefixText: '@',
                                          prefixStyle: VineTheme.bodyLargeFont(
                                            color: VineTheme.onSurfaceMuted,
                                          ),
                                          suffixText: '.divine.video',
                                          suffixStyle: VineTheme.bodyLargeFont(
                                            color: VineTheme.onSurfaceMuted,
                                          ),
                                          errorMaxLines: 2,
                                        ),
                                        // Lowercase as the user types and
                                        // restrict to canonical subdomain
                                        // characters. The name server stores
                                        // and resolves usernames as lowercase,
                                        // so normalizing here avoids a
                                        // confusing "invalid format" error
                                        // for a typed capital letter.
                                        inputFormatters: [
                                          const LowercaseTextInputFormatter(),
                                          FilteringTextInputFormatter.allow(
                                            RegExp('[a-z0-9-]'),
                                          ),
                                        ],
                                        textInputAction: TextInputAction.next,
                                        onFieldSubmitted: (_) =>
                                            FocusScope.of(context).nextFocus(),
                                        onChanged: (value) => context
                                            .read<ProfileEditorBloc>()
                                            .add(UsernameChanged(value)),
                                      ),
                                      // Username status indicators
                                      if (!isExternal)
                                        BlocBuilder<
                                          ProfileEditorBloc,
                                          ProfileEditorState
                                        >(
                                          builder: (context, state) =>
                                              UsernameStatusIndicator(
                                                status: state.usernameStatus,
                                                error: state.usernameError,
                                                formatMessage:
                                                    state.usernameFormatMessage,
                                              ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 24),

                              // Banner section: image upload + color swatches.
                              // Replaces the old standalone profile-color
                              // picker; the bloc serializes the chosen color
                              // into the same kind-0 `banner` field.
                              const _BannerEditingBlock(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            bottomNavigationBar: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            profileEditorState.status ==
                                ProfileEditorStatus.loading
                            ? null
                            : () {
                                // Wait for any ongoing transitions before popping
                                // This prevents navigation timing race condition
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (mounted) {
                                    Navigator.of(context).pop();
                                  }
                                });
                              },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: VineTheme.surfaceContainer,
                          foregroundColor: VineTheme.vineGreen,
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          side: const BorderSide(
                            color: VineTheme.outlineMuted,
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(
                          context.l10n.commonCancel,
                          style: VineTheme.titleMediumFont(
                            color: VineTheme.vineGreen,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    if (pubkey != null)
                      Expanded(
                        child: _SaveButton(
                          canSave: profileEditorState.isSaveReady,
                          onSave: () {
                            if (_nameController.text.trim().isEmpty) {
                              _nameFocusNode.requestFocus();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    context
                                        .l10n
                                        .profileSetupDisplayNameRequired,
                                  ),
                                  backgroundColor: VineTheme.error,
                                ),
                              );
                              return;
                            }
                            context.read<ProfileEditorBloc>().add(
                              ProfileSaved(
                                pubkey: pubkey,
                                displayName: _nameController.text,
                                about: _bioController.text,
                                username: _nip05Controller.text,
                                // Picture and banner are owned by bloc state.
                                // The bloc reads pendingPictureUrl /
                                // pendingBannerUrl / pendingBannerColor /
                                // persistedBanner directly via
                                // `effectiveBanner`, so we don't pass them
                                // through the event.
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Attempts to reconnect relays and re-dispatches [ProfileSaved].
  ///
  /// Called from the retry CTA on the no-relays-connected SnackBar. Triggers
  /// [NostrClient.retryDisconnectedRelays] before re-submitting so the relay
  /// pool has a chance to reconnect before the publish is attempted again.
  Future<void> _retryAfterRelayReconnect(
    BuildContext context,
    String pubkey,
  ) async {
    await ref.read(nostrServiceProvider).retryDisconnectedRelays();
    if (!context.mounted) return;
    context.read<ProfileEditorBloc>().add(
      ProfileSaved(
        pubkey: pubkey,
        displayName: _nameController.text,
        about: _bioController.text,
        username: _nip05Controller.text,
        // Picture and banner sourced from bloc state (see ProfileSaved
        // dispatch above) via `effectiveBanner` / `effectivePictureUrl`.
      ),
    );
  }

  ImageProvider<Object>? _buildProfilePictureProvider(
    ProfileEditorState editorState,
  ) {
    // Priority:
    //   1. Local pick preview (only relevant during upload — the bloc has
    //      no URL yet).
    //   2. Staged picture from bloc state (post-upload or manual URL).
    //   3. Persisted picture from bloc state (current kind 0 value).
    //   4. Placeholder.
    if (editorState.pendingAvatarStatus == PendingAvatarStatus.uploading) {
      if (_selectedImageBytes != null) return MemoryImage(_selectedImageBytes!);
      if (_selectedImage != null) return FileImage(_selectedImage!);
    }

    final pending = editorState.pendingPictureUrl;
    if (pending != null && pending.isNotEmpty) {
      return NetworkImage(pending);
    }

    final persisted = editorState.persistedPictureUrl;
    if (persisted != null && persisted.isNotEmpty) {
      return NetworkImage(persisted);
    }

    return null;
  }

  /// Platform-aware image selection.
  ///
  /// Native (mobile + desktop): selects an [XFile] with a real filesystem
  /// path, wraps it in `dart:io File`, and routes through
  /// `BlossomUploadService.uploadImage` so the platform-channel EXIF
  /// stripper runs.
  ///
  /// Web: `image_picker` returns an [XFile] whose `.path` is a blob URL
  /// that `dart:io` cannot resolve, so we read the bytes directly and
  /// route through `BlossomUploadService.uploadImageBytes`, which strips
  /// EXIF in pure Dart and uploads from memory.
  Future<void> _pickImage(ImageSource source) async {
    try {
      Log.info(
        '🖼️ Attempting to pick image from ${source.name} on '
        '${kIsWeb ? "web" : defaultTargetPlatform.name}',
        name: 'ProfileSetupScreen',
        category: LogCategory.ui,
      );

      final picked = await _pickXFile(source);
      if (picked == null) {
        Log.info(
          '❌ No image selected',
          name: 'ProfileSetupScreen',
          category: LogCategory.ui,
        );
        return;
      }
      Log.info(
        '✅ Image picked: ${picked.name}',
        name: 'ProfileSetupScreen',
        category: LogCategory.ui,
      );

      final pubkey = ref.read(authServiceProvider).currentPublicKeyHex;
      if (pubkey == null) {
        Log.error(
          'Cannot upload avatar: no public key available',
          name: 'ProfileSetupScreen',
          category: LogCategory.ui,
        );
        return;
      }

      if (kIsWeb) {
        // Resolve the blob synchronously here — once we navigate away from
        // the picker the URL can be revoked.
        final bytes = await picked.readAsBytes();
        if (!mounted) return;
        setState(() {
          _selectedImage = null;
          _selectedImageBytes = bytes;
          _pictureController.clear();
        });
        context.read<ProfileEditorBloc>().add(
          ProfilePictureUploadRequested(
            pubkey: pubkey,
            bytes: bytes,
            filename: picked.name,
          ),
        );
      } else {
        if (!mounted) return;
        final file = File(picked.path);
        setState(() {
          _selectedImage = file;
          _selectedImageBytes = null;
          _pictureController.clear();
        });
        context.read<ProfileEditorBloc>().add(
          ProfilePictureUploadRequested(pubkey: pubkey, file: file),
        );
      }
    } catch (e) {
      Log.error(
        'Error picking image: $e',
        name: 'ProfileSetupScreen',
        category: LogCategory.ui,
      );

      // Show user-friendly error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              source == ImageSource.gallery
                  ? context.l10n.profileSetupImageSelectionFailed
                  : context.l10n.profileSetupCameraAccessFailed('$e'),
            ),
            backgroundColor: VineTheme.error,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: context.l10n.profileSetupGotItButton,
              textColor: VineTheme.whiteText,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  /// Picks a single image, returning the picker's [XFile] without resolving
  /// it to a `dart:io File`. The returned XFile may have a blob-URL `path`
  /// on web; callers must use [XFile.readAsBytes] there rather than
  /// constructing a `File`.
  Future<XFile?> _pickXFile(ImageSource source) async {
    // image_picker handles both gallery and camera on web, mobile, and
    // (since plugin updates) desktop camera. file_selector is only
    // preferred for native desktop gallery, where it provides a richer
    // file-type filter UX.
    if (!kIsWeb && source == ImageSource.gallery && _isDesktopPlatform()) {
      return _pickXFileFromDesktop();
    }

    try {
      return await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
        requestFullMetadata: false,
      );
    } catch (e) {
      Log.error(
        'image_picker error: $e',
        name: 'ProfileSetupScreen',
        category: LogCategory.ui,
      );
      rethrow;
    }
  }

  /// Check if running on desktop platform.
  ///
  /// Always returns false on web — `defaultTargetPlatform` reports the
  /// host OS in a desktop browser, but a browser is not desktop for
  /// picker-routing purposes (no real filesystem access).
  bool _isDesktopPlatform() {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  /// Use file_selector for native desktop platforms.
  Future<XFile?> _pickXFileFromDesktop() async {
    try {
      Log.info(
        '🖥️ Starting desktop file picker...',
        name: 'ProfileSetupScreen',
        category: LogCategory.ui,
      );

      final typeGroup = XTypeGroup(
        label: context.l10n.profileSetupImagesTypeGroup,
        extensions: const <String>['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'],
      );

      final file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);

      if (file == null) {
        Log.info(
          '❌ Desktop file picker: User cancelled or no file selected',
          name: 'ProfileSetupScreen',
          category: LogCategory.ui,
        );
        return null;
      }

      Log.info(
        '✅ Desktop file selected: ${file.name}',
        name: 'ProfileSetupScreen',
        category: LogCategory.ui,
      );
      return file;
    } catch (e) {
      Log.error(
        'Desktop file picker error: $e',
        name: 'ProfileSetupScreen',
        category: LogCategory.ui,
      );
      rethrow;
    }
  }

  void _showNostrInfoSheet(BuildContext context) {
    // Unfocus any field before opening sheet
    FocusScope.of(context).unfocus();
    VineBottomSheet.show<void>(
      context: context,
      children: const [NostrInfoSheetContent()],
    ).then((_) {
      // Unfocus after sheet is dismissed to prevent auto-focus on form fields
      if (context.mounted) {
        FocusScope.of(context).unfocus();
      }
    });
  }

  void _showImageUrlSheet(BuildContext context) {
    // Unfocus any field before opening sheet
    FocusScope.of(context).unfocus();
    VineBottomSheet.show<void>(
      context: context,
      scrollable: false,
      expanded: false,
      isScrollControlled: true,
      title: Text(
        context.l10n.profileSetupImageUrlTitle,
        style: VineTheme.titleMediumFont(color: VineTheme.onSurface),
      ),
      children: [
        Builder(
          builder: (sheetContext) => Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
            ),
            child: TextFormField(
              controller: _pictureController,
              style: const TextStyle(color: VineTheme.whiteText),
              cursorColor: VineTheme.primary,
              decoration: InputDecoration(
                hintText: 'https://example.com/image.jpg',
                hintStyle: const TextStyle(color: VineTheme.lightText),
                filled: true,
                fillColor: VineTheme.surfaceContainer,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
              ),
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onFieldSubmitted: (_) => Navigator.of(sheetContext).pop(),
              keyboardType: TextInputType.url,
              autofocus: true,
            ),
          ),
        ),
      ],
    ).then((_) {
      // Stage the URL the user typed so the avatar widget previews it and
      // Save can publish it. Empty string clears any prior staged change.
      if (context.mounted) {
        context.read<ProfileEditorBloc>().add(
          ProfilePictureUrlSet(_pictureController.text),
        );
        FocusScope.of(context).unfocus();
      }
    });
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.canSave, required this.onSave});

  final bool canSave;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select<ProfileEditorBloc, bool>(
      (bloc) => bloc.state.status == ProfileEditorStatus.loading,
    );

    return ElevatedButton(
      onPressed: (isLoading || !canSave) ? null : onSave,
      style: ElevatedButton.styleFrom(
        backgroundColor: VineTheme.vineGreen,
        foregroundColor: VineTheme.onPrimary,
        disabledBackgroundColor: VineTheme.vineGreen.withValues(alpha: 0.4),
        disabledForegroundColor: VineTheme.onPrimary.withValues(alpha: 0.6),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: isLoading
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: VineTheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  context.l10n.profileSetupSavingButton,
                  style: VineTheme.titleMediumFont(color: VineTheme.onPrimary),
                ),
              ],
            )
          : Text(
              context.l10n.profileSetupSaveButton,
              style: VineTheme.titleMediumFont(color: VineTheme.onPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
    );
  }
}

/// Banner editing block: 3:1 preview, gallery upload, and color swatches.
///
/// Image and color are mutually exclusive — selecting one clears the other
/// at the bloc layer. The preview reads
/// `pendingBannerUrl ?? pendingBannerColor ?? persistedBanner` via
/// granular `context.select`s so unrelated state changes don't rebuild it.
class _BannerEditingBlock extends StatelessWidget {
  const _BannerEditingBlock();

  // Brand-accent palette parallel to the avatar's profile-color picker.
  // Order is load-bearing for the
  // `profile_banner_color_swatch_preset_<index>` keys used in tests.
  static const List<Color> _bannerSwatchPalette = [
    VineTheme.vineGreen,
    VineTheme.accentBlue,
    VineTheme.accentPurple,
    VineTheme.likeRed,
    VineTheme.accentOrange,
    VineTheme.accentLime,
    VineTheme.accentPink,
    VineTheme.accentViolet,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.profileSetupBannerSectionTitle,
              style: VineTheme.labelMediumFont(
                color: VineTheme.onSurfaceMuted,
              ),
            ),
          ),
          const _BannerPreview(),
          const SizedBox(height: 12),
          const _BannerActionRow(),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (var i = 0; i < _bannerSwatchPalette.length; i++)
                _BannerColorSwatch(
                  index: i,
                  color: _bannerSwatchPalette[i],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BannerPreview extends StatelessWidget {
  const _BannerPreview();

  @override
  Widget build(BuildContext context) {
    final pendingUrl = context.select(
      (ProfileEditorBloc b) => b.state.pendingBannerUrl,
    );
    final pendingColor = context.select(
      (ProfileEditorBloc b) => b.state.pendingBannerColor,
    );
    final persistedBanner = context.select(
      (ProfileEditorBloc b) => b.state.persistedBanner,
    );
    final isUploading = context.select(
      (ProfileEditorBloc b) =>
          b.state.pendingBannerStatus == PendingBannerStatus.uploading,
    );

    final radius = BorderRadius.circular(16);
    final imageUrl = (pendingUrl != null && pendingUrl.isNotEmpty)
        ? pendingUrl
        : (pendingColor == null &&
              persistedBanner != null &&
              persistedBanner.startsWith('http'))
        ? persistedBanner
        : null;

    Widget child;
    Key previewKey;
    if (imageUrl != null) {
      previewKey = const ValueKey('profile_banner_image_preview');
      child = Semantics(
        label: context.l10n.profileSetupBannerSectionTitle,
        image: true,
        child: ClipRRect(
          borderRadius: radius,
          child: VineCachedImage(imageUrl: imageUrl),
        ),
      );
    } else if (pendingColor != null) {
      previewKey = const ValueKey('profile_banner_color_preview');
      child = DecoratedBox(
        decoration: BoxDecoration(
          color: pendingColor,
          borderRadius: radius,
        ),
      );
    } else {
      previewKey = const ValueKey('profile_banner_empty_preview');
      child = DecoratedBox(
        decoration: BoxDecoration(
          color: VineTheme.surfaceContainer,
          borderRadius: radius,
          border: Border.all(color: VineTheme.outlineMuted, width: 2),
        ),
      );
    }

    return Stack(
      children: [
        AspectRatio(
          key: previewKey,
          aspectRatio: 3,
          child: child,
        ),
        if (isUploading)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: VineTheme.backgroundColor.withValues(alpha: 0.6),
                borderRadius: radius,
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  color: VineTheme.vineGreen,
                  strokeWidth: 3,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _BannerActionRow extends StatelessWidget {
  const _BannerActionRow();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasSelection = context.select(
      (ProfileEditorBloc b) =>
          (b.state.pendingBannerUrl?.isNotEmpty ?? false) ||
          b.state.pendingBannerColor != null ||
          (b.state.persistedBanner?.isNotEmpty ?? false),
    );
    final isUploading = context.select(
      (ProfileEditorBloc b) =>
          b.state.pendingBannerStatus == PendingBannerStatus.uploading,
    );

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: isUploading ? null : () => _pickBannerImage(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: VineTheme.vineGreen,
              side: const BorderSide(
                color: VineTheme.outlineMuted,
                width: 2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Text(
              l10n.profileSetupBannerUploadButton,
              style: VineTheme.titleMediumFont(color: VineTheme.vineGreen),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: (isUploading || !hasSelection)
                ? null
                : () => context.read<ProfileEditorBloc>().add(
                    const ProfileBannerCleared(),
                  ),
            style: OutlinedButton.styleFrom(
              foregroundColor: VineTheme.lightText,
              side: const BorderSide(
                color: VineTheme.outlineMuted,
                width: 2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Text(
              l10n.profileSetupBannerClearButton,
              style: VineTheme.titleMediumFont(color: VineTheme.lightText),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickBannerImage(BuildContext context) async {
    final editorBloc = context.read<ProfileEditorBloc>();
    final container = ProviderScope.containerOf(context, listen: false);
    final pk = container.read(authServiceProvider).currentPublicKeyHex;
    if (pk == null) return;

    final picker = ImagePicker();
    XFile? picked;
    try {
      picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1500,
        imageQuality: 85,
        requestFullMetadata: false,
      );
    } catch (e) {
      Log.error(
        'Banner image_picker error: $e',
        name: 'ProfileSetupScreen',
        category: LogCategory.ui,
      );
      return;
    }
    if (picked == null) return;

    if (kIsWeb) {
      final bytes = await picked.readAsBytes();
      editorBloc.add(
        ProfileBannerUploadRequested(
          pubkey: pk,
          bytes: bytes,
          filename: picked.name,
        ),
      );
    } else {
      editorBloc.add(
        ProfileBannerUploadRequested(
          pubkey: pk,
          file: File(picked.path),
        ),
      );
    }
  }
}

class _BannerColorSwatch extends StatelessWidget {
  const _BannerColorSwatch({required this.index, required this.color});

  final int index;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isSelected = context.select(
      (ProfileEditorBloc b) => b.state.pendingBannerColor == color,
    );
    return Semantics(
      button: true,
      label: context.l10n.profileSetupBannerSectionTitle,
      child: GestureDetector(
        key: ValueKey('profile_banner_color_swatch_preset_$index'),
        onTap: () => context.read<ProfileEditorBloc>().add(
          ProfileBannerColorSelected(color),
        ),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? VineTheme.whiteText : VineTheme.transparent,
              width: 3,
            ),
          ),
          child: isSelected
              ? const DivineIcon(
                  icon: DivineIconName.check,
                  color: VineTheme.whiteText,
                  size: 20,
                )
              : null,
        ),
      ),
    );
  }
}

class _PublicKeyLink extends StatelessWidget {
  const _PublicKeyLink();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton(
        onPressed: () => context.pushNamed(KeyManagementScreen.routeName),
        child: Text(
          l10n.profileEditPublicKeyLink,
          style: VineTheme.labelMediumFont(color: VineTheme.primary),
        ),
      ),
    );
  }
}

class _VerifiedAccountsSection extends StatelessWidget {
  const _VerifiedAccountsSection();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final claims = context.select<MyProfileBloc, List<IdentityClaim>>((bloc) {
      final state = bloc.state;
      if (state is MyProfileLoaded) return state.verifiedClaims;
      if (state is MyProfileUpdated) return state.verifiedClaims;
      return const [];
    });
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Text(
              l10n.profileEditVerifiedAccountsTitle,
              style: VineTheme.labelMediumFont(color: VineTheme.lightText),
            ),
          ),
          if (claims.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: VerifiedAccountsRow(claims: claims),
            ),
            const SizedBox(height: 8),
          ],
          const _GetVerifiedTile(),
        ],
      ),
    );
  }
}

class _GetVerifiedTile extends StatelessWidget {
  const _GetVerifiedTile();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      title: Text(
        l10n.profileEditGetVerifiedCta,
        style: VineTheme.titleMediumFont(),
      ),
      subtitle: Text(
        l10n.profileEditGetVerifiedSubtitle,
        style: VineTheme.bodyMediumFont(color: VineTheme.lightText),
      ),
      trailing: const DivineIcon(
        icon: DivineIconName.caretRight,
        color: VineTheme.lightText,
      ),
      onTap: () => context.read<ProfileEditorBloc>().add(
        const VerifierLaunchRequested(),
      ),
    );
  }
}
