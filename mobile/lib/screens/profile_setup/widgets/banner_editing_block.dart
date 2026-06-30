import 'dart:async';
import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/image_crop_launcher_provider.dart';
import 'package:openvine/screens/image_crop_editor/image_crop_editor.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:unified_logger/unified_logger.dart';

/// Banner editing block: 3:1 preview, gallery upload, and color swatches.
///
/// Image and color are mutually exclusive — selecting one clears the other
/// at the bloc layer. The preview reads
/// `pendingBannerUrl ?? pendingBannerColor ?? persistedBanner` via
/// granular `context.select`s so unrelated state changes don't rebuild it.
class BannerEditingBlock extends StatelessWidget {
  const BannerEditingBlock({super.key});

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

    final cropLauncher = container.read(imageCropLauncherProvider);
    Uint8List? cropped;
    if (kIsWeb) {
      final bytes = await picked.readAsBytes();
      if (!context.mounted) return;
      cropped = await cropLauncher(
        context,
        kind: ImageCropKind.banner,
        bytes: bytes,
      );
    } else {
      if (!context.mounted) return;
      cropped = await cropLauncher(
        context,
        kind: ImageCropKind.banner,
        file: File(picked.path),
      );
    }

    if (cropped == null) return;
    if (!context.mounted) return;

    editorBloc.add(
      ProfileBannerUploadRequested(
        pubkey: pk,
        bytes: cropped,
        filename: ImageCropKind.banner.filename,
        mimeType: ImageCropKind.banner.mimeType,
      ),
    );
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
