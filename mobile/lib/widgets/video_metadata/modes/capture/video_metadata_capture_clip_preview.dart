import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/screens/video_metadata/video_metadata_preview_screen.dart';
import 'package:openvine/widgets/video_editor/clip_editor/video_clip_editor_processing_overlay.dart';
import 'package:openvine/widgets/video_metadata/modes/capture/video_metadata_capture_preview_thumbnail.dart';

/// Video clip preview widget with thumbnail and play button.
///
/// Displays a thumbnail of the recorded video and allows opening
/// the full-screen preview when tapped. Shows processing overlay
/// while the video is being rendered.
class VideoMetadataCaptureClipPreview extends ConsumerWidget {
  /// Creates a video metadata clip preview.
  const VideoMetadataCaptureClipPreview({super.key});

  /// Opens the full-screen video preview with a fade transition.
  Future<void> _openPreview(BuildContext context, DivineVideoClip clip) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Navigator.push(
      context,
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => VideoMetadataPreviewScreen(clip: clip),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get the first (and only) clip from manager
    final clips = ref.watch(clipManagerProvider).clips;
    if (clips.isEmpty) return const SizedBox.shrink();
    final clip = clips.first;
    // Watch processing state and rendered clip
    final state = ref.watch(
      videoEditorProvider.select(
        (s) => (
          isProcessing: s.isProcessing,
          finalRenderedClip: s.finalRenderedClip,
        ),
      ),
    );
    final isReady = state.finalRenderedClip != null;

    return Center(
      child: SizedBox(
        height: 200,
        // Hero animation to preview screen
        child: Hero(
          tag: VideoEditorConstants.heroMetaPreviewId,
          // Use linear flight path instead of curved arc
          createRectTween: (begin, end) => RectTween(begin: begin, end: end),
          child: AspectRatio(
            aspectRatio: clip.targetAspectRatio.value,
            child: ClipRRect(
              borderRadius: .circular(16),
              child: Semantics(
                button: true,
                enabled: isReady,
                label: context.l10n.videoMetadataOpenPreviewSemanticLabel,
                child: GestureDetector(
                  onTap: isReady
                      ? () => _openPreview(context, state.finalRenderedClip!)
                      : null,
                  child: Stack(
                    children: [
                      // Video thumbnail or placeholder
                      AnimatedSwitcher(
                        layoutBuilder: (currentChild, previousChildren) =>
                            Stack(
                              fit: .expand,
                              alignment: .center,
                              children: [...previousChildren, ?currentChild],
                            ),

                        duration: const Duration(milliseconds: 150),
                        child: clip.thumbnailPath != null
                            ? // Video thumbnail image
                              VideoMetadataCapturePreviewThumbnail(clip: clip)
                            : // Fallback placeholder
                              const ColoredBox(
                                color: VineTheme.onSurfaceMuted,
                                child: DivineIcon(
                                  icon: .playCircle,
                                  size: 64,
                                  color: VineTheme.whiteText,
                                ),
                              ),
                      ),
                      // Processing overlay with play button
                      VideoClipEditorProcessingOverlay(
                        clip: clip,
                        isProcessing:
                            state.finalRenderedClip == null ||
                            state.isProcessing,
                        inactivePlaceholder: Center(
                          child: DivineIconButton(
                            icon: .play,
                            type: .ghost,
                            size: .small,
                            onPressed: () =>
                                _openPreview(context, state.finalRenderedClip!),
                          ),
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
    );
  }
}
