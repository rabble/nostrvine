// ABOUTME: Thumbnail card widget for displaying video clips in grid layout
// ABOUTME: Shows thumbnail with duration badge, selection state, and tap handlers

import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/utils/video_editor_utils.dart';

/// Thumbnail card for a single clip in the grid.
///
/// Displays a video clip thumbnail with duration badge and optional selection
/// indicator.
/// Uses [FutureBuilder] to asynchronously check thumbnail file existence for
/// optimal performance.
class VideoClipThumbnailCard extends StatefulWidget {
  const VideoClipThumbnailCard({
    required this.clip,
    required this.onTap,
    required this.onLongPress,
    this.selectionIndex = 0,
    this.isSelected = false,
    this.disabled = false,
    this.showDurationBadge = true,
    super.key,
  });

  /// The clip data to display, including thumbnail path, duration, and
  /// aspect ratio.
  final DivineVideoClip clip;

  /// The 1-based position of this clip in the current selection order.
  ///
  /// Displayed inside the selection circle when the card is selected.
  final int selectionIndex;

  /// Callback invoked when the card is tapped.
  final VoidCallback onTap;

  /// Callback invoked when the card is long-pressed.
  final VoidCallback onLongPress;

  /// Whether this clip is currently selected, showing green border and
  /// check icon.
  final bool isSelected;

  /// Whether to show the duration badge at the bottom-left corner.
  final bool showDurationBadge;

  /// Whether this clip is disabled and cannot be interacted with.
  /// When disabled, the card is shown with reduced opacity and tap handlers
  /// are inactive.
  final bool disabled;

  @override
  State<VideoClipThumbnailCard> createState() => _VideoClipThumbnailCardState();
}

/// State for [VideoClipThumbnailCard].
///
/// Manages thumbnail existence check as a cached [Future] to prevent
/// redundant file system checks on rebuild.
class _VideoClipThumbnailCardState extends State<VideoClipThumbnailCard> {
  @override
  Widget build(BuildContext context) {
    // Calculate aspect ratio for container
    final aspectRatio = widget.clip.targetAspectRatio.value;

    return Semantics(
      // TODO(l10n): Replace with context.l10n when localization is added.
      label: 'Video clip, ${widget.clip.duration.toFormattedSeconds()} seconds',
      value: widget.isSelected ? 'Selected' : 'Not selected',
      button: true,
      selected: widget.isSelected,
      enabled: !widget.disabled,
      onTap: widget.disabled ? null : widget.onTap,
      onLongPress: widget.disabled ? null : widget.onLongPress,
      // TODO(l10n): Replace with context.l10n when localization is added.
      hint: widget.disabled
          ? 'Disabled'
          : 'Tap to ${widget.isSelected ? 'deselect' : 'select'}, '
                'long press to preview',
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 100),
        opacity: widget.disabled ? 0.4 : 1.0,
        child: GestureDetector(
          onTap: widget.disabled ? null : widget.onTap,
          onLongPress: widget.disabled ? null : widget.onLongPress,
          child: ClipRRect(
            borderRadius: .circular(4),
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: ColoredBox(
                color: VineTheme.cardBackground,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    /// Thumbnail or placeholder
                    _Thumbnail(clip: widget.clip),

                    /// Duration badge - bottom left
                    if (widget.showDurationBadge)
                      _DurationBadge(clip: widget.clip),

                    /// Selection check circle - top right
                    _SelectionOverlay(
                      selectionIndex: widget.selectionIndex,
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

/// Builds the thumbnail image or placeholder.
///
/// Uses [FutureBuilder] to show a loading spinner while checking if the
/// thumbnail exists, then displays either the thumbnail image or a
/// placeholder icon.
class _Thumbnail extends StatefulWidget {
  const _Thumbnail({required this.clip});

  final DivineVideoClip clip;

  @override
  State<_Thumbnail> createState() => _ThumbnailState();
}

class _ThumbnailState extends State<_Thumbnail> {
  late bool _thumbnailExists;

  @override
  void initState() {
    super.initState();
    _thumbnailExists = _checkThumbnailExists();
  }

  /// Asynchronously checks if the thumbnail file exists
  bool _checkThumbnailExists() {
    if (widget.clip.thumbnailPath == null) {
      return false;
    }
    return File(widget.clip.thumbnailPath!).existsSync();
  }

  @override
  Widget build(BuildContext context) {
    if (_thumbnailExists && widget.clip.thumbnailPath != null) {
      return Hero(
        tag: 'Video-Clip-Preview-${widget.clip.id}',
        child: Image.file(File(widget.clip.thumbnailPath!), fit: .cover),
      );
    }

    return const Icon(Icons.videocam, color: VineTheme.lightText, size: 32);
  }
}

/// Builds the duration badge shown at the bottom-left corner.
///
/// Displays the clip duration in seconds with 2 decimal places.
class _DurationBadge extends StatelessWidget {
  const _DurationBadge({required this.clip});

  final DivineVideoClip clip;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 8,
      bottom: 8,
      child: Container(
        padding: const .symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: VineTheme.scrim65,
          borderRadius: .circular(4),
        ),
        child: Text(
          clip.durationInSeconds.toStringAsFixed(2),
          style: VineTheme.labelSmallFont().copyWith(
            fontFeatures: [const .tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// Builds the selection overlay with a numbered circle indicator.
///
/// Shows a circular badge in the top-right corner. When selected, displays
/// the selection index number; when unselected, shows an empty circle.
class _SelectionOverlay extends StatelessWidget {
  const _SelectionOverlay({required this.selectionIndex});

  final int selectionIndex;

  bool get _isSelected => selectionIndex >= 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          right: 8,
          top: 6,
          child: Container(
            constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
            padding: const .all(5),
            decoration: BoxDecoration(
              color: _isSelected
                  ? VineTheme.surfaceBackground
                  : VineTheme.onSurfaceDisabled,
              border: Border.all(
                color: _isSelected ? VineTheme.primary : VineTheme.onSurface,
                width: 3,
              ),
              borderRadius: .circular(999),
            ),
            child: _isSelected
                ? Center(
                    child: MediaQuery.withNoTextScaling(
                      child: Text(
                        selectionIndex.toString(),
                        maxLines: 1,
                        style: VineTheme.labelLargeFont().copyWith(
                          fontFeatures: [const .tabularFigures()],
                          height: 1,
                        ),
                      ),
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
