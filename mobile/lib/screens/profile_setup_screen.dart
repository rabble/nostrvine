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
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:openvine/blocs/my_profile/my_profile_bloc.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/services/zendesk_support_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/utils/user_profile_utils.dart';
import 'package:openvine/widgets/branded_loading_scaffold.dart';
import 'package:openvine/widgets/profile/nostr_info_sheet_content.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:url_launcher/url_launcher.dart';

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
    final userProfileService = ref.watch(userProfileServiceProvider);
    final authService = ref.watch(authServiceProvider);

    final pubkey = authService.currentPublicKeyHex;

    // Show loading until NostrClient has keys
    if (profileRepository == null || pubkey == null) {
      return const BrandedLoadingScaffold();
    }

    return MultiBlocProvider(
      providers: [
        BlocProvider<ProfileEditorBloc>(
          create: (context) => ProfileEditorBloc(
            profileRepository: profileRepository,
            userProfileService: userProfileService,
            hasExistingProfile: authService.hasExistingProfile,
            currentUserPubkey: pubkey,
          ),
        ),
        BlocProvider<MyProfileBloc>(
          create: (context) {
            final bloc = MyProfileBloc(
              profileRepository: profileRepository,
              pubkey: pubkey,
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
  final _externalNip05Controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  // Focus nodes for tracking field focus state
  final _nameFocusNode = FocusNode();
  final _bioFocusNode = FocusNode();
  final _usernameFocusNode = FocusNode();
  final _externalNip05FocusNode = FocusNode();

  bool _isUploadingImage = false;
  File? _selectedImage;
  String? _uploadedImageUrl;
  Color? _selectedProfileColor;

  @override
  void initState() {
    super.initState();
    // Rebuild when display name changes so save button updates.
    _nameController.addListener(_onFocusChange);
    // Add focus listeners to update label colors
    _nameFocusNode.addListener(_onFocusChange);
    _bioFocusNode.addListener(_onFocusChange);
    _usernameFocusNode.addListener(_onFocusChange);
    _externalNip05FocusNode.addListener(_onFocusChange);
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
    _externalNip05Controller.dispose();
    _nameFocusNode.removeListener(_onFocusChange);
    _bioFocusNode.removeListener(_onFocusChange);
    _usernameFocusNode.removeListener(_onFocusChange);
    _externalNip05FocusNode.removeListener(_onFocusChange);
    _nameFocusNode.dispose();
    _bioFocusNode.dispose();
    _usernameFocusNode.dispose();
    _externalNip05FocusNode.dispose();

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
              _selectedProfileColor = profile.profileBackgroundColor;

              if (extractedUsername != null) {
                _nip05Controller.text = extractedUsername;
              }
              if (externalNip05 != null) {
                _externalNip05Controller.text = externalNip05;
              }
            });

            final editorBloc = context.read<ProfileEditorBloc>();
            if (extractedUsername != null) {
              editorBloc.add(InitialUsernameSet(extractedUsername));
            }
            if (externalNip05 != null) {
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
                        child: const Icon(
                          Icons.check,
                          color: VineTheme.whiteText,
                          size: 17,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Profile published successfully!',
                        style: TextStyle(color: VineTheme.vineGreen),
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
                  title: const Text(
                    'Create new profile?',
                    style: TextStyle(color: VineTheme.whiteText),
                  ),
                  content: const Text(
                    "We didn't find an existing profile on your "
                    'relays. Publishing will create a new profile. '
                    'Continue?',
                    style: TextStyle(color: VineTheme.secondaryText),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: VineTheme.lightText),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        context.read<ProfileEditorBloc>().add(
                          const ProfileSaveConfirmed(),
                        );
                      },
                      child: const Text(
                        'Publish',
                        style: TextStyle(color: VineTheme.vineGreen),
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
                    const SnackBar(
                      content: Text(
                        'Username was just taken. '
                        'Please choose another.',
                      ),
                      backgroundColor: VineTheme.error,
                      duration: Duration(seconds: 3),
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
                    const SnackBar(
                      content: Text(
                        'Failed to claim username. Please try again.',
                      ),
                      backgroundColor: VineTheme.error,
                    ),
                  );
                case ProfileEditorError.publishFailed:
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Failed to publish profile. Please try again.',
                      ),
                      backgroundColor: VineTheme.error,
                    ),
                  );
                case null:
                  break;
              }
            }
          },
        ),
      ],
      child: BlocBuilder<ProfileEditorBloc, ProfileEditorState>(
        builder: (context, profileEditorState) {
          return Scaffold(
            backgroundColor: VineTheme.surfaceContainerHigh,
            appBar: DiVineAppBar(
              title: 'Edit Profile',
              backgroundMode: DiVineAppBarBackgroundMode.transparent,
              showBackButton: true,
              backButtonSemanticLabel: 'Back',
              onBackPressed: () {
                // Try to pop using context.pop() which GoRouter intercepts
                // This should work even if canPop() returns false
                try {
                  context.pop();
                } catch (e) {
                  // If pop fails, navigate to profile or home as fallback
                  final authService = ref.read(authServiceProvider);
                  final currentPubkey = authService.currentPublicKeyHex;
                  if (currentPubkey != null) {
                    final npub = authService.currentNpub;
                    context.go('/profile/$npub');
                  } else {
                    context.go('/home/0');
                  }
                }
              },
              style: const DiVineAppBarStyle(
                iconButtonBackgroundColor: VineTheme.scrim15,
              ),
              actions: [
                DiVineAppBarAction(
                  icon: const SvgIconSource('assets/icon/info.svg'),
                  onPressed: () => _showNostrInfoSheet(context),
                  tooltip: 'About Nostr',
                  semanticLabel: 'About Nostr',
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
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      // Profile picture preview
                                      UserAvatar(
                                        imageProvider:
                                            _buildProfilePictureProvider(),
                                        name: _nameController.text.trim(),
                                        size: 144,
                                        semanticLabel:
                                            'Profile picture preview',
                                      ),
                                      // Upload progress indicator
                                      if (_isUploadingImage)
                                        Positioned(
                                          top: 0,
                                          left: 0,
                                          width: 144,
                                          height: 144,
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(56),
                                              color: VineTheme.backgroundColor
                                                  .withValues(alpha: 0.7),
                                            ),
                                            child: const Center(
                                              child: CircularProgressIndicator(
                                                color: VineTheme.vineGreen,
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
                                                onTap: _isUploadingImage
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
                                                      'assets/icon/cameraPlus.svg',
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
                                            ],
                                            GestureDetector(
                                              onTap: _isUploadingImage
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
                                                      BorderRadius.circular(16),
                                                  border: Border.all(
                                                    color:
                                                        VineTheme.outlineMuted,
                                                    width: 2,
                                                  ),
                                                ),
                                                child: Center(
                                                  child: SvgPicture.asset(
                                                    'assets/icon/imagesSquare.svg',
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
                                              onTap: () =>
                                                  _showImageUrlSheet(context),
                                              child: Container(
                                                width: 40,
                                                height: 40,
                                                decoration: BoxDecoration(
                                                  color: VineTheme
                                                      .surfaceContainer,
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  border: Border.all(
                                                    color:
                                                        VineTheme.outlineMuted,
                                                    width: 2,
                                                  ),
                                                ),
                                                child: Center(
                                                  child: SvgPicture.asset(
                                                    'assets/icon/linkSimple.svg',
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
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Display Name
                              Padding(
                                padding: const EdgeInsets.only(left: 16),
                                child: Text(
                                  'Display Name',
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
                                decoration: const InputDecoration(
                                  isCollapsed: true,
                                  hintText: 'How should people know you?',
                                  hintStyle: TextStyle(
                                    color: VineTheme.lightText,
                                  ),
                                  border: UnderlineInputBorder(
                                    borderRadius: BorderRadius.zero,
                                    borderSide: BorderSide(
                                      color: VineTheme.neutral10,
                                    ),
                                  ),
                                  enabledBorder: UnderlineInputBorder(
                                    borderRadius: BorderRadius.zero,
                                    borderSide: BorderSide(
                                      color: VineTheme.neutral10,
                                    ),
                                  ),
                                  focusedBorder: UnderlineInputBorder(
                                    borderRadius: BorderRadius.zero,
                                    borderSide: BorderSide(
                                      color: VineTheme.neutral10,
                                    ),
                                  ),
                                  errorBorder: UnderlineInputBorder(
                                    borderRadius: BorderRadius.zero,
                                    borderSide: BorderSide(
                                      color: VineTheme.neutral10,
                                    ),
                                  ),
                                  focusedErrorBorder: UnderlineInputBorder(
                                    borderRadius: BorderRadius.zero,
                                    borderSide: BorderSide(
                                      color: VineTheme.neutral10,
                                    ),
                                  ),
                                  contentPadding: EdgeInsets.all(16),
                                ),
                                textInputAction: TextInputAction.next,
                                onFieldSubmitted: (_) =>
                                    FocusScope.of(context).nextFocus(),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter a display name';
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
                                      'Bio (Optional)',
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
                                decoration: const InputDecoration(
                                  isCollapsed: true,
                                  hintText: 'Tell people about yourself...',
                                  hintStyle: TextStyle(
                                    color: VineTheme.lightText,
                                  ),
                                  border: UnderlineInputBorder(
                                    borderRadius: BorderRadius.zero,
                                    borderSide: BorderSide(
                                      color: VineTheme.neutral10,
                                    ),
                                  ),
                                  enabledBorder: UnderlineInputBorder(
                                    borderRadius: BorderRadius.zero,
                                    borderSide: BorderSide(
                                      color: VineTheme.neutral10,
                                    ),
                                  ),
                                  focusedBorder: UnderlineInputBorder(
                                    borderRadius: BorderRadius.zero,
                                    borderSide: BorderSide(
                                      color: VineTheme.neutral10,
                                    ),
                                  ),
                                  errorBorder: UnderlineInputBorder(
                                    borderRadius: BorderRadius.zero,
                                    borderSide: BorderSide(
                                      color: VineTheme.neutral10,
                                    ),
                                  ),
                                  focusedErrorBorder: UnderlineInputBorder(
                                    borderRadius: BorderRadius.zero,
                                    borderSide: BorderSide(
                                      color: VineTheme.neutral10,
                                    ),
                                  ),
                                  contentPadding: EdgeInsets.all(16),
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

                              // Public key (npub) - read-only
                              Padding(
                                padding: const EdgeInsets.only(left: 16),
                                child: Text(
                                  'Public key (npub)',
                                  style: VineTheme.labelMediumFont(
                                    color: VineTheme.onSurfaceMuted,
                                  ),
                                ),
                              ),
                              TextFormField(
                                initialValue: ref
                                    .watch(authServiceProvider)
                                    .currentNpub,
                                readOnly: true,
                                maxLines: null,
                                style: VineTheme.bodyLargeFont(
                                  color: VineTheme.onSurfaceMuted,
                                ),
                                decoration: const InputDecoration(
                                  isCollapsed: true,
                                  border: UnderlineInputBorder(
                                    borderRadius: BorderRadius.zero,
                                    borderSide: BorderSide(
                                      color: VineTheme.neutral10,
                                    ),
                                  ),
                                  enabledBorder: UnderlineInputBorder(
                                    borderRadius: BorderRadius.zero,
                                    borderSide: BorderSide(
                                      color: VineTheme.neutral10,
                                    ),
                                  ),
                                  focusedBorder: UnderlineInputBorder(
                                    borderRadius: BorderRadius.zero,
                                    borderSide: BorderSide(
                                      color: VineTheme.neutral10,
                                    ),
                                  ),
                                  contentPadding: EdgeInsets.all(16),
                                ),
                              ),
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
                                          'Username (Optional)',
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
                                          hintText: 'username',
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
                                        // Only allow valid subdomain characters
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                            RegExp('[a-zA-Z0-9-]'),
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

                              // External NIP-05 section
                              _ExternalNip05Section(
                                controller: _externalNip05Controller,
                                focusNode: _externalNip05FocusNode,
                              ),

                              const SizedBox(height: 24),

                              // Profile Color (optional)
                              Padding(
                                padding: const EdgeInsets.only(left: 16),
                                child: Text(
                                  'Profile Color (Optional)',
                                  style: VineTheme.labelMediumFont(
                                    color: VineTheme.onSurfaceMuted,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const .symmetric(horizontal: 16),
                                child: _ProfileColorPicker(
                                  selectedColor: _selectedProfileColor,
                                  onColorChanged: (color) {
                                    setState(() {
                                      _selectedProfileColor = color;
                                    });
                                  },
                                ),
                              ),
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
                          'Cancel',
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
                          canSave:
                              _nameController.text.trim().isNotEmpty &&
                              profileEditorState.isSaveReady,
                          onSave: () {
                            context.read<ProfileEditorBloc>().add(
                              ProfileSaved(
                                pubkey: pubkey,
                                displayName: _nameController.text,
                                about: _bioController.text,
                                username: _nip05Controller.text,
                                externalNip05: _externalNip05Controller.text,
                                picture: _pictureController.text,
                                banner: _selectedProfileColor != null
                                    ? '0x${_selectedProfileColor!.toARGB32().toRadixString(16).substring(2)}'
                                    : null,
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

  ImageProvider<Object>? _buildProfilePictureProvider() {
    // Priority: selected image > uploaded URL > manual URL > placeholder
    if (_selectedImage != null) {
      return FileImage(_selectedImage!);
    }

    if (_uploadedImageUrl != null && _uploadedImageUrl!.isNotEmpty) {
      return NetworkImage(_uploadedImageUrl!);
    }

    if (_pictureController.text.isNotEmpty) {
      return NetworkImage(_pictureController.text);
    }

    return null;
  }

  /// Platform-aware image selection
  Future<void> _pickImage(ImageSource source) async {
    try {
      Log.info(
        '🖼️ Attempting to pick image from ${source.name} on ${defaultTargetPlatform.name}',
        name: 'ProfileSetupScreen',
        category: LogCategory.ui,
      );

      File? selectedFile;

      // Use different methods based on platform and source
      if (source == ImageSource.gallery && _isDesktopPlatform()) {
        // Use file_selector for desktop gallery/file browsing
        selectedFile = await _pickImageFromDesktop();
      } else {
        // Use image_picker for mobile or camera
        selectedFile = await _pickImageFromMobile(source);
      }

      if (selectedFile != null) {
        Log.info(
          '✅ Image picked successfully: ${selectedFile.path}',
          name: 'ProfileSetupScreen',
          category: LogCategory.ui,
        );
        setState(() {
          _selectedImage = selectedFile;
          _uploadedImageUrl = null; // Clear previous upload
          _pictureController.clear(); // Clear manual URL
        });

        // Upload the image
        await _uploadImage();
      } else {
        Log.info(
          '❌ No image selected',
          name: 'ProfileSetupScreen',
          category: LogCategory.ui,
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
                  ? 'Image selection failed. Please paste an image URL below instead.'
                  : 'Camera access failed: $e',
            ),
            backgroundColor: VineTheme.error,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Got it',
              textColor: VineTheme.whiteText,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  /// Check if running on desktop platform
  bool _isDesktopPlatform() =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;

  /// Use file_selector for desktop platforms
  Future<File?> _pickImageFromDesktop() async {
    try {
      Log.info(
        '🖥️ Starting desktop file picker...',
        name: 'ProfileSetupScreen',
        category: LogCategory.ui,
      );

      const typeGroup = XTypeGroup(
        label: 'images',
        extensions: <String>['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'],
      );

      Log.info(
        '🖥️ Opening file dialog with type group: ${typeGroup.label}',
        name: 'ProfileSetupScreen',
        category: LogCategory.ui,
      );

      final file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);

      if (file != null) {
        Log.info(
          '✅ Desktop file selected: ${file.path}',
          name: 'ProfileSetupScreen',
          category: LogCategory.ui,
        );
        Log.info(
          '📁 File name: ${file.name}',
          name: 'ProfileSetupScreen',
          category: LogCategory.ui,
        );
        Log.info(
          '📁 File size: ${await file.length()} bytes',
          name: 'ProfileSetupScreen',
          category: LogCategory.ui,
        );
        return File(file.path);
      } else {
        Log.info(
          '❌ Desktop file picker: User cancelled or no file selected',
          name: 'ProfileSetupScreen',
          category: LogCategory.ui,
        );
      }
      return null;
    } catch (e) {
      Log.error(
        'Desktop file picker error: $e',
        name: 'ProfileSetupScreen',
        category: LogCategory.ui,
      );
      Log.error(
        'Error type: ${e.runtimeType}',
        name: 'ProfileSetupScreen',
        category: LogCategory.ui,
      );
      Log.error(
        'Stack trace: ${StackTrace.current}',
        name: 'ProfileSetupScreen',
        category: LogCategory.ui,
      );
      rethrow;
    }
  }

  /// Use image_picker for mobile platforms and camera
  Future<File?> _pickImageFromMobile(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      Log.error(
        'Mobile image picker error: $e',
        name: 'ProfileSetupScreen',
        category: LogCategory.ui,
      );
      rethrow;
    }
  }

  Future<void> _uploadImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _isUploadingImage = true;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final uploadService = ref.read(blossomUploadServiceProvider);

      if (authService.currentPublicKeyHex == null) {
        throw Exception('No public key available');
      }

      final result = await uploadService.uploadImage(
        imageFile: _selectedImage!,
        nostrPubkey: authService.currentPublicKeyHex!,
        onProgress: (progress) {
          // Only log at major milestones to reduce noise
          if (progress == 1.0 || progress == 0.0) {
            Log.debug(
              'Upload ${progress == 1.0 ? "completed" : "started"}',
              name: 'ProfileSetupScreen',
              category: LogCategory.ui,
            );
          }
        },
      );

      if (result.success && result.cdnUrl != null) {
        setState(() {
          _uploadedImageUrl = result.cdnUrl;
          _pictureController.text = result.cdnUrl!;
        });

        // Dismiss keyboard after programmatically setting text field value
        if (mounted) {
          FocusScope.of(context).unfocus();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture uploaded successfully!'),
              backgroundColor: VineTheme.success,
            ),
          );
        }
      } else {
        throw Exception(result.errorMessage ?? 'Upload failed');
      }
    } catch (e) {
      Log.error(
        'Error uploading image: $e',
        name: 'ProfileSetupScreen',
        category: LogCategory.ui,
      );
      Log.error(
        'Upload error type: ${e.runtimeType}',
        name: 'ProfileSetupScreen',
        category: LogCategory.ui,
      );

      // Check if it's a network connectivity issue
      final errorMessage = e.toString().toLowerCase();
      String userMessage = 'Failed to upload image: $e';

      if (errorMessage.contains('network') ||
          errorMessage.contains('connection') ||
          errorMessage.contains('timeout')) {
        userMessage =
            'Network error: Please check your internet connection and try again.';
      } else if (errorMessage.contains('auth') ||
          errorMessage.contains('401') ||
          errorMessage.contains('403')) {
        userMessage =
            'Authentication error: Please try logging out and back in.';
      } else if (errorMessage.contains('file too large') ||
          errorMessage.contains('size')) {
        userMessage =
            'File too large: Please choose a smaller image (max 10MB).';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMessage),
            backgroundColor: VineTheme.error,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Got it',
              textColor: VineTheme.whiteText,
              onPressed: () {},
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  void _showNostrInfoSheet(BuildContext context) {
    // Unfocus any field before opening sheet
    FocusScope.of(context).unfocus();
    VineBottomSheet.show<void>(
      context: context,
      scrollable: false,
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
        'Add image URL',
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
      // Unfocus after sheet is dismissed to prevent auto-focus on form fields
      if (context.mounted) {
        FocusScope.of(context).unfocus();
      }
    });
  }
}

/// Displays username availability status (checking, available, taken, reserved, error)
class UsernameStatusIndicator extends StatelessWidget {
  const UsernameStatusIndicator({
    required this.status,
    this.error,
    this.formatMessage,
    super.key,
  });

  final UsernameStatus status;
  final UsernameValidationError? error;

  /// Custom message from the server for format validation errors.
  final String? formatMessage;

  @override
  Widget build(BuildContext context) {
    String? errorText;
    if (error != null) {
      errorText = switch (error) {
        UsernameValidationError.invalidFormat =>
          formatMessage ?? 'Only letters, numbers, and hyphens are allowed',
        UsernameValidationError.invalidLength =>
          'Username must be 3-20 characters',
        UsernameValidationError.networkError =>
          'Could not check availability. Please try again.',
        null => null,
      };
    }
    return switch (status) {
      UsernameStatus.idle => const SizedBox.shrink(),
      UsernameStatus.checking => const _UsernameCheckingIndicator(),
      UsernameStatus.available => const _UsernameAvailableIndicator(),
      UsernameStatus.taken => const _UsernameTakenIndicator(),
      UsernameStatus.reserved => const _UsernameReservedIndicator(),
      UsernameStatus.invalidFormat => _UsernameErrorIndicator(
        message: errorText ?? 'Invalid username format',
      ),
      UsernameStatus.error => _UsernameErrorIndicator(
        message: errorText ?? 'Failed to check availability',
      ),
    };
  }
}

class _UsernameCheckingIndicator extends StatelessWidget {
  const _UsernameCheckingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 8),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text(
            'Checking availability...',
            style: TextStyle(color: VineTheme.secondaryText, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _UsernameAvailableIndicator extends StatelessWidget {
  const _UsernameAvailableIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: VineTheme.vineGreen, size: 16),
          SizedBox(width: 8),
          Text(
            'Username available!',
            style: TextStyle(color: VineTheme.vineGreen, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _UsernameTakenIndicator extends StatelessWidget {
  const _UsernameTakenIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(Icons.cancel, color: VineTheme.error, size: 16),
          SizedBox(width: 8),
          Text(
            'Username already taken',
            style: TextStyle(color: VineTheme.error, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _UsernameReservedIndicator extends StatelessWidget {
  const _UsernameReservedIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lock, color: VineTheme.warning, size: 16),
              SizedBox(width: 8),
              Text(
                'Username is reserved',
                style: TextStyle(color: VineTheme.warning, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  final username = context
                      .read<ProfileEditorBloc>()
                      .state
                      .username;
                  showDialog<void>(
                    context: context,
                    builder: (dialogContext) => BlocProvider.value(
                      value: context.read<ProfileEditorBloc>(),
                      child: UsernameReservedDialog(username),
                    ),
                  );
                },
                child: const Text(
                  'Contact support',
                  style: TextStyle(
                    color: VineTheme.vineGreen,
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                    decorationColor: VineTheme.vineGreen,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => context.read<ProfileEditorBloc>().add(
                  const UsernameRechecked(),
                ),
                child: const Text(
                  'Check again',
                  style: TextStyle(
                    color: VineTheme.vineGreen,
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                    decorationColor: VineTheme.vineGreen,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UsernameErrorIndicator extends StatelessWidget {
  const _UsernameErrorIndicator({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: VineTheme.warning, size: 16),
          const SizedBox(width: 8),
          Text(
            message,
            style: const TextStyle(color: VineTheme.warning, fontSize: 12),
          ),
        ],
      ),
    );
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
                  'Saving...',
                  style: VineTheme.titleMediumFont(color: VineTheme.onPrimary),
                ),
              ],
            )
          : Text(
              'Save',
              style: VineTheme.titleMediumFont(color: VineTheme.onPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
    );
  }
}

@visibleForTesting
class UsernameReservedDialog extends StatefulWidget {
  const UsernameReservedDialog(this.username, {super.key});

  final String username;

  @override
  State<UsernameReservedDialog> createState() => _UsernameReservedDialogState();
}

class _UsernameReservedDialogState extends State<UsernameReservedDialog> {
  final _reasonController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _contactSupport() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) return;

    setState(() => _submitting = true);

    final npub = ZendeskSupportService.userNpub;
    final created = await ZendeskSupportService.createTicketViaApi(
      subject: 'Reserved username request: ${widget.username}',
      description:
          'Username requested: ${widget.username}\n'
          '${npub != null ? 'Nostr npub: $npub\n' : ''}\n'
          'Why this name should be mine:\n$reason',
      requesterName: ZendeskSupportService.userName,
      requesterEmail: ZendeskSupportService.userEmail,
      tags: ['reserved_username', 'name_request'],
    );

    if (!mounted) return;

    setState(() => _submitting = false);

    if (created) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Support request sent! We'll get back to you soon."),
          backgroundColor: VineTheme.vineGreen,
        ),
      );
    } else {
      // Fallback to email if Zendesk is unavailable
      final encodedReason = Uri.encodeComponent(reason);
      final launched = await launchUrl(
        Uri.parse(
          'mailto:names@divine.video?subject=Reserved username request: '
          '${widget.username}&body=Username requested: ${widget.username}'
          '%0A%0AWhy this name should be mine:%0A$encodedReason',
        ),
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Couldn't open email. Send to: names@divine.video",
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: VineTheme.cardBackground,
      title: const Text(
        'Username reserved',
        style: TextStyle(color: VineTheme.whiteText),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The name ${widget.username} is reserved. Tell us why it should '
            'be yours.',
            style: const TextStyle(color: VineTheme.secondaryText),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonController,
            maxLines: 3,
            style: const TextStyle(color: VineTheme.whiteText, fontSize: 14),
            decoration: const InputDecoration(
              hintText: "e.g. It's my brand name, stage name, etc.",
              hintStyle: TextStyle(color: VineTheme.onSurfaceMuted),
              border: OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: VineTheme.surfaceContainer),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: VineTheme.vineGreen),
              ),
              contentPadding: EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Already contacted support? Tap "Check again" to see if '
            "it's been released to you.",
            style: TextStyle(color: VineTheme.secondaryText, fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Close',
            style: TextStyle(color: VineTheme.lightText),
          ),
        ),
        TextButton(
          onPressed: () {
            context.read<ProfileEditorBloc>().add(const UsernameRechecked());
            Navigator.of(context).pop();
          },
          child: const Text(
            'Check again',
            style: TextStyle(color: VineTheme.vineGreen),
          ),
        ),
        FilledButton(
          onPressed: _submitting ? null : _contactSupport,
          style: FilledButton.styleFrom(
            backgroundColor: VineTheme.vineGreen,
          ),
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: VineTheme.whiteText,
                  ),
                )
              : const Text('Send request'),
        ),
      ],
    );
  }
}

/// Color picker widget for selecting profile background color.
class _ProfileColorPicker extends StatelessWidget {
  const _ProfileColorPicker({
    required this.selectedColor,
    required this.onColorChanged,
  });

  final Color? selectedColor;
  final ValueChanged<Color?> onColorChanged;

  // Preset colors from VineTheme brand accent palette
  static const List<Color> _presetColors = [
    VineTheme.vineGreen, // Green (brand primary)
    VineTheme.accentBlue, // Blue
    VineTheme.accentPurple, // Purple
    VineTheme.likeRed, // Red
    VineTheme.accentOrange, // Orange
    VineTheme.accentLime, // Lime
    VineTheme.accentPink, // Pink
    VineTheme.accentViolet, // Violet
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Preset color swatches
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            // "No color" option
            _ColorSwatch(
              color: null,
              isSelected: selectedColor == null,
              onTap: () => onColorChanged(null),
            ),
            // Preset colors
            for (final color in _presetColors)
              _ColorSwatch(
                color: color,
                isSelected: selectedColor == color,
                onTap: () => onColorChanged(color),
              ),
            // Custom color picker
            _CustomColorButton(
              currentColor: selectedColor,
              onColorPicked: onColorChanged,
            ),
          ],
        ),
      ],
    );
  }
}

/// Individual color swatch button.
class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final Color? color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color ?? VineTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? VineTheme.whiteText : Colors.transparent,
            width: 3,
          ),
        ),
        child: color == null
            ? const Icon(Icons.block, color: VineTheme.onSurfaceMuted, size: 20)
            : isSelected
            ? const Icon(Icons.check, color: VineTheme.whiteText, size: 20)
            : null,
      ),
    );
  }
}

/// Button to open custom color picker dialog.
class _CustomColorButton extends StatelessWidget {
  const _CustomColorButton({
    required this.currentColor,
    required this.onColorPicked,
  });

  final Color? currentColor;
  final ValueChanged<Color?> onColorPicked;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showColorPicker(context),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              VineTheme.error,
              VineTheme.warning,
              VineTheme.accentYellow,
              VineTheme.success,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: VineTheme.whiteText.withValues(alpha: 0.3)),
        ),
        child: const Icon(Icons.colorize, color: VineTheme.whiteText, size: 20),
      ),
    );
  }

  Future<void> _showColorPicker(BuildContext context) async {
    Color pickerColor = currentColor ?? VineTheme.vineGreen;

    final result = await showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VineTheme.cardBackground,
        title: const Text(
          'Pick a color',
          style: TextStyle(color: VineTheme.whiteText),
        ),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: pickerColor,
            onColorChanged: (color) => pickerColor = color,
            enableAlpha: false,
            displayThumbColor: true,
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: VineTheme.onSurfaceMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(pickerColor),
            child: const Text(
              'Select',
              style: TextStyle(color: VineTheme.vineGreen),
            ),
          ),
        ],
      ),
    );

    if (result != null) {
      onColorPicked(result);
    }
  }
}

