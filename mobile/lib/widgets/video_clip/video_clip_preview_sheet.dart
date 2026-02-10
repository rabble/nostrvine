// ABOUTME: Bottom sheet for previewing video clips with playback controls
// ABOUTME: Shows looping video player with clip info and delete action

import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/saved_clip.dart';
import 'package:video_player/video_player.dart';

/// Preview sheet for playing a video clip in a modal bottom sheet.
///
/// Displays a looping video player with the clip's duration information
/// and a delete button. The video automatically starts playing when opened.
class VideoClipPreviewSheet extends StatefulWidget {
  const VideoClipPreviewSheet({super.key, required this.clip});

  /// The clip to preview, containing file path, duration, and other metadata.
  final SavedClip clip;

  @override
  State<VideoClipPreviewSheet> createState() => _VideoClipPreviewSheetState();
}

/// State for [VideoClipPreviewSheet].
///
/// Manages video player initialization and playback lifecycle.
class _VideoClipPreviewSheetState extends State<VideoClipPreviewSheet> {
  /// Video player controller for the clip, null until initialized.
  VideoPlayerController? _controller;

  /// Whether the video player has completed initialization and is ready to play.
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  /// Initializes the video player and starts playback.
  ///
  /// Checks if the video file exists, creates a [VideoPlayerController],
  /// initializes it, enables looping, and starts playback automatically.
  /// Updates [_isInitialized] when complete.
  Future<void> _initializePlayer() async {
    final file = File(widget.clip.filePath);
    if (!file.existsSync()) {
      context.pop();
      return;
    }

    if (mounted) _controller = VideoPlayerController.file(file);
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
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.pop(),
      behavior: .translucent,
      child: ColoredBox(
        color: Colors.black54,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: .all(36),
              child: AspectRatio(
                aspectRatio: widget.clip.aspectRatioValue,
                child: ClipRRect(
                  borderRadius: .circular(16),
                  child: Stack(
                    fit: .expand,
                    children: [
                      // Thumbnail
                      if (widget.clip.thumbnailPath != null)
                        Hero(
                          tag: 'Video-Clip-Preview-${widget.clip.id}',
                          child: Image.file(
                            File(widget.clip.thumbnailPath!),
                            fit: .cover,
                          ),
                        ),

                      // Progress-indicator
                      Center(
                        child: CircularProgressIndicator(
                          color: VineTheme.vineGreen,
                        ),
                      ),

                      // Video-player
                      AnimatedSwitcher(
                        layoutBuilder: (currentChild, previousChildren) =>
                            Stack(
                              alignment: .center,
                              fit: .expand,
                              children: <Widget>[
                                ...previousChildren,
                                ?currentChild,
                              ],
                            ),
                        switchInCurve: Curves.easeInOut,
                        duration: Duration(milliseconds: 120),
                        child: _isInitialized && _controller != null
                            ? FittedBox(
                                fit: .cover,
                                clipBehavior: .hardEdge,
                                child: SizedBox(
                                  width: _controller!.value.size.width,
                                  height: _controller!.value.size.height,
                                  child: VideoPlayer(_controller!),
                                ),
                              )
                            : SizedBox.shrink(),
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
