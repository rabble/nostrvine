import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/screens/clip_library_screen.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
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
  Future<void> _saveToGallery(WidgetRef ref) async {
    final finalRenderedClip = ref.read(videoEditorProvider).finalRenderedClip;
    if (finalRenderedClip == null) return;

    final gallerySaveService = ref.read(gallerySaveServiceProvider);
    await gallerySaveService.saveVideoToGallery(finalRenderedClip.video);
  }

  Future<void> _onSaveForLater(BuildContext context, WidgetRef ref) async {
    var saveSuccess = true;

    // Save the final rendered video to the gallery (non-blocking).
    unawaited(_saveToGallery(ref));

    try {
      // Save the draft to the library.
      final draftSuccess = await ref
          .read(videoEditorProvider.notifier)
          .saveAsDraft();
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
      saveSuccess = false;
    }

    if (!context.mounted) return;

    // Store router reference before showing SnackBar
    final router = GoRouter.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Build the status message
    // TODO(l10n): Replace with context.l10n when localization is added.
    final label = saveSuccess ? 'Saved to library' : 'Failed to save';

    scaffoldMessenger.showSnackBar(
      SnackBar(
        padding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        content: DivineSnackbarContainer(
          label: label,
          error: !saveSuccess,
          // TODO(l10n): Replace with context.l10n when localization is added.
          actionLabel: 'Go to Library',
          onActionPressed: () {
            scaffoldMessenger.hideCurrentSnackBar();
            router.push(ClipLibraryScreen.clipsPath);
          },
        ),
      ),
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
    // Save the final rendered video to the gallery (non-blocking).
    unawaited(_saveToGallery(ref));

    await ref.read(videoEditorProvider.notifier).postVideo(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xE5032017),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: VineTheme.outlineVariant),
          boxShadow: const [
            BoxShadow(
              color: Color(0x6B000000),
              blurRadius: 20,
              offset: Offset(0, 6),
            ),
          ],
        ),
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
        child: GestureDetector(
          onTap: isSaving || isProcessing ? null : onTap,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isSaving ? 0.6 : 1.0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xAA0E2B21), Color(0xE5032017)],
                ),
                border: Border.all(color: const Color(0xFF184235), width: 1.5),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
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
                          style: VineTheme.titleSmallFont(
                            color: VineTheme.primary,
                          ),
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
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF3ED9A2), VineTheme.primary],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x4D27C58B),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                // TODO(l10n): Replace with context.l10n when localization is
                // added.
                child: Text(
                  'Post',
                  style: VineTheme.titleSmallFont(
                    color: const Color(0xFF002C1C),
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
