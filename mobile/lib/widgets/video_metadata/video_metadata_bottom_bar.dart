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
import 'package:openvine/utils/unified_logger.dart';

/// Bottom bar with "Save for Later" and "Post" buttons for video metadata.
///
/// Buttons are disabled with reduced opacity when metadata is invalid.
/// Handles shared gallery-save logic for both actions (DRY).
class VideoMetadataBottomBar extends ConsumerWidget {
  /// Creates a video metadata bottom bar.
  const VideoMetadataBottomBar({super.key});

  /// Saves the final rendered video to the device gallery.
  Future<GallerySaveResult?> _saveToGallery(WidgetRef ref) async {
    final finalRenderedClip = ref.read(videoEditorProvider).finalRenderedClip;
    if (finalRenderedClip == null) return null;

    final gallerySaveService = ref.read(gallerySaveServiceProvider);
    return gallerySaveService.saveVideoToGallery(finalRenderedClip.video);
  }

  String? _gallerySaveFailureMessage(GallerySaveResult? result) {
    final destination = GallerySaveService.destinationName;

    return switch (result) {
      null || GallerySaveSuccess() => null,
      GallerySavePermissionDenied() => '$destination permission denied',
      GallerySaveFailure(:final reason) =>
        'failed to save to $destination: $reason',
    };
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
    final galleryResult = await _saveToGallery(ref);
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
    final galleryFailureMessage = _gallerySaveFailureMessage(galleryResult);
    final gallerySaveSucceeded =
        galleryResult == null || galleryResult is GallerySaveSuccess;
    final saveSuccess = draftSaved && gallerySaveSucceeded;
    final destination = GallerySaveService.destinationName;

    final label = switch ((draftSaved, galleryFailureMessage, galleryResult)) {
      (true, null, _) => 'Saved to library',
      (true, final message?, _) => 'Saved to library, but $message',
      (false, null, GallerySaveSuccess()) =>
        'Saved to $destination, but failed to save to library',
      (false, final message?, _) => 'Failed to save to library, and $message',
      (false, null, _) => 'Failed to save',
    };

    _showStatusSnackBar(
      context,
      label: label,
      error: !saveSuccess,
      actionLabel: 'Go to Library',
      onActionPressed: () => router.push(LibraryScreen.draftsPath),
    );

    if (saveSuccess) {
      router.go(VideoFeedPage.pathForIndex(0));
      // Clear editor state after navigation animation completes (~600ms)
      Future.delayed(
        const Duration(milliseconds: 600),
        ref.read(videoPublishProvider.notifier).clearAll,
      );
    }
  }

  Future<void> _onPost(BuildContext context, WidgetRef ref) async {
    final galleryResult = await _saveToGallery(ref);
    if (!context.mounted) return;

    final galleryFailureMessage = _gallerySaveFailureMessage(galleryResult);
    if (galleryFailureMessage != null) {
      _showStatusSnackBar(
        context,
        label: '$galleryFailureMessage. Video will still post.',
        error: true,
      );
    }

    await ref.read(videoEditorProvider.notifier).postVideo(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
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
        child: GestureDetector(
          onTap: isSaving || isProcessing ? null : onTap,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isSaving ? 0.6 : 1.0,
            child: Container(
              decoration: BoxDecoration(
                color: VineTheme.surfaceContainer,
                border: Border.all(color: VineTheme.containerLow, width: 2),
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: VineTheme.primary,
                        ),
                      )
                    // TODO(l10n): Replace with context.l10n when localization
                    // is added.
                    : Text(
                        'Save for Later',
                        style: VineTheme.titleMediumFont(
                          fontSize: 16,
                          color: VineTheme.primary,
                          height: 1.33,
                        ),
                      ),
              ),
            ),
          ),
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
        child: GestureDetector(
          onTap: isValidToPost ? onTap : null,
          child: Container(
            decoration: BoxDecoration(
              color: VineTheme.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              // TODO(l10n): Replace with context.l10n when localization is
              // added.
              child: Text(
                'Post',
                style: VineTheme.titleMediumFont(
                  fontSize: 16,
                  height: 1.33,
                  color: VineTheme.onPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
