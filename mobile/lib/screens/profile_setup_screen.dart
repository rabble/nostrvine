// ABOUTME: Profile setup screen for new users to configure their display name, bio, and avatar
// ABOUTME: Publishes initial profile metadata to Nostr after setup is complete

import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/providers/username_notifier.dart';
import 'package:openvine/state/username_state.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:openvine/utils/unified_logger.dart';
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
    final usernameRepository = ref.watch(usernameRepositoryProvider);
    final userProfileService = ref.watch(userProfileServiceProvider);

    return BlocProvider<ProfileEditorBloc>(
      create: (context) => ProfileEditorBloc(
        profileRepository: profileRepository,
        usernameRepository: usernameRepository,
        userProfileService: userProfileService,
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

  bool _isUploadingImage = false;
  bool _isFormValid = false;
  File? _selectedImage;
  String? _uploadedImageUrl;
  // Store notifier reference to safely call in deactivate
  OverlayVisibility? _overlayNotifier;
  String? _initialUsername;

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
    // Mark settings as open to pause video playback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _overlayNotifier = ref.read(overlayVisibilityProvider.notifier);
      _overlayNotifier?.setSettingsOpen(true);
    });
  }

  @override
  void deactivate() {
    // Mark settings as closed when leaving
    // Use cached notifier reference since ref is invalid during deactivate
    // Must use Future to avoid modifying provider during widget tree build
    final notifier = _overlayNotifier;
    if (notifier != null) {
      Future(() {
        notifier.setSettingsOpen(false);
      });
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _pictureController.dispose();
    _nip05Controller.dispose();

    super.dispose();
  }

  Future<void> _loadExistingProfile() async {
    if (!widget.isNewUser) {
      // For imported users, try to load their existing profile
      try {
        final userProfileService = ref.read(userProfileServiceProvider);
        final authService = ref.read(authServiceProvider);

        if (authService.currentPublicKeyHex != null) {
          final profile = await userProfileService.fetchProfile(
            authService.currentPublicKeyHex!,
          );
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
              );
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
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: VineTheme.scrim15,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: SvgPicture.asset(
                      'assets/icon/info.svg',
                      width: 24,
                      height: 24,
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
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
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
                                        borderRadius: BorderRadius.circular(33),
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
                                                  color:
                                                      VineTheme.surfaceContainer,
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
                                                color:
                                                    VineTheme.surfaceContainer,
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: VineTheme.outlineMuted,
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
                                                color:
                                                    VineTheme.surfaceContainer,
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: VineTheme.outlineMuted,
                                                  width: 2,
                                                ),
                                              ),
                                              child: const Center(
                                                child: Icon(
                                                  Icons.link,
                                                  size: 24,
                                                  color: VineTheme.primary,
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
                            TextFormField(
                              controller: _nameController,
                              autofocus: false,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Display Name',
                                labelStyle: const TextStyle(color: Colors.grey),
                                hintText: 'How should people know you?',
                                hintStyle: TextStyle(color: Colors.grey[600]),
                                filled: true,
                                fillColor: Colors.grey[900],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey[700]!,
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: VineTheme.vineGreen,
                                    width: 2,
                                  ),
                                ),
                                prefixIcon: const Icon(
                                  Icons.person,
                                  color: Colors.grey,
                                ),
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
                            TextFormField(
                              controller: _bioController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Bio (Optional)',
                                labelStyle: const TextStyle(color: Colors.grey),
                                hintText: 'Tell people about yourself...',
                                hintStyle: TextStyle(color: Colors.grey[600]),
                                filled: true,
                                fillColor: Colors.grey[900],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey[700]!,
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: VineTheme.vineGreen,
                                    width: 2,
                                  ),
                                ),
                                prefixIcon: const Icon(
                                  Icons.info_outline,
                                  color: Colors.grey,
                                ),
                              ),
                              maxLines: 3,
                              minLines: 1,
                              maxLength: 160,
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (_) =>
                                  FocusScope.of(context).nextFocus(),
                            ),
                            const SizedBox(height: 16),

                            // NIP-05 Username (optional)
                            TextFormField(
                              controller: _nip05Controller,
                              style: const TextStyle(color: Colors.white),
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              decoration: InputDecoration(
                                labelText: 'Username (Optional)',
                                labelStyle: const TextStyle(color: Colors.grey),
                                hintText: 'username',
                                hintStyle: TextStyle(color: Colors.grey[600]),
                                filled: true,
                                fillColor: Colors.grey[900],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey[700]!,
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: VineTheme.vineGreen,
                                    width: 2,
                                  ),
                                ),
                                prefixIcon: const Icon(
                                  Icons.verified_user,
                                  color: Colors.grey,
                                ),
                                suffixText: '@divine.video',
                                suffixStyle: TextStyle(color: Colors.grey[500]),
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
                            const SizedBox(height: 32),

                            // Action buttons
                            Row(
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
                                            WidgetsBinding.instance
                                                .addPostFrameCallback((_) {
                                                  if (mounted) {
                                                    Navigator.of(context).pop();
                                                  }
                                                });
                                          },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(
                                        color: Colors.white,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text('Cancel'),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                if (pubkey != null)
                                  Expanded(
                                    child: _SaveButton(
                                      canSave:
                                          _isFormValid &&
                                          (_nip05Controller.text
                                                  .trim()
                                                  .isEmpty ||
                                              usernameState.isAvailable ||
                                              _nip05Controller.text.trim() ==
                                                  _initialUsername) &&
                                          !usernameState.isChecking,
                                      onSave: () =>
                                          context.read<ProfileEditorBloc>().add(
                                            ProfileSaved(
                                              pubkey: pubkey,
                                              displayName: _nameController.text,
                                              about: _bioController.text,
                                              username: _nip05Controller.text,
                                              picture: _pictureController.text,
                                            ),
                                          ),
                                    ),
                                  ),
                              ],
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
          'assets/icon/user-avatar.png',
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
          'assets/icon/user-avatar.png',
          width: 144,
          height: 144,
          fit: BoxFit.cover,
        ),
      );
    } else {
      return Image.asset(
        'assets/icon/user-avatar.png',
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
    VineBottomSheet.show<void>(
      context: context,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                text: TextSpan(
                  style: VineTheme.bodyLargeFont(color: VineTheme.onSurface),
                  children: const [
                    TextSpan(
                      text: 'DiVine is built on Nostr,',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text:
                          ' a censorship-resistant open protocol that lets people communicate online without relying on a single company or platform. ',
                    ),
                    TextSpan(
                      text:
                          'When you sign up for diVine, you get a new Nostr identity.',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Nostr lets you own your content, identity and social graph, which you can use across many apps. The result is more choice, less lock-in, and a healthier, more resilient social internet.',
                style: VineTheme.bodyLargeFont(color: VineTheme.onSurface),
              ),
              const SizedBox(height: 16),
              Text(
                'Nostr lingo:',
                style: VineTheme.titleSmallFont(color: VineTheme.onSurface),
              ),
              const SizedBox(height: 8),
              _buildBulletPoint(
                'npub:',
                " Your public Nostr address. It's safe to share and lets others find, follow, or message you across Nostr apps.",
              ),
              const SizedBox(height: 8),
              _buildBulletPoint(
                'nsec:',
                ' Your private key and proof of ownership. It gives full control of your Nostr identity, so ',
                italicSuffix: 'always keep it secret!',
              ),
              const SizedBox(height: 8),
              _buildBulletPoint(
                'Nostr username:',
                ' A human-readable name (like @name.divine.video) that links to your npub. It makes your Nostr identity easier to recognize and verify, similar to an email address.',
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () async {
                  final uri = Uri.parse('https://divine.video/about');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: RichText(
                  text: TextSpan(
                    style: VineTheme.bodyLargeFont(color: VineTheme.onSurface),
                    children: const [
                      TextSpan(text: 'Learn more at '),
                      TextSpan(
                        text: 'divine.video/about',
                        style: TextStyle(
                          decoration: TextDecoration.underline,
                          decorationColor: VineTheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
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
                    'Got it!',
                    style: VineTheme.titleMediumFont(
                      color: VineTheme.vineGreen,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showImageUrlSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: VineTheme.surfaceBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(VineTheme.bottomSheetBorderRadius),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: VineTheme.onSurfaceMuted,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    'Add image URL',
                    style: VineTheme.titleMediumFont(color: VineTheme.onSurface),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _pictureController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Image URL',
                    labelStyle: const TextStyle(color: VineTheme.primary),
                    hintText: 'https://example.com/your-avatar.jpg',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    filled: true,
                    fillColor: VineTheme.surfaceContainer,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: VineTheme.primary,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: VineTheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                  onFieldSubmitted: (_) => Navigator.of(context).pop(),
                  keyboardType: TextInputType.url,
                  autofocus: true,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBulletPoint(
    String boldText,
    String normalText, {
    String? italicSuffix,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('• ', style: VineTheme.bodyLargeFont(color: VineTheme.onSurface)),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: VineTheme.bodyLargeFont(color: VineTheme.onSurface),
              children: [
                TextSpan(
                  text: boldText,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: normalText),
                if (italicSuffix != null)
                  TextSpan(
                    text: italicSuffix,
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
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
        foregroundColor: Colors.white,
        disabledBackgroundColor: VineTheme.vineGreen.withValues(alpha: 0.4),
        disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: isLoading
          ? const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Text('Saving...'),
              ],
            )
          : const Text(
              'Save',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
