// ABOUTME: Bottom sheet for previewing video clips with playback controls
// ABOUTME: Shows looping video player with clip info and delete action

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:openvine/models/saved_clip.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:video_player/video_player.dart';

/// Preview sheet for playing a video clip in a modal bottom sheet.
///
/// Displays a looping video player with the clip's duration information
/// and a delete button. The video automatically starts playing when opened.
class VideoClipPreviewSheet extends StatefulWidget {
  const VideoClipPreviewSheet({
    super.key,
    required this.clip,
    required this.onDelete,
  });

  /// The clip to preview, containing file path, duration, and other metadata.
  final SavedClip clip;

  /// Callback invoked when the delete button is pressed.
  final VoidCallback onDelete;

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
    if (!await file.exists()) {
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
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: .vertical(top: .circular(16)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const .symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: .circular(2),
            ),
          ),
          // Video preview
          Expanded(
            child: _isInitialized && _controller != null
                ? Center(
                    child: AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    ),
                  )
                : const Center(
                    child: CircularProgressIndicator(
                      color: VineTheme.vineGreen,
                    ),
                  ),
          ),
          // Info and actions
          Container(
            padding: const .all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.clip.durationInSeconds.toStringAsFixed(1)}s clip',
                        style: const TextStyle(
                          color: VineTheme.whiteText,
                          fontSize: 16,
                          fontWeight: .bold,
                        ),
                      ),
                      Text(
                        widget.clip.displayDuration,
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: widget.onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
