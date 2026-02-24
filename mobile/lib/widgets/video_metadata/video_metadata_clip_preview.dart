import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/screens/video_metadata/video_metadata_preview_screen.dart';
import 'package:openvine/widgets/video_clip_editor/video_clip_editor_processing_overlay.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_preview_thumbnail.dart';

/// Video clip preview widget with thumbnail and play button.
///
/// Displays a thumbnail of the recorded video and allows opening
/// the full-screen preview when tapped. Shows processing overlay
/// while the video is being rendered.
class VideoMetadataClipPreview extends ConsumerWidget {
  /// Creates a video metadata clip preview.
  const VideoMetadataClipPreview({super.key});

  /// Opens the full-screen video preview with a fade transition.
  Future<void> _openPreview(BuildContext context, RecordingClip clip) async {
    await Navigator.push(
      context,
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => VideoMetadataPreviewScreen(clip: clip),
        transitionDuration: const Duration(milliseconds: 300),
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

    return Padding(
      padding: const .symmetric(vertical: 18),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFF205040)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x52000000),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: SizedBox(
            height: 200,
            // Hero animation to preview screen
            child: Hero(
              tag: 'Video-metadata-clip-preview-video',
              // Use linear flight path instead of curved arc
              createRectTween: (begin, end) =>
                  RectTween(begin: begin, end: end),
              child: AspectRatio(
                aspectRatio: clip.targetAspectRatio.value,
                child: ClipRRect(
                  borderRadius: .circular(16),
                  child: Semantics(
                    button: true,
                    // TODO(l10n): Replace with context.l10n when localization
                    // is added.
                    label: 'Open post preview screen',
                    child: GestureDetector(
                      onTap: state.finalRenderedClip != null
                          ? () =>
                                _openPreview(context, state.finalRenderedClip!)
                          : null,
                      child: Stack(
                        children: [
                          // Video thumbnail or placeholder
                          AnimatedSwitcher(
                            layoutBuilder: (currentChild, previousChildren) =>
                                Stack(
                                  fit: .expand,
                                  alignment: .center,
                                  children: [
                                    ...previousChildren,
                                    ?currentChild,
                                  ],
                                ),
                            duration: const Duration(milliseconds: 150),
                            child: clip.thumbnailPath != null
                                ? // Video thumbnail image
                                  VideoMetadataPreviewThumbnail(clip: clip)
                                : // Fallback placeholder
                                  ColoredBox(
                                    color: Colors.grey.shade400,
                                    child: const Icon(
                                      Icons.play_circle_outline,
                                      size: 64,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                          // Processing overlay with play button
                          VideoClipEditorProcessingOverlay(
                            clip: clip,
                            isProcessing: state.isProcessing,
                            inactivePlaceholder: Center(
                              child: DivineIconButton(
                                icon: .play,
                                type: .ghost,
                                size: .small,
                                onPressed: () => _openPreview(
                                  context,
                                  state.finalRenderedClip!,
                                ),
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
        ),
      ),
    );
  }
}
