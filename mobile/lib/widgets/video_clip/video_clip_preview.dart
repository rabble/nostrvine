// ABOUTME: Bottom sheet for previewing video clips with playback controls
// ABOUTME: Shows looping video player with clip info, save-to-gallery,
// ABOUTME: and dismiss

import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:video_player/video_player.dart';

class VideoClipPreview extends ConsumerStatefulWidget {
  const VideoClipPreview({
    required this.clip,
    this.onDelete,
    super.key,
  });

  /// The clip to preview, containing file path, duration, and other metadata.
  final DivineVideoClip clip;

  /// Called when the delete button is tapped. If null, delete button is hidden.
  final VoidCallback? onDelete;

  @override
  ConsumerState<VideoClipPreview> createState() =>
      _VideoClipPreviewSheetState();
}

class _VideoClipPreviewSheetState extends ConsumerState<VideoClipPreview> {
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
    final file = File(await widget.clip.video.safeFilePath());
    if (!file.existsSync()) {
      if (mounted) context.pop();
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
      final video = widget.clip.video;
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

      context.pop();
    } catch (e, s) {
      Log.error(
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
        color: VineTheme.scrim65,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const .all(36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 48,
                children: [
                  // Video preview
                  Flexible(
                    child: AspectRatio(
                      aspectRatio: widget.clip.targetAspectRatio.value,
                      child: ClipRRect(
                        borderRadius: .circular(16),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Thumbnail
                            if (widget.clip.thumbnailPath != null)
                              Hero(
                                tag: 'Video-Clip-Preview-${widget.clip.id}',
                                child: Image.file(
                                  File(widget.clip.thumbnailPath!),
                                  fit: BoxFit.cover,
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
                                    alignment: Alignment.center,
                                    fit: StackFit.expand,
                                    children: <Widget>[
                                      ...previousChildren,
                                      ?currentChild,
                                    ],
                                  ),
                              switchInCurve: Curves.easeInOut,
                              duration: const Duration(milliseconds: 120),
                              child: _isInitialized && _controller != null
                                  ? FittedBox(
                                      fit: BoxFit.cover,
                                      clipBehavior: Clip.hardEdge,
                                      child: SizedBox(
                                        width: _controller!.value.size.width,
                                        height: _controller!.value.size.height,
                                        child: VideoPlayer(_controller!),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Action buttons row
                  _ActionButtonsRow(
                    isSaving: _isSaving,
                    onSave: _saveToGallery,
                    onDelete: widget.onDelete,
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

/// Row of action buttons displayed below the video preview.
///
/// Contains a save-to-gallery button and an optional delete button.
/// Absorbs taps to prevent dismissing the preview overlay.
class _ActionButtonsRow extends StatelessWidget {
  const _ActionButtonsRow({
    required this.isSaving,
    required this.onSave,
    this.onDelete,
  });

  static const double _buttonPadding = 12;

  /// Whether a save operation is currently in progress.
  final bool isSaving;

  /// Called when the save button is tapped.
  final VoidCallback onSave;

  /// Called when the delete button is tapped. If null, delete button is hidden.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: .transparency,
      child: Row(
        mainAxisSize: .min,
        mainAxisAlignment: .center,
        spacing: 32,
        children: [
          // Save to gallery button
          Semantics(
            button: true,
            // TODO(l10n): Replace with context.l10n when localization is added.
            label: 'Save to ${GallerySaveService.destinationName}',
            child: GestureDetector(
              onTap: onSave,
              child: Container(
                padding: const EdgeInsets.all(_buttonPadding),
                decoration: ShapeDecoration(
                  color: VineTheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const DivineIcon(
                  icon: DivineIconName.downloadSimple,
                  color: VineTheme.onPrimary,
                ),
              ),
            ),
          ),
          if (onDelete != null)
            // Delete button
            Semantics(
              button: true,
              // TODO(l10n): Replace with context.l10n when localization is
              // added.
              label: 'Delete clip',
              child: GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(_buttonPadding),
                  decoration: ShapeDecoration(
                    color: VineTheme.error,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const DivineIcon(
                    icon: DivineIconName.trash,
                    color: VineTheme.whiteText,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
