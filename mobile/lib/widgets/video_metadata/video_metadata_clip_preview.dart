import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/platform_io.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/screens/video_metadata/video_metadata_preview_screen.dart';
import 'package:openvine/widgets/video_editor/video_editor_clip_processing_overlay.dart';

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
    final clip = ref.watch(clipManagerProvider).clips.first;
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
      padding: const .symmetric(vertical: 32),
      child: Center(
        child: SizedBox(
          height: 200,
          // Hero animation to preview screen
          child: Hero(
            tag: 'Video-metadata-clip-preview-video',
            // Use linear flight path instead of curved arc
            createRectTween: (begin, end) => RectTween(begin: begin, end: end),
            child: AspectRatio(
              aspectRatio: clip.aspectRatio.value,
              child: ClipRRect(
                borderRadius: .circular(16),
                child: Stack(
                  children: [
                    // Video thumbnail or placeholder
                    AnimatedSwitcher(
                      layoutBuilder: (currentChild, previousChildren) => Stack(
                        fit: .expand,
                        alignment: .center,
                        children: [...previousChildren, ?currentChild],
                      ),
                      duration: const Duration(milliseconds: 150),
                      child: clip.thumbnailPath != null
                          ? // Video thumbnail image
                            Image.file(File(clip.thumbnailPath!), fit: .cover)
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
                    VideoEditorClipProcessingOverlay(
                      clip: clip,
                      isProcessing: state.isProcessing,
                      inactivePlaceholder: _PlayIndicator(
                        clip: clip,
                        onTap: state.finalRenderedClip != null
                            ? () => _openPreview(
                                context,
                                state.finalRenderedClip!,
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Play button indicator overlay for opening the preview screen.
class _PlayIndicator extends StatelessWidget {
  /// Creates a play indicator.
  const _PlayIndicator({required this.clip, required this.onTap});

  final RecordingClip clip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        button: true,
        // TODO(l10n): Replace with context.l10n when localization is added.
        label: 'Open post preview screen',
        child: GestureDetector(
          onTap: onTap,
          // Semi-transparent dark button with play icon
          child: Container(
            padding: const .all(12),
            decoration: ShapeDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              shape: RoundedRectangleBorder(borderRadius: .circular(20)),
            ),
            child: SizedBox(
              width: 24,
              height: 24,
              child: SvgPicture.asset(
                'assets/icon/play.svg',
                colorFilter: const .mode(Colors.white, .srcIn),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
