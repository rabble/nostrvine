// ABOUTME: Displays individual video clip with preview and playback controls
// ABOUTME: Manages video player lifecycle for the currently selected clip

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/platform_io.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_clip_editor/video_clip_editor_processing_overlay.dart';
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
class VideoEditorClipPreview extends ConsumerStatefulWidget {
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
  final RecordingClip clip;

  /// Whether this is the currently selected/playing clip.
  final bool isCurrentClip;

  /// Whether clip reordering mode is active.
  final bool isReordering;

  /// Callback when the clip is tapped.
  final VoidCallback? onTap;

  /// Callback when the clip is long-pressed (for reordering).
  final VoidCallback? onLongPress;

  @override
  ConsumerState<VideoEditorClipPreview> createState() =>
      _VideoClipPreviewState();
}

class _VideoClipPreviewState extends ConsumerState<VideoEditorClipPreview> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hadPlayed = false;

  @override
  void initState() {
    super.initState();

    // Only initialize if this is the current clip
    if (widget.isCurrentClip) {
      unawaited(_initializeVideoPlayer());
      _setupListeners();
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

  void _setupListeners() {
    ref
      // Listen to play/pause state changes
      ..listenManual(videoEditorProvider.select((state) => state.isPlaying), (
        previous,
        next,
      ) {
        _handlePlaybackStateChange(next);
      })
      // Listen to trim-position changes
      ..listenManual(
        videoEditorProvider.select(
          (state) =>
              (splitPosition: state.splitPosition, isEditing: state.isEditing),
        ),
        (previous, next) {
          if (!next.isEditing) return;
          _controller?.seekTo(next.splitPosition);
        },
      )
      // Listen to trim-position changes
      ..listenManual(videoEditorProvider.select((state) => state.isEditing), (
        previous,
        next,
      ) {
        if (previous == next) return;

        _controller?.setLooping(!next);
      });
  }

  Future<void> _initializeVideoPlayer() async {
    final videoPath = await widget.clip.video.safeFilePath();

    _controller = VideoPlayerController.file(File(videoPath));
    await _controller?.initialize();
    if (mounted) await _controller?.setLooping(true);

    // Add listener to detect when video ends
    _controller?.addListener(_videoPlayerListener);

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  Future<void> _videoPlayerListener() async {
    if (_controller == null || !mounted) return;

    final isEditing = ref.read(videoEditorProvider).isEditing;
    final isPlaying = ref.read(videoEditorProvider).isPlaying;
    final splitPosition = ref.read(videoEditorProvider).splitPosition;
    final notifier = ref.read(videoEditorProvider.notifier);

    // Check if video has ended
    final position = _controller!.value.position;
    final targetDuration = isEditing
        ? splitPosition
        : _controller!.value.duration;

    notifier.updatePosition(_controller!.value.position);

    if (!_hadPlayed) {
      _hadPlayed = _controller?.value.isPlaying ?? false;
      setState(() {});
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
      unawaited(_disposeController());
      _hadPlayed = false;
      _isInitialized = false;
    }

    // Handle playback when isCurrentClip changes
    if (oldWidget.isCurrentClip != widget.isCurrentClip) {
      final isPlaying = ref.read(videoEditorProvider).isPlaying;
      _handlePlaybackStateChange(isPlaying);
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
        ref.watch(videoEditorProvider.select((s) => s.isOverDeleteZone));

    return Center(
      child: AspectRatio(
        aspectRatio: widget.clip.aspectRatio.value,
        child: GestureDetector(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: .circular(16),
              border: .all(
                color: isOverDeleteZone
                    ? const Color(0xFFF44336) // Red when over delete zone
                    : widget.isReordering
                    ? const Color(0xFFEBDE3B) // Yellow when reordering
                    : const Color(0x00000000), // Transparent otherwise
                width: 6,
                strokeAlign: BorderSide.strokeAlignOutside,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x51000000),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
                BoxShadow(
                  color: Color(0x28000000),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                  spreadRadius: 3,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: .circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Show video player ONLY when this is the current clip
                  if (_isInitialized &&
                      _controller != null &&
                      widget.isCurrentClip)
                    FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller!.value.size.width,
                        height: _controller!.value.size.height,
                        child: IgnorePointer(child: VideoPlayer(_controller!)),
                      ),
                    ),

                  AnimatedSwitcher(
                    layoutBuilder: (currentChild, previousChildren) => Stack(
                      fit: .expand,
                      alignment: .center,
                      children: [...previousChildren, ?currentChild],
                    ),
                    duration: const Duration(milliseconds: 150),
                    child:
                        (_controller != null && _controller!.value.isPlaying) ||
                            _hadPlayed
                        ? const SizedBox.shrink()
                        : _ClipThumbnail(clip: widget.clip),
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

  final RecordingClip clip;

  @override
  Widget build(BuildContext context) {
    if (clip.thumbnailPath == null) {
      return Container(
        color: Colors.grey.shade400,
        child: const Icon(
          Icons.play_circle_outline,
          size: 64,
          color: Colors.white,
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      layoutBuilder: (current, previous) => Stack(
        alignment: .center,
        fit: .expand,
        children: <Widget>[...previous, ?current],
      ),
      child: Image.file(
        File(clip.thumbnailPath!),
        key: ValueKey('${clip.id}-${clip.thumbnailPath}'),
        fit: .cover,
      ),
    );
  }
}
