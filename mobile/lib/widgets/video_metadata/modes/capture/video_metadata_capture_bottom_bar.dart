import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/library_screen.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:openvine/utils/gallery_save_utils.dart';
import 'package:unified_logger/unified_logger.dart';

/// Bottom bar with "Save for Later" and "Post" buttons for video metadata.
///
/// Buttons are disabled with reduced opacity when metadata is invalid.
/// Handles shared gallery-save logic for both actions (DRY).
class VideoMetadataCaptureBottomBar extends ConsumerWidget {
  /// Creates a video metadata bottom bar.
  const VideoMetadataCaptureBottomBar({super.key});

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
    await saveToGallery(context, ref);
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
        name: 'VideoMetadataCaptureBottomBar',
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
      label: draftSaved
          ? context.l10n.videoMetadataSavedToLibrarySnackbar
          : context.l10n.videoMetadataFailedToSaveSnackbar,
      error: !draftSaved,
      actionLabel: context.l10n.videoMetadataGoToLibraryButton,
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
    await saveToGallery(context, ref);
    if (!context.mounted) return;

    await ref.read(videoEditorProvider.notifier).postVideo(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textScaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: 1.15);
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
        label: context.l10n.videoMetadataSaveForLaterSemanticLabel,
        hint: isProcessing
            ? context.l10n.videoMetadataRenderingVideoHint
            : isSaving
            ? context.l10n.videoMetadataSavingVideoHint
            : context.l10n.videoMetadataSaveToDraftsHint(
                GallerySaveService.destinationName,
              ),
        button: true,
        enabled: !isSaving && !isProcessing,
        child: DivineButton(
          onPressed: isSaving || isProcessing ? null : onTap,
          type: .secondary,
          label: context.l10n.videoMetadataSaveForLaterButton,
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
        label: context.l10n.videoMetadataPostSemanticLabel,
        hint: isValidToPost
            ? context.l10n.videoMetadataPublishVideoHint
            : context.l10n.videoMetadataFormNotReadyHint,
        button: true,
        enabled: isValidToPost,
        child: DivineButton(
          onPressed: isValidToPost ? onTap : null,
          expanded: true,
          label: context.l10n.videoMetadataPostButton,
        ),
      ),
    );
  }
}
