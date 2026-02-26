// ABOUTME: Bottom sheet for previewing video clips with playback controls
// ABOUTME: Shows looping video player with clip info, save-to-gallery,
// ABOUTME: and dismiss

import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/saved_clip.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:video_player/video_player.dart';

/// Preview sheet for playing a video clip in a modal bottom sheet.
///
/// Displays a looping video player with the clip's duration information
/// and a delete button. The video automatically starts playing when opened.
class VideoClipPreviewSheet extends ConsumerStatefulWidget {
  const VideoClipPreviewSheet({required this.clip, super.key});

  /// The clip to preview, containing file path, duration, and other metadata.
  final SavedClip clip;

  @override
  ConsumerState<VideoClipPreviewSheet> createState() =>
      _VideoClipPreviewSheetState();
}

/// State for [VideoClipPreviewSheet].
///
/// Manages video player initialization and playback lifecycle.
class _VideoClipPreviewSheetState extends ConsumerState<VideoClipPreviewSheet> {
  /// Video player controller for the clip, null until initialized.
  VideoPlayerController? _controller;

  /// Whether the video player has completed initialization and is ready to play.
  bool _isInitialized = false;

  /// Whether a gallery save operation is currently in progress.
  bool _isSaving = false;

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

  /// Saves the current clip to the device gallery/camera roll.
  ///
  /// Shows a snackbar with the result and handles permission denied.
  Future<void> _saveToGallery() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final gallerySaveService = ref.read(gallerySaveServiceProvider);
      final video = EditorVideo.file(widget.clip.filePath);
      final result = await gallerySaveService.saveVideoToGallery(video);

      if (!mounted) return;

      final destination = GallerySaveService.destinationName;
      final message = switch (result) {
        GallerySaveSuccess() => 'Clip saved to $destination',
        GallerySavePermissionDenied() => '$destination permission denied',
        GallerySaveFailure(:final reason) => 'Failed to save clip: $reason',
      };

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          content: DivineSnackbarContainer(
            label: message,
            error: result is! GallerySaveSuccess,
          ),
        ),
      );
    } catch (e, s) {
      UnifiedLogger.error(
        'Failed to save clip to gallery',
        error: e,
        stackTrace: s,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            content: DivineSnackbarContainer(
              label: 'Failed to save clip',
              error: true,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
              padding: const .all(36),
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
                      const Center(
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
                        duration: const Duration(milliseconds: 120),
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
                            : const SizedBox.shrink(),
                      ),

                      // Save to gallery button
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: _SaveToGalleryButton(
                          isSaving: _isSaving,
                          onPressed: _saveToGallery,
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

/// Button to save a clip to the device gallery/camera roll.
///
/// Shows a loading indicator while saving, and a download icon otherwise.
/// Absorbs taps on the surrounding [GestureDetector] to prevent dismissal.
class _SaveToGalleryButton extends StatelessWidget {
  const _SaveToGalleryButton({required this.isSaving, required this.onPressed});

  /// Whether a save operation is currently in progress.
  final bool isSaving;

  /// Called when the button is tapped.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Absorb taps so the preview sheet doesn't dismiss.
      onTap: () {},
      child: IconButton(
        onPressed: isSaving ? null : onPressed,
        style: IconButton.styleFrom(
          backgroundColor: VineTheme.iconButtonBackground,
        ),
        tooltip: 'Save to ${GallerySaveService.destinationName}',
        icon: isSaving
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: VineTheme.whiteText,
                ),
              )
            : const Icon(Icons.download_rounded, color: VineTheme.whiteText),
      ),
    );
  }
}
