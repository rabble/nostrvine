// ABOUTME: Profile setup screen for new users to configure their display name, bio, and avatar
// ABOUTME: Publishes initial profile metadata to Nostr after setup is complete

import 'dart:async';
import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/models/user_profile.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/providers/username_notifier.dart';
import 'package:openvine/state/username_state.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/branded_loading_scaffold.dart';
import 'package:openvine/widgets/profile/nostr_info_sheet_content.dart';
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

    // Show loading until NostrClient has keys
    if (profileRepository == null) {
      return const BrandedLoadingScaffold();
    }

    return BlocProvider<ProfileEditorBloc>(
      create: (context) => ProfileEditorBloc(
        profileRepository: profileRepository,
        userProfileService: userProfileService,
        hasExistingProfile: authService.hasExistingProfile,
      ),
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
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _pictureController = TextEditingController();
  final _nip05Controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  // Focus nodes for tracking field focus state
  final _nameFocusNode = FocusNode();
  final _bioFocusNode = FocusNode();
  final _usernameFocusNode = FocusNode();

  bool _isUploadingImage = false;
  bool _isFormValid = false;
  File? _selectedImage;
  String? _uploadedImageUrl;
  String? _initialUsername;
  Color? _selectedProfileColor;

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
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

  Future<void> _loadExistingProfile() async {
    if (!widget.isNewUser) {
      // For imported users, try to load their existing profile
      try {
        final authService = ref.read(authServiceProvider);

        if (authService.currentPublicKeyHex != null) {
          final profileRepo = ref.read(profileRepositoryProvider);
          // Return early if NostrClient doesn't have keys yet
          if (profileRepo == null) return;
          final repoProfile = await profileRepo.getProfile(
            pubkey: authService.currentPublicKeyHex!,
          );
          final profile = repoProfile != null
              ? UserProfile.fromJson(repoProfile.toJson())
              : null;
          if (profile != null && mounted) {
            setState(() {
              // Use bestDisplayName which handles name/displayName fallback properly
              _nameController.text = profile.displayName ?? profile.name ?? '';
              _bioController.text = profile.about ?? '';
              _pictureController.text = profile.picture ?? '';

              // Extract username from NIP-05 if present
              if (profile.nip05 != null &&
                  (profile.nip05!.endsWith('@divine.video') ||
                      profile.nip05!.endsWith('@openvine.co'))) {
                final username = profile.nip05!.split('@')[0];
                _nip05Controller.text = username;
                _initialUsername = username;
              }

              // Load profile color from banner field
              _selectedProfileColor = profile.profileBackgroundColor;
            });

            Log.info(
              '✅ Pre-filled profile setup form with existing data:',
              name: 'ProfileSetupScreen',
              category: LogCategory.ui,
            );
            Log.info(
              '  - name: ${profile.name}',
              name: 'ProfileSetupScreen',
              category: LogCategory.ui,
            );
            Log.info(
              '  - displayName: ${profile.displayName}',
              name: 'ProfileSetupScreen',
              category: LogCategory.ui,
            );
            Log.info(
              '  - about: ${profile.about}',
              name: 'ProfileSetupScreen',
              category: LogCategory.ui,
            );
            Log.info(
              '  - picture: ${profile.picture}',
              name: 'ProfileSetupScreen',
              category: LogCategory.ui,
            );
            Log.info(
              '  - banner: ${profile.banner}',
              name: 'ProfileSetupScreen',
              category: LogCategory.ui,
            );
            Log.info(
              '  - website: ${profile.website}',
              name: 'ProfileSetupScreen',
              category: LogCategory.ui,
            );
            Log.info(
              '  - nip05: ${profile.nip05}',
              name: 'ProfileSetupScreen',
              category: LogCategory.ui,
            );
            Log.info(
              '  - lud16: ${profile.lud16}',
              name: 'ProfileSetupScreen',
              category: LogCategory.ui,
            );
          }
        }
      } catch (e) {
        Log.error(
          'Failed to load existing profile: $e',
          name: 'ProfileSetupScreen',
          category: LogCategory.ui,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // TODO(refactor): Migrate usernameProvider to ProfileEditorBloc with
    // debounced username validation
    final usernameState = ref.watch(usernameProvider);
    final pubkey = ref.watch(authServiceProvider).currentPublicKeyHex;

    return BlocConsumer<ProfileEditorBloc, ProfileEditorState>(
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
                      color: Colors.white,
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
              backgroundColor: Colors.white,
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
        } else if (state.status == ProfileEditorStatus.confirmationRequired) {
          // Show confirmation dialog for blank profile overwrite warning
          showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              backgroundColor: VineTheme.cardBackground,
              title: const Text(
                'Create new profile?',
                style: TextStyle(color: VineTheme.whiteText),
              ),
              content: const Text(
                "We didn't find an existing profile on your relays. Publishing will create a new profile. Continue?",
                style: TextStyle(color: VineTheme.secondaryText),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
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
          // Invalidate profile providers after rollback so UI shows correct data
          final currentPubkey = ref
              .read(authServiceProvider)
              .currentPublicKeyHex;
          if (currentPubkey != null) {
            ref.invalidate(fetchUserProfileProvider(currentPubkey));
            ref.invalidate(userProfileReactiveProvider(currentPubkey));
          }
          // Re-check username so indicator shows current state (e.g., "taken")
          final username = _nip05Controller.text.trim();
          if (username.isNotEmpty) {
            ref.read(usernameProvider.notifier).checkAvailability(username);
          }
          switch (state.error) {
            case ProfileEditorError.usernameTaken:
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'Username was just taken. Please choose another.',
                  ),
                  backgroundColor: Colors.red[700],
                  duration: const Duration(seconds: 3),
                ),
              );
            case ProfileEditorError.usernameReserved:
              final username = usernameState.username;
              showDialog<void>(
                context: context,
                builder: (context) => UsernameReservedDialog(username),
              ).then((_) {
                ref.read(usernameProvider.notifier).setReserved(username);
              });
            case ProfileEditorError.publishFailed:
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to publish profile. Please try again.'),
                  backgroundColor: Colors.red,
                ),
              );
            case null:
              break;
          }
        }
      },
      builder: (context, profileEditorState) {
        return Scaffold(
          backgroundColor: VineTheme.surfaceContainerHigh,
          appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 0,
            toolbarHeight: 72,
            leadingWidth: 80,
            centerTitle: true,
            backgroundColor: Colors.transparent,
            leading: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: VineTheme.scrim15,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: SvgPicture.asset(
                  'assets/icon/CaretLeft.svg',
                  width: 32,
                  height: 32,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              onPressed: () {
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
              tooltip: 'Back',
            ),
            title: Text('Edit Profile', style: VineTheme.titleMediumFont()),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Container(
                    width: 48,
                    height: 48,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: VineTheme.scrim15,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: SvgPicture.asset(
                      'assets/icon/info.svg',
                      width: 32,
                      height: 32,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  onPressed: () => _showNostrInfoSheet(context),
                  tooltip: 'About Nostr',
                ),
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
                        child: Form(
                          key: _formKey,
                          onChanged: () {
                            final isValid =
                                _formKey.currentState?.validate() ?? false;
                            if (isValid != _isFormValid) {
                              setState(() {
                                _isFormValid = isValid;
                              });
                            }
                          },
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
                                      Container(
                                        width: 144,
                                        height: 144,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            33,
                                          ),
                                          color: Colors.grey[800],
                                          border: Border.all(
                                            color: VineTheme.onSurfaceDisabled,
                                            width: 1.64,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            31.36,
                                          ),
                                          child: _buildProfilePicturePreview(),
                                        ),
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
                                                  BorderRadius.circular(33),
                                              color: Colors.black.withValues(
                                                alpha: 0.7,
                                              ),
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
                                autofocus: false,
                                style: VineTheme.bodyLargeFont(
                                  color: VineTheme.onSurface,
                                ),
                                decoration: InputDecoration(
                                  isCollapsed: true,
                                  hintText: 'How should people know you?',
                                  hintStyle: TextStyle(color: Colors.grey[600]),
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
                                decoration: InputDecoration(
                                  isCollapsed: true,
                                  hintText: 'Tell people about yourself...',
                                  hintStyle: TextStyle(color: Colors.grey[600]),
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
                              Padding(
                                padding: const EdgeInsets.only(left: 16),
                                child: Text(
                                  'Username (Optional)',
                                  style: VineTheme.labelMediumFont(
                                    color: _usernameFocusNode.hasFocus
                                        ? VineTheme.primary
                                        : VineTheme.onSurfaceMuted,
                                  ),
                                ),
                              ),
                              TextFormField(
                                controller: _nip05Controller,
                                focusNode: _usernameFocusNode,
                                style: VineTheme.bodyLargeFont(
                                  color: VineTheme.onSurface,
                                ),
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                decoration: InputDecoration(
                                  isCollapsed: true,
                                  hintText: 'username',
                                  hintStyle: TextStyle(color: Colors.grey[600]),
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
                                  prefixText: '@',
                                  prefixStyle: VineTheme.bodyLargeFont(
                                    color: VineTheme.onSurfaceMuted,
                                  ),
                                  suffixText: '@divine.video',
                                  suffixStyle: VineTheme.bodyLargeFont(
                                    color: VineTheme.onSurfaceMuted,
                                  ),
                                  errorMaxLines: 2,
                                ),
                                textInputAction: TextInputAction.next,
                                onFieldSubmitted: (_) =>
                                    FocusScope.of(context).nextFocus(),
                                onChanged: (value) => ref
                                    .read(usernameProvider.notifier)
                                    .onUsernameChanged(value),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return null; // Optional field
                                  }

                                  final regex = RegExp(
                                    r'^[a-z0-9\-_.]+$',
                                    caseSensitive: false,
                                  );
                                  if (!regex.hasMatch(value)) {
                                    return 'Username can only contain letters, numbers, dash, underscore, and dot';
                                  }
                                  if (value.length < kMinUsernameLength) {
                                    return 'Username must be at least $kMinUsernameLength characters';
                                  }
                                  if (value.length > kMaxUsernameLength) {
                                    return 'Username must be $kMaxUsernameLength characters or less';
                                  }
                                  return null;
                                },
                              ),
                              // Username status indicators
                              UsernameStatusIndicator(state: usernameState),

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
                              _ProfileColorPicker(
                                selectedColor: _selectedProfileColor,
                                onColorChanged: (color) {
                                  setState(() {
                                    _selectedProfileColor = color;
                                  });
                                },
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
                              WidgetsBinding.instance.addPostFrameCallback((_) {
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
                            _isFormValid &&
                            (_nip05Controller.text.trim().isEmpty ||
                                usernameState.isAvailable ||
                                _nip05Controller.text.trim() ==
                                    _initialUsername) &&
                            !usernameState.isChecking,
                        onSave: () => context.read<ProfileEditorBloc>().add(
                          ProfileSaved(
                            pubkey: pubkey,
                            displayName: _nameController.text,
                            about: _bioController.text,
                            username: _nip05Controller.text,
                            picture: _pictureController.text,
                            banner: _selectedProfileColor != null
                                ? '0x${_selectedProfileColor!.toARGB32().toRadixString(16).substring(2)}'
                                : null,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Skip button removed from UI - no longer needed
  // void _skipProfileSetup() {
  //   if (widget.isNewUser) {
  //     // For new users, navigate back to the auth flow
  //     // The auth service should already be in authenticated state
  //     Navigator.of(context).popUntil((route) => route.isFirst);
  //   } else {
  //     // For existing users, just go back to previous screen
  //     Navigator.of(context).pop();
  //   }
  // }

  Widget _buildProfilePicturePreview() {
    // Priority: selected image > uploaded URL > manual URL > placeholder
    if (_selectedImage != null) {
      return Image.file(
        _selectedImage!,
        fit: BoxFit.cover,
        width: 144,
        height: 144,
      );
    } else if (_uploadedImageUrl != null) {
      return Image.network(
        _uploadedImageUrl!,
        fit: BoxFit.cover,
        width: 144,
        height: 144,
        errorBuilder: (context, error, stackTrace) => Image.asset(
          'assets/icon/acid_avatar.png',
          width: 144,
          height: 144,
          fit: BoxFit.cover,
        ),
      );
    } else if (_pictureController.text.isNotEmpty) {
      return Image.network(
        _pictureController.text,
        fit: BoxFit.cover,
        width: 144,
        height: 144,
        errorBuilder: (context, error, stackTrace) => Image.asset(
          'assets/icon/acid_avatar.png',
          width: 144,
          height: 144,
          fit: BoxFit.cover,
        ),
      );
    } else {
      return Image.asset(
        'assets/icon/acid_avatar.png',
        width: 144,
        height: 144,
        fit: BoxFit.cover,
      );
    }
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
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Got it',
              textColor: Colors.white,
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
        mimeType: 'image/jpeg',
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
              backgroundColor: Colors.green,
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
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Got it',
              textColor: Colors.white,
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
      if (mounted) {
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
              style: const TextStyle(color: Colors.white),
              cursorColor: VineTheme.primary,
              decoration: InputDecoration(
                hintText: 'https://example.com/image.jpg',
                hintStyle: TextStyle(color: Colors.grey[600]),
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
      if (mounted) {
        FocusScope.of(context).unfocus();
      }
    });
  }
}

/// Displays username availability status (checking, available, taken, reserved, error)
class UsernameStatusIndicator extends StatelessWidget {
  const UsernameStatusIndicator({required this.state, super.key});

  final UsernameState state;

  @override
  Widget build(BuildContext context) {
    if (state.status == UsernameCheckStatus.idle || state.username.isEmpty) {
      return const SizedBox.shrink();
    }

    if (state.isChecking) {
      return const _UsernameCheckingIndicator();
    }

    if (state.isAvailable) {
      return const _UsernameAvailableIndicator();
    }

    if (state.isTaken) {
      return const _UsernameTakenIndicator();
    }

    if (state.isReserved) {
      return _UsernameReservedIndicator();
    }

    if (state.hasError) {
      return _UsernameErrorIndicator(
        message: state.errorMessage ?? 'Failed to check availability',
      );
    }

    return const SizedBox.shrink();
  }
}

class _UsernameCheckingIndicator extends StatelessWidget {
  const _UsernameCheckingIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            'Checking availability...',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
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
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: VineTheme.vineGreen, size: 16),
          const SizedBox(width: 8),
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
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(Icons.cancel, color: Colors.red[400], size: 16),
          const SizedBox(width: 8),
          Text(
            'Username already taken',
            style: TextStyle(color: Colors.red[400], fontSize: 12),
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
      child: Row(
        children: [
          Icon(Icons.lock, color: Colors.orange[400], size: 16),
          const SizedBox(width: 8),
          Text(
            'Username is reserved',
            style: TextStyle(color: Colors.orange[400], fontSize: 12),
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
          Icon(Icons.error_outline, color: Colors.orange[400], size: 16),
          const SizedBox(width: 8),
          Text(
            message,
            style: TextStyle(color: Colors.orange[400], fontSize: 12),
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
class UsernameReservedDialog extends StatelessWidget {
  const UsernameReservedDialog(this.username);

  final String username;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: VineTheme.cardBackground,
      title: const Text(
        'Username reserved',
        style: TextStyle(color: VineTheme.whiteText),
      ),
      content: RichText(
        text: TextSpan(
          style: TextStyle(color: VineTheme.secondaryText),
          children: [
            TextSpan(text: 'The name $username is reserved. Please email '),
            WidgetSpan(
              child: GestureDetector(
                onTap: () async {
                  final launched = await launchUrl(
                    Uri.parse(
                      'mailto:names@divine.video?subject=Reserved username request: $username',
                    ),
                  );
                  if (!launched && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Couldn't open email. Send to: names@divine.video",
                        ),
                      ),
                    );
                  }
                },
                child: Text(
                  'names@divine.video',
                  style: TextStyle(
                    color: VineTheme.vineGreen,
                    decoration: TextDecoration.underline,
                    decorationColor: VineTheme.vineGreen,
                  ),
                ),
              ),
            ),
            const TextSpan(
              text: ' explaining and proving why you should own it.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close', style: TextStyle(color: VineTheme.lightText)),
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

  // Preset colors inspired by classic Vine profile colors
  static const _presetColors = [
    Color(0xFF33CCBF), // Teal (Vine default)
    Color(0xFF6B93D6), // Blue
    Color(0xFF9B59B6), // Purple
    Color(0xFFE74C3C), // Red
    Color(0xFFF39C12), // Orange
    Color(0xFF2ECC71), // Green
    Color(0xFFE91E63), // Pink
    Color(0xFF00BCD4), // Cyan
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
            color: isSelected ? Colors.white : Colors.transparent,
            width: 3,
          ),
        ),
        child: color == null
            ? const Icon(Icons.block, color: VineTheme.onSurfaceMuted, size: 20)
            : isSelected
            ? const Icon(Icons.check, color: Colors.white, size: 20)
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
            colors: [Colors.red, Colors.orange, Colors.yellow, Colors.green],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: const Icon(Icons.colorize, color: Colors.white, size: 20),
      ),
    );
  }

  Future<void> _showColorPicker(BuildContext context) async {
    Color pickerColor = currentColor ?? const Color(0xFF33CCBF);

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
