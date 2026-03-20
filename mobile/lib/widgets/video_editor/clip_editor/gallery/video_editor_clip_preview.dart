// ABOUTME: Displays individual video clip with preview and playback controls
// ABOUTME: Manages video player lifecycle for the currently selected clip

import 'dart:async';
import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/widgets/video_editor/clip_editor/video_clip_editor_processing_overlay.dart';
import 'package:video_player/video_player.dart';

/// Displays a video clip preview with thumbnail and video playback.
///
/// When [isCurrentClip] is true:
/// - Initializes video player for playback
/// - Responds to play/pause state changes
/// - Handles split position seeking in edit mode
/// - Shows live video feed when playing
///
/// When not current:
/// - Shows thumbnail or placeholder icon
/// - Disposes video player to free resources
class VideoEditorClipPreview extends StatefulWidget {
  /// Creates a video clip preview widget.
  const VideoEditorClipPreview({
    required this.clip,
    super.key,
    this.isCurrentClip = false,
    this.isReordering = false,
    this.onTap,
    this.onLongPress,
  });

  /// The clip to display.
  final DivineVideoClip clip;

  /// Whether this is the currently selected/playing clip.
  final bool isCurrentClip;

  /// Whether clip reordering mode is active.
  final bool isReordering;

  /// Callback when the clip is tapped.
  final VoidCallback? onTap;

  /// Callback when the clip is long-pressed (for reordering).
  final VoidCallback? onLongPress;

  @override
  State<VideoEditorClipPreview> createState() => _VideoClipPreviewState();
}

