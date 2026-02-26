import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' show VideoEvent;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/aspect_ratio_extensions.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/platform_io.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_bottom_bar.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_preview_thumbnail.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_upload_status.dart';
import 'package:video_player/video_player.dart';

/// Full-screen preview of the recorded video with metadata overlay.
///
/// Displays the video in a hero animation transition and shows
/// how the post will appear with the entered title, description, and tags.
class VideoMetadataPreviewScreen extends ConsumerStatefulWidget {
  /// Creates a video preview screen for the given clip.
  const VideoMetadataPreviewScreen({required this.clip, super.key});

  /// The recording clip to preview.
  final RecordingClip clip;

  @override
  ConsumerState<VideoMetadataPreviewScreen> createState() =>
      _VideoMetadataPreviewScreenState();
}

class _VideoMetadataPreviewScreenState
    extends ConsumerState<VideoMetadataPreviewScreen> {
  /// Video player controller for the clip, null until initialized.
  VideoPlayerController? _controller;

  /// Whether the video player has completed initialization and is ready
  /// to play.
  bool _isInitialized = false;
  final _isPreviewReady = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    // Start video playback
    unawaited(_initializePlayer());

    ref.listenManual(
      videoPublishProvider.select((state) => state.publishState),
      (previous, next) {
        if (previous != next && _controller?.value.isPlaying == true) {
          _controller?.pause();
        }
      },
    );

    // Wait for hero animation to finish before showing overlay
    // Before displaying the overlay, we wait for the hero animation to finish.
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _isPreviewReady.value = true;
    });
  }

  /// Initializes the video player and starts playback.
  ///
  /// Checks if the video file exists, creates a [VideoPlayerController],
  /// initializes it, enables looping, and starts playback automatically.
  /// Updates [_isInitialized] when complete.
  Future<void> _initializePlayer() async {
    _controller = VideoPlayerController.file(
      File(await widget.clip.video.safeFilePath()),
    );
    if (mounted) await _controller!.initialize();
    if (mounted) await _controller!.setLooping(true);
    if (mounted) await _controller!.play();

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    unawaited(_controller?.dispose());
    _isPreviewReady.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000A06),
      body: Stack(
        children: [
          Column(
            spacing: 16,
            children: [
              // Video preview area with close button
              Expanded(
                child: Stack(
                  fit: .expand,
                  children: [
                    _VideoPreviewContent(
                      clip: widget.clip,
                      controller: _controller,
                      isInitialized: _isInitialized,
                      isPreviewReady: _isPreviewReady,
                    ),
                    const _CloseButton(),
                  ],
                ),
              ),
              // Post button at bottom
              const SafeArea(top: false, child: VideoMetadataBottomBar()),
            ],
          ),

          const VideoMetadataUploadStatus(),
        ],
      ),
    );
  }
}

/// Container widget that wraps the video player and overlay in a hero
/// transition.
class _VideoPreviewContent extends ConsumerWidget {
  /// Creates the video preview content wrapper.
  const _VideoPreviewContent({
    required this.clip,
    required this.controller,
    required this.isInitialized,
    required this.isPreviewReady,
  });

  final RecordingClip clip;
  final VideoPlayerController? controller;
  final bool isInitialized;
  final ValueNotifier<bool> isPreviewReady;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hero animation from metadata screen
    return Hero(
      tag: 'Video-metadata-clip-preview-video',
      // Use linear flight path instead of curved arc
      createRectTween: (begin, end) => RectTween(begin: begin, end: end),
      child: Stack(
        fit: .expand,
        children: [
          // Video playback layer
          _VideoPlayerWidget(
            clip: clip,
            controller: controller,
            isInitialized: isInitialized,
          ),
          // Metadata overlay layer
          _PreviewOverlay(isPreviewReady: isPreviewReady),
        ],
      ),
    );
  }
}

/// Video player widget with thumbnail fallback and smooth transitions.
class _VideoPlayerWidget extends StatelessWidget {
  /// Creates a video player widget.
  const _VideoPlayerWidget({
    required this.clip,
    required this.controller,
    required this.isInitialized,
  });

  final RecordingClip clip;
  final VideoPlayerController? controller;
  final bool isInitialized;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // For vertical videos (9:16), expand to fill the available space.
          // For other ratios (e.g., square), maintain their intrinsic aspect.
          final aspectRatio = clip.targetAspectRatio.useFullScreen
              ? constraints.biggest.aspectRatio
              : clip.targetAspectRatio.value;

          return AspectRatio(
            aspectRatio: aspectRatio,
            child: ClipRRect(
              borderRadius: .circular(16),
              child: Stack(
                fit: .expand,
                children: [
                  // Show thumbnail while video loads
                  if (clip.thumbnailPath != null)
                    VideoMetadataPreviewThumbnail(clip: clip),
                  // Smooth transition to video player
                  AnimatedSwitcher(
                    layoutBuilder: (currentChild, previousChildren) => Stack(
                      alignment: .center,
                      fit: .expand,
                      children: <Widget>[...previousChildren, ?currentChild],
                    ),
                    switchInCurve: Curves.easeInOut,
                    duration: const Duration(milliseconds: 120),
                    child: isInitialized && controller != null
                        ? FittedBox(
                            fit: .cover,
                            clipBehavior: .hardEdge,
                            child: SizedBox(
                              width: controller!.value.size.width,
                              height: controller!.value.size.height,
                              child: VideoPlayer(controller!),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Semi-transparent overlay showing how the video will appear with metadata.
class _PreviewOverlay extends ConsumerWidget {
  /// Creates a preview overlay.
  const _PreviewOverlay({required this.isPreviewReady});

  final ValueNotifier<bool> isPreviewReady;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get current metadata from editor
    final metadata = ref.watch(
      videoEditorProvider.select(
        (s) => (title: s.title, description: s.description, tags: s.tags),
      ),
    );

    // Get user's public key for preview
    final publicKey = ref.watch(
      nostrServiceProvider.select((s) => s.publicKey),
    );

    // Non-interactive overlay with reduced opacity
    return IgnorePointer(
      child: Opacity(
        opacity: 0.5,
        child: ValueListenableBuilder(
          valueListenable: isPreviewReady,
          builder: (_, isActive, _) {
            // Show overlay actions in preview mode
            return VideoOverlayActions(
              video: VideoEvent(
                id: 'id',
                pubkey: publicKey,
                timestamp: DateTime.now(),
                createdAt: DateTime.now().millisecondsSinceEpoch,
                content: metadata.title,
                hashtags: metadata.tags.toList(),
                originalLikes: 1,
                originalComments: 1,
                originalReposts: 1,
              ),
              isVisible: true,
              isActive: isActive,
              isPreviewMode: true,
            );
          },
        ),
      ),
    );
  }
}

/// Close button positioned at the top-left corner.
class _CloseButton extends StatelessWidget {
  /// Creates a close button.
  const _CloseButton();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 6,
      left: 16,
      child: SafeArea(
        child: Hero(
          tag: VideoEditorConstants.heroBackButtonId,
          child: DivineIconButton(
            type: .ghostSecondary,
            size: .small,
            // TODO(l10n): Replace with context.l10n when localization is added.
            semanticLabel: 'Close video recorder',
            icon: .x,
            onPressed: () => context.pop(),
          ),
        ),
      ),
    );
  }
}
