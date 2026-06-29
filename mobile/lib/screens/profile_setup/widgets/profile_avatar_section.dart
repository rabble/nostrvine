import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/profile_setup/widgets/profile_image_picker.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:unified_logger/unified_logger.dart';

class ProfileAvatarSection extends ConsumerStatefulWidget {
  const ProfileAvatarSection({required this.nameController, super.key});

  final TextEditingController nameController;

  @override
  ConsumerState<ProfileAvatarSection> createState() =>
      _ProfileAvatarSectionState();
}

class _ProfileAvatarSectionState extends ConsumerState<ProfileAvatarSection> {
  File? _selectedImage;
  Uint8List? _selectedImageBytes;
  final TextEditingController _pictureController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    widget.nameController.addListener(_onNameChanged);
  }

  @override
  void didUpdateWidget(ProfileAvatarSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nameController != widget.nameController) {
      oldWidget.nameController.removeListener(_onNameChanged);
      widget.nameController.addListener(_onNameChanged);
    }
  }

  void _onNameChanged() => setState(() {});

  @override
  void dispose() {
    widget.nameController.removeListener(_onNameChanged);
    _pictureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pubkey = ref.watch(authServiceProvider).currentPublicKeyHex;
    return BlocListener<ProfileEditorBloc, ProfileEditorState>(
      // Pre-fill the manual image-URL sheet with the persisted picture once it
      // loads, matching the pre-decomposition seeding behaviour.
      listenWhen: (previous, current) =>
          previous.persistedPictureUrl != current.persistedPictureUrl,
      listener: (context, state) =>
          _pictureController.text = state.persistedPictureUrl ?? '',
      child: Center(
        child: SizedBox(
          // 144 avatar + 20 (half of 40px buttons extending below)
          height: 164,
          width: 144,
          child: BlocBuilder<ProfileEditorBloc, ProfileEditorState>(
            buildWhen: (prev, curr) =>
                prev.pendingAvatarStatus != curr.pendingAvatarStatus ||
                prev.pendingPictureUrl != curr.pendingPictureUrl ||
                prev.persistedPictureUrl != curr.persistedPictureUrl,
            builder: (context, editorState) {
              final isUploadingImage =
                  editorState.pendingAvatarStatus ==
                  PendingAvatarStatus.uploading;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  UserAvatar(
                    imageProvider: _buildProfilePictureProvider(editorState),
                    name: widget.nameController.text.trim(),
                    placeholderSeed: pubkey,
                    size: 144,
                    semanticLabel:
                        context.l10n.profileSetupProfilePicturePreview,
                  ),
                  if (isUploadingImage)
                    Positioned(
                      top: 0,
                      left: 0,
                      width: 144,
                      height: 144,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(56),
                          color: VineTheme.backgroundColor.withValues(
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
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Camera capture is mobile-only.
                        if (!isDesktopImagePickerPlatform()) ...[
                          _ImageSourceButton(
                            iconAsset: DivineIconName.cameraPlus.assetPath,
                            onTap: isUploadingImage
                                ? null
                                : () => _pickImage(ImageSource.camera),
                          ),
                          const SizedBox(width: 12),
                        ],
                        _ImageSourceButton(
                          iconAsset: DivineIconName.imagesSquare.assetPath,
                          onTap: isUploadingImage
                              ? null
                              : () => _pickImage(ImageSource.gallery),
                        ),
                        const SizedBox(width: 12),
                        _ImageSourceButton(
                          iconAsset: DivineIconName.linkSimple.assetPath,
                          onTap: isUploadingImage
                              ? null
                              : () => _showImageUrlSheet(context),
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

      final picked = await pickProfileXFile(source, _picker, context);
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

class _ImageSourceButton extends StatelessWidget {
  const _ImageSourceButton({required this.iconAsset, required this.onTap});

  final String iconAsset;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: VineTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: VineTheme.outlineMuted, width: 2),
        ),
        child: Center(
          child: SvgPicture.asset(
            iconAsset,
            width: 24,
            height: 24,
            colorFilter: const ColorFilter.mode(
              VineTheme.primary,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
}