class _VideoClipPreviewState extends State<VideoEditorClipPreview> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();

    // Only initialize if this is the current clip
    if (widget.isCurrentClip) {
      unawaited(_initializeVideoPlayer());
    }
  }

  Future<void> _handlePlaybackStateChange(bool isPlaying) async {
    if (_controller == null || !_isInitialized || !mounted) {
      return;
    }

    final shouldPlay = widget.isCurrentClip && isPlaying;

    await _videoPlayerListener();

    if (shouldPlay && !_controller!.value.isPlaying) {
      await _controller!.play();
    } else if (!shouldPlay && _controller!.value.isPlaying) {
      await _controller!.pause();
    }
  }

  Future<void> _initializeVideoPlayer() async {
    final videoPath = await widget.clip.video.safeFilePath();

    _controller = VideoPlayerController.file(File(videoPath));
    await _controller?.initialize();
    // Seek to thumbnail timestamp for seamless transition from thumbnail to video
    final thumbnailTimestamp = widget.clip.thumbnailTimestamp;
    if (mounted && thumbnailTimestamp > .zero) {
      await _controller?.seekTo(thumbnailTimestamp);
    }
    if (mounted) await _controller?.setLooping(true);

    // Add listener to detect when video ends
    _controller?.addListener(_videoPlayerListener);

    if (mounted) {
      context.read<ClipEditorBloc>().add(
        const ClipEditorPlayerReadyChanged(isReady: true),
      );
      setState(() {
        _isInitialized = true;
      });
    }
  }

  Future<void> _videoPlayerListener() async {
    if (_controller == null || !mounted || !widget.isCurrentClip) return;

    final bloc = context.read<ClipEditorBloc>();
    final blocState = bloc.state;

    final isEditing = blocState.isEditing;
    final isPlaying = blocState.isPlaying;
    final splitPosition = blocState.splitPosition;

    // Check if video has ended
    final position = _controller!.value.position;
    final targetDuration = isEditing
        ? splitPosition
        : _controller!.value.duration;

    bloc.add(
      ClipEditorPositionUpdated(
        clipId: widget.clip.id,
        position: _controller!.value.position,
      ),
    );

    // Track when video starts playing (to hide thumbnail)
    if (!blocState.hasPlayedOnce && (_controller?.value.isPlaying ?? false)) {
      bloc.add(const ClipEditorFirstPlaybackStarted());
    }

    if (isEditing &&
        widget.isCurrentClip &&
        position > targetDuration &&
        targetDuration > Duration.zero) {
      await _controller?.seekTo(.zero);
      if (isPlaying) {
        await _controller?.play();
      } else {
        await _controller?.pause();
      }
    }
  }

  @override
  void didUpdateWidget(VideoEditorClipPreview oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Initialize video player when becoming current clip
    if (!oldWidget.isCurrentClip &&
        widget.isCurrentClip &&
        _controller == null) {
      unawaited(_initializeVideoPlayer());
    }

    // Dispose video player when no longer current clip
    if (oldWidget.isCurrentClip && !widget.isCurrentClip) {
      context.read<ClipEditorBloc>().add(
        const ClipEditorPlayerReadyChanged(isReady: false),
      );
      unawaited(_disposeController());
      _isInitialized = false;
    }

    // Reinitialize when the underlying video file changed (e.g. after a
    // split finishes rendering) while this is still the current clip.
    if (widget.isCurrentClip && oldWidget.clip.video != widget.clip.video) {
      unawaited(_reinitializePlayer());
    }

    // Handle playback when isCurrentClip changes
    if (oldWidget.isCurrentClip != widget.isCurrentClip) {
      final isPlaying = context.read<ClipEditorBloc>().state.isPlaying;
      _handlePlaybackStateChange(isPlaying);
    }
  }

  Future<void> _reinitializePlayer() async {
    context.read<ClipEditorBloc>().add(
      const ClipEditorPlayerReadyChanged(isReady: false),
    );
    await _disposeController();
    _isInitialized = false;
    if (mounted) {
      await _initializeVideoPlayer();
    }
  }

  Future<void> _disposeController() async {
    _controller?.removeListener(_videoPlayerListener);
    await _controller?.dispose();
    _controller = null;
  }

  @override
  void dispose() {
    unawaited(_disposeController());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Only watch delete zone state for current clip to avoid unnecessary
    // rebuilds
    final isOverDeleteZone =
        widget.isCurrentClip &&
        context.select<ClipEditorBloc, bool>(
          (bloc) => bloc.state.isOverDeleteZone,
        );

    return MultiBlocListener(
      listeners: [
        BlocListener<ClipEditorBloc, ClipEditorState>(
          listenWhen: (prev, curr) => prev.isPlaying != curr.isPlaying,
          listener: (_, state) => _handlePlaybackStateChange(state.isPlaying),
        ),
        BlocListener<ClipEditorBloc, ClipEditorState>(
          listenWhen: (prev, curr) =>
              curr.isEditing &&
              (prev.splitPosition != curr.splitPosition ||
                  prev.isEditing != curr.isEditing),
          listener: (_, state) => _controller?.seekTo(state.splitPosition),
        ),
        BlocListener<ClipEditorBloc, ClipEditorState>(
          listenWhen: (prev, curr) => prev.isEditing != curr.isEditing,
          listener: (_, state) => _controller?.setLooping(!state.isEditing),
        ),
      ],
      child: Center(
        child: AspectRatio(
          aspectRatio: widget.clip.targetAspectRatio.value,
          child: GestureDetector(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: .circular(16),
                border: .all(
                  color: isOverDeleteZone
                      // Red when over delete zone
                      ? VineTheme.error
                      : widget.isReordering
                      // Yellow when reordering
                      ? VineTheme.accentYellow
                      : VineTheme.transparent, // Transparent otherwise
                  width: 6,
                  strokeAlign: BorderSide.strokeAlignOutside,
                ),
              ),
              child: ClipRRect(
                borderRadius: .circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Very short clips (< 300ms) may render as a black
                    // frame in the video player, but they can still be
                    // merged into the final video. Show the thumbnail
                    // permanently so the user sees a meaningful preview.
                    if (widget.clip.duration <
                        const Duration(milliseconds: 300))
                      _ThumbnailVisibility(
                        enforceVisible: true,
                        isCurrentClip: widget.isCurrentClip,
                        clip: widget.clip,
                      ),

                    // Show video player ONLY when this is the current clip
                    if (_isInitialized &&
                        _controller != null &&
                        widget.isCurrentClip)
                      FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _controller!.value.size.width,
                          height: _controller!.value.size.height,
                          child: IgnorePointer(
                            child: VideoPlayer(_controller!),
                          ),
                        ),
                      ),

                    _ThumbnailVisibility(
                      isCurrentClip: widget.isCurrentClip,
                      clip: widget.clip,
                    ),

                    VideoClipEditorProcessingOverlay(
                      clip: widget.clip,
                      isCurrentClip: widget.isCurrentClip,
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

/// Controls thumbnail visibility based on playback and editing state.
///
/// Hides the thumbnail when:
/// - The video has played at least once, OR
/// - The clip is in edit mode (split position seeking shows the live frame)
///
/// Uses AnimatedOpacity for smooth bidirectional fade transitions.
class _ThumbnailVisibility extends StatelessWidget {
  const _ThumbnailVisibility({
    required this.isCurrentClip,
    required this.clip,
    this.enforceVisible = false,
  });

  final bool isCurrentClip;
  final bool enforceVisible;
  final DivineVideoClip clip;

  @override
  Widget build(BuildContext context) {
    final shouldHide =
        !enforceVisible &&
        isCurrentClip &&
        context.select<ClipEditorBloc, bool>(
          (bloc) => bloc.state.hasPlayedOnce || bloc.state.isEditing,
        );

    return IgnorePointer(
      ignoring: shouldHide,
      child: AnimatedOpacity(
        opacity: shouldHide ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: _ClipThumbnail(clip: clip),
      ),
    );
  }
}

/// Displays thumbnail for a clip with animated transitions.
///
/// Shows the thumbnail image when available, otherwise displays a placeholder.
/// Uses AnimatedSwitcher for smooth transitions when thumbnail changes
/// (e.g., after splitting a clip).
class _ClipThumbnail extends StatelessWidget {
  const _ClipThumbnail({required this.clip});

  final DivineVideoClip clip;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      layoutBuilder: (current, previous) => Stack(
        alignment: .center,
        fit: .expand,
        children: <Widget>[...previous, ?current],
      ),
      child: clip.thumbnailPath == null
          ? const ColoredBox(
              color: VineTheme.lightText,
              child: DivineIcon(
                icon: .playCircle,
                size: 64,
                color: VineTheme.whiteText,
              ),
            )
          : Image.file(
              File(clip.thumbnailPath!),
              key: ValueKey('${clip.id}-${clip.thumbnailPath}'),
              fit: .cover,
            ),
    );
  }
}
