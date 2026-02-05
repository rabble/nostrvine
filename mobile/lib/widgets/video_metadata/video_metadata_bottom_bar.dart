import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:openvine/models/saved_clip.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/screens/clip_library_screen.dart';
import 'package:openvine/screens/home_screen_router.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Bottom bar with "Save for Later" and "Post" buttons for video metadata.
///
/// Buttons are disabled with reduced opacity when metadata is invalid.
class VideoMetadataBottomBar extends StatelessWidget {
  /// Creates a video metadata bottom bar.
  const VideoMetadataBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: _SaveForLaterButton()),
          SizedBox(width: 16),
          Expanded(child: _PostButton()),
        ],
      ),
    );
  }
}

/// Outlined button to save the video to drafts and gallery without publishing.
class _SaveForLaterButton extends ConsumerWidget {
  /// Creates a save for later button.
  const _SaveForLaterButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSaving = ref.watch(
      videoEditorProvider.select((s) => s.isSavingDraft),
    );

    return Semantics(
      // TODO(l10n): Replace with context.l10n when localization is added.
      label: 'Save for later button',
      hint: isSaving
          ? 'Saving video...'
          : 'Save video to drafts and camera roll',
      button: true,
      enabled: !isSaving,
      child: GestureDetector(
        onTap: isSaving ? null : () => _onSaveForLater(context, ref),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isSaving ? 0.6 : 1.0,
          child: Container(
            decoration: BoxDecoration(
              color: VineTheme.surfaceContainer,
              border: Border.all(color: const Color(0xFF0E2B21), width: 2),
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
                  // TODO(l10n): Replace with context.l10n when localization is added.
                  : Text(
                      'Save for Later',
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: VineTheme.primary,
                        height: 1.33,
                        letterSpacing: 0.15,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onSaveForLater(BuildContext context, WidgetRef ref) async {
    // Get the clips from clip manager
    final recordingClips = ref.read(clipManagerProvider).clips;
    if (recordingClips.isEmpty) {
      Log.warning(
        'No clips to save',
        name: '_SaveForLaterButton',
        category: LogCategory.video,
      );
      return;
    }

    var saveSuccess = true;
    String? gallerySaveMessage;

    try {
      // 1. Get video path and save to gallery FIRST (before draft save deletes
      // the original file)
      final videoPath = await recordingClips.first.video.safeFilePath();
      final gallerySaveService = ref.read(gallerySaveServiceProvider);
      final galleryResult = await gallerySaveService.saveVideoToGallery(
        videoPath,
      );

      gallerySaveMessage = switch (galleryResult) {
        GallerySaveSuccess() => 'Saved to camera roll',
        GallerySaveFailure(:final reason) => 'Camera roll: $reason',
      };

      // 2. Save each clip to the clip library for the Clips tab
      // (must happen before saveAsDraft which may delete files)
      final clipLibraryService = ref.read(clipLibraryServiceProvider);
      final sessionId = 'save_${DateTime.now().millisecondsSinceEpoch}';

      for (final clip in recordingClips) {
        final clipPath = await clip.video.safeFilePath();
        final savedClip = SavedClip(
          id: 'clip_${DateTime.now().microsecondsSinceEpoch}_${clip.id}',
          filePath: clipPath,
          thumbnailPath: clip.thumbnailPath,
          duration: clip.duration,
          createdAt: DateTime.now(),
          aspectRatio: clip.targetAspectRatio.name,
          sessionId: sessionId,
        );

        await clipLibraryService.saveClip(savedClip);

        Log.info(
          'Saved clip to library: ${savedClip.id}',
          name: '_SaveForLaterButton',
          category: LogCategory.video,
        );
      }

      // 3. Save as draft (with metadata) for the Drafts tab
      // Note: This may delete original files, so it must happen LAST
      final draftSuccess = await ref
          .read(videoEditorProvider.notifier)
          .saveAsDraft();
      if (!draftSuccess) {
        Log.warning(
          'Failed to save draft',
          name: '_SaveForLaterButton',
          category: LogCategory.video,
        );
      }
    } catch (e, stackTrace) {
      Log.error(
        'Failed to save: $e',
        name: '_SaveForLaterButton',
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
    String label;
    if (saveSuccess) {
      label = gallerySaveMessage != null
          ? 'Saved to library & camera roll!'
          : 'Saved to library!';
    } else {
      label = 'Failed to save';
    }

    scaffoldMessenger.showSnackBar(
      SnackBar(
        padding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        content: DivineSnackbarContainer(
          // TODO(l10n): Replace with context.l10n when localization is added.
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
      // Navigate first, then cleanup after the frame to avoid
      // "Bad state: No element" errors from widgets rebuilding
      // during the transition
      router.go(HomeScreenRouter.pathForIndex(0));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(videoPublishProvider.notifier).clearAll();
      });
    }
  }
}

/// Filled button to publish the video to the feed.
class _PostButton extends ConsumerWidget {
  /// Creates a post button.
  const _PostButton();

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
        // TODO(l10n): Replace with context.l10n when localization is added.
        label: 'Post button',
        hint: isValidToPost
            ? 'Publish video to feed'
            : 'Fill out the form to enable',
        button: true,
        enabled: isValidToPost,
        child: GestureDetector(
          onTap: isValidToPost
              ? () => ref.read(videoEditorProvider.notifier).postVideo(context)
              : null,
          child: Container(
            decoration: BoxDecoration(
              color: VineTheme.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              // TODO(l10n): Replace with context.l10n when localization is added.
              child: Text(
                'Post',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF002C1C),
                  height: 1.33,
                  letterSpacing: 0.15,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
