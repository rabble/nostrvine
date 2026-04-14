import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/library_screen.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:openvine/widgets/gallery_permission_sheet.dart';
import 'package:unified_logger/unified_logger.dart';

/// Bottom bar with "Save for Later" and "Post" buttons for video metadata.
///
/// Buttons are disabled with reduced opacity when metadata is invalid.
/// Handles shared gallery-save logic for both actions (DRY).
class VideoMetadataBottomBar extends ConsumerWidget {
  /// Creates a video metadata bottom bar.
  const VideoMetadataBottomBar({super.key});

  /// Saves the final rendered video to the device gallery.
  ///
  /// When gallery permission is denied and the user has not previously
  /// opted out, a bottom sheet is shown offering to open Settings or
  /// dismiss forever. If the user opens Settings and comes back, the
  /// save is retried once.
  Future<void> _saveToGallery(
    BuildContext context,
    WidgetRef ref,
  ) async {
    // User opted out of gallery saves permanently.
    if (await isGalleryPermissionDismissedForever()) return;

    final finalRenderedClip = ref.read(videoEditorProvider).finalRenderedClip;
    if (finalRenderedClip == null) return;

    final gallerySaveService = ref.read(gallerySaveServiceProvider);
    final result = await gallerySaveService.saveVideoToGallery(
      finalRenderedClip.video,
    );

    if (result is! GallerySavePermissionDenied || !context.mounted) {
      return;
    }

    // Permission denied — show an actionable sheet instead of a snackbar.
    final permissionsService = ref.read(permissionsServiceProvider);
    final choice = await showGalleryPermissionSheet(
      context,
      permissionsService: permissionsService,
    );

    if (choice == GalleryPermissionChoice.openedSettings ||
        choice == GalleryPermissionChoice.granted) {
      // Retry once — the user may have just granted access.
      await gallerySaveService.saveVideoToGallery(
        finalRenderedClip.video,
      );
    }
  }

  void _showStatusSnackBar(
    BuildContext context, {
    required String label,
    required bool error,
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      SnackBar(
        padding: EdgeInsets.zero,
        backgroundColor: VineTheme.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        content: DivineSnackbarContainer(
          label: label,
          error: error,
          actionLabel: actionLabel,
          onActionPressed: onActionPressed != null
              ? () {
                  onActionPressed();
                  scaffoldMessenger.hideCurrentSnackBar();
                }
              : null,
        ),
      ),
    );
  }

  Future<void> _onSaveForLater(BuildContext context, WidgetRef ref) async {
    await _saveToGallery(context, ref);
    var draftSaved = true;

    try {
      // Save the draft to the library.
      final draftSuccess = await ref
          .read(videoEditorProvider.notifier)
          .saveAsDraft(enforceCreateNewDraft: true);
      if (!draftSuccess) {
        throw StateError('Failed to save draft');
      }
    } catch (e, stackTrace) {
      Log.error(
        'Failed to save: $e',
        name: 'VideoMetadataBottomBar',
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
      draftSaved = false;
    }

    if (!context.mounted) return;

    final router = GoRouter.of(context);

    _showStatusSnackBar(
      context,
      label: draftSaved ? 'Saved to library' : 'Failed to save',
      error: !draftSaved,
      actionLabel: 'Go to Library',
      onActionPressed: () => router.push(LibraryScreen.draftsPath),
    );

    if (draftSaved) {
      router.go(VideoFeedPage.pathForIndex(0));
      // Clear editor state after navigation animation completes (~600ms)
      Future.delayed(
        const Duration(milliseconds: 600),
        ref.read(videoPublishProvider.notifier).clearAll,
      );
    }
  }

  Future<void> _onPost(BuildContext context, WidgetRef ref) async {
    await _saveToGallery(context, ref);
    if (!context.mounted) return;

    await ref.read(videoEditorProvider.notifier).postVideo(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textScaler = MediaQuery.textScalerOf(context).clamp(
      maxScaleFactor: 1.15,
    );
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: Padding(
        padding: const .fromLTRB(16, 0, 16, 4),
        child: Row(
          crossAxisAlignment: .end,
          spacing: 10,
          children: [
            Expanded(
              child: _SaveForLaterButton(
                onTap: () => _onSaveForLater(context, ref),
              ),
            ),
            Expanded(child: _PostButton(onTap: () => _onPost(context, ref))),
          ],
        ),
      ),
    );
  }
}

/// Outlined button to save the video to drafts and gallery without publishing.
class _SaveForLaterButton extends ConsumerWidget {
  /// Creates a save for later button.
  const _SaveForLaterButton({required this.onTap});

  /// Called when the button is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      videoEditorProvider.select(
        (s) => (isSavingDraft: s.isSavingDraft, isProcessing: s.isProcessing),
      ),
    );
    final isSaving = state.isSavingDraft;
    final isProcessing = state.isProcessing;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: !isProcessing ? 1 : 0.32,
      child: Semantics(
        identifier: 'save_for_later_button',
        // TODO(l10n): Replace with context.l10n when localization is added.
        label: 'Save for later button',
        hint: isProcessing
            ? 'Rendering video...'
            : isSaving
            ? 'Saving video...'
            : 'Save video to drafts and '
                  '${GallerySaveService.destinationName}',
        button: true,
        enabled: !isSaving && !isProcessing,
        child: DivineButton(
          onPressed: isSaving || isProcessing ? null : onTap,
          type: .secondary,
          label: 'Save for Later',
        ),
      ),
    );
  }
}

/// Filled button to publish the video to the feed.
class _PostButton extends ConsumerWidget {
  /// Creates a post button.
  const _PostButton({required this.onTap});

  /// Called when the button is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isValidToPost = ref.watch(
      videoEditorProvider.select((s) => s.isValidToPost),
    );

    // Fade buttons when form is invalid
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isValidToPost ? 1 : 0.32,
      child: Semantics(
        identifier: 'post_button',
        // TODO(l10n): Replace with context.l10n when localization is added.
        label: 'Post button',
        hint: isValidToPost
            ? 'Publish video to feed'
            : 'Fill out the form to enable',
        button: true,
        enabled: isValidToPost,
        child: DivineButton(
          onPressed: isValidToPost ? onTap : null,
          expanded: true,
          label: 'Post',
        ),
      ),
    );
  }
}
