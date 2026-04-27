import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' show VideoEvent;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/screens/feed/feed_mode_switch.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:openvine/widgets/video_metadata/modes/capture/video_metadata_capture_bottom_bar.dart';
import 'package:openvine/widgets/video_metadata/modes/capture/video_metadata_capture_preview_thumbnail.dart';

/// Full-screen preview of the recorded video with metadata overlay.
///
/// Displays the video in a hero animation transition and shows
/// how the post will appear with the entered title, description, and tags.
class VideoMetadataPreviewScreen extends ConsumerStatefulWidget {
  /// Creates a video preview screen for the given clip.
  const VideoMetadataPreviewScreen({
    required this.clip,
    this.previewOnly = false,
    super.key,
  });

  /// The recording clip to preview.
  final DivineVideoClip clip;

  /// When `true`, hides the bottom bar and metadata overlay.
  ///
  /// Used when showing a read-only preview outside the editor flow
  /// (e.g. from the upload failure sheet).
  final bool previewOnly;

  @override
  ConsumerState<VideoMetadataPreviewScreen> createState() =>
      _VideoMetadataPreviewScreenState();
}

class _VideoMetadataPreviewScreenState
    extends ConsumerState<VideoMetadataPreviewScreen> {
  /// Video player controller for the clip, null until initialized.
  DivineVideoPlayerController? _controller;

  /// Whether the video player has completed initialization and is ready
  /// to play.
  final _isPreviewReady = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    // Start video playback
    unawaited(_initializePlayer());

    ref.listenManual(
      videoPublishProvider.select((state) => state.publishState),
      (previous, next) {
        if (previous != next && _controller?.state.isPlaying == true) {
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
  /// Creates a [DivineVideoPlayerController], initializes it, enables
  /// looping, and starts playback automatically.
  Future<void> _initializePlayer() async {
    _controller = DivineVideoPlayerController(useTexture: true);
    if (mounted) await _controller!.initialize();
    if (mounted) {
      await _controller!.setSource(
        VideoClip.file(await widget.clip.video.safeFilePath()),
      );
    }
    if (mounted) await _controller!.setLooping(looping: true);
    if (mounted) await _controller!.play();
    // Rebuild so DivineVideoPlayer receives the now-initialized controller.
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    unawaited(_controller?.dispose());
    _isPreviewReady.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: VideoEditorConstants.uiOverlayStyle,
      child: Scaffold(
        backgroundColor: VineTheme.surfaceContainerHigh,
        body: Column(
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
                  ),
                  if (!widget.previewOnly)
                    _PreviewOverlay(isPreviewReady: _isPreviewReady),
                  const _CloseButton(),
                ],
              ),
            ),
            // Post button at bottom
            if (!widget.previewOnly)
              const SafeArea(
                top: false,
                child: VideoMetadataCaptureBottomBar(),
              ),
          ],
        ),
      ),
    );
  }
}

/// Container widget that wraps the video player in a hero transition.
class _VideoPreviewContent extends ConsumerWidget {
  /// Creates the video preview content wrapper.
  const _VideoPreviewContent({
    required this.clip,
    required this.controller,
  });

  final DivineVideoClip clip;
  final DivineVideoPlayerController? controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aspectRatio = clip.targetAspectRatio.value;

    // Hero animation from metadata screen
    return Hero(
      tag: VideoEditorConstants.heroMetaPreviewId,
      // Use linear flight path instead of curved arc
      createRectTween: (begin, end) => RectTween(begin: begin, end: end),
      child: Center(
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: DivineVideoPlayer(
              controller: controller,
              placeholder: VideoMetadataCapturePreviewThumbnail(clip: clip),
            ),
          ),
        ),
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

    // Non-interactive overlay with reduced opacity.
    // Lives in the outer full-screen Stack so it always renders at
    // phone-screen proportions, independent of the video's aspect ratio.
    return IgnorePointer(
      child: Opacity(
        opacity: 0.5,
        child: Material(
          type: .transparency,
          child: ValueListenableBuilder(
            valueListenable: isPreviewReady,
            builder: (_, isActive, _) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  const FeedModeSwitch(isPreviewMode: true),
                  VideoOverlayActions(
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
                  ),
                ],
              );
            },
          ),
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
    return PositionedDirectional(
      top: 6,
      start: 16,
      child: SafeArea(
        child: Hero(
          tag: VideoEditorConstants.heroBackButtonId,
          child: DivineIconButton(
            icon: .x,
            type: .ghostSecondary,
            size: .small,
            semanticLabel: context.l10n.videoMetadataClosePreviewSemanticLabel,
            onPressed: () => context.pop(),
          ),
        ),
      ),
    );
  }
}