/// Collapsible section for entering an external NIP-05 identifier.
///
/// Shows a toggle to switch between divine.video username mode and external
/// NIP-05 mode. When expanded, displays a text field for entering the
/// external NIP-05 (e.g., `alice@example.com`).
class _ExternalNip05Section extends StatelessWidget {
  const _ExternalNip05Section({
    required this.controller,
    required this.focusNode,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileEditorBloc, ProfileEditorState>(
      buildWhen: (prev, curr) =>
          prev.nip05Mode != curr.nip05Mode ||
          prev.externalNip05Error != curr.externalNip05Error,
      builder: (context, state) {
        final isExternal = state.nip05Mode == Nip05Mode.external_;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            // Toggle button
            GestureDetector(
              onTap: () {
                final newMode = isExternal
                    ? Nip05Mode.divine
                    : Nip05Mode.external_;
                context.read<ProfileEditorBloc>()
                  ..add(Nip05ModeChanged(newMode))
                  ..add(
                    ExternalNip05Changed(
                      newMode == Nip05Mode.external_ ? controller.text : '',
                    ),
                  );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      isExternal
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      color: isExternal
                          ? VineTheme.vineGreen
                          : VineTheme.onSurfaceMuted,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Use your own NIP-05 address',
                      style: VineTheme.bodyMediumFont(
                        color: VineTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // External NIP-05 input field (visible when toggled)
            if (isExternal) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Text(
                  'NIP-05 Address',
                  style: VineTheme.labelMediumFont(
                    color: focusNode.hasFocus
                        ? VineTheme.primary
                        : VineTheme.onSurfaceMuted,
                  ),
                ),
              ),
              TextFormField(
                controller: controller,
                focusNode: focusNode,
                style: VineTheme.bodyLargeFont(color: VineTheme.onSurface),
                decoration: InputDecoration(
                  isCollapsed: true,
                  hintText: 'you@example.com',
                  hintStyle: const TextStyle(color: VineTheme.onSurfaceMuted),
                  border: const UnderlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: VineTheme.neutral10),
                  ),
                  enabledBorder: const UnderlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: VineTheme.neutral10),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: VineTheme.neutral10),
                  ),
                  errorBorder: const UnderlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: VineTheme.neutral10),
                  ),
                  focusedErrorBorder: const UnderlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: VineTheme.neutral10),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                  errorMaxLines: 2,
                  errorText: switch (state.externalNip05Error) {
                    ExternalNip05ValidationError.invalidFormat =>
                      'Invalid NIP-05 format (e.g., name@domain.com)',
                    ExternalNip05ValidationError.divineDomain =>
                      'Use the username field above for divine.video',
                    null => null,
                  },
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                onChanged: (value) => context.read<ProfileEditorBloc>().add(
                  ExternalNip05Changed(value),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
