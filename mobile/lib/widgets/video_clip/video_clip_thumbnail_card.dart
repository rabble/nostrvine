// ABOUTME: Thumbnail card widget for displaying video clips in grid layout
// ABOUTME: Shows thumbnail with duration badge, selection state, and tap handlers

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/utils/video_editor_utils.dart';
import 'package:openvine/widgets/video_clip/clip_thumbnail_image.dart';

/// Thumbnail card for a single clip in the grid.
///
/// Displays a video clip thumbnail with duration badge and optional selection
/// indicator.
class VideoClipThumbnailCard extends StatefulWidget {
  const VideoClipThumbnailCard({
    required this.clip,
    this.onTap,
    this.onLongPress,
    this.selectionIndex = -1,
    this.showSelectionIndicator = true,
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

  /// Whether to show the selection indicator in the top-right corner.
  final bool showSelectionIndicator;

  /// Callback invoked when the card is tapped. When `null`, the card
  /// is non-interactive (e.g. in the trash bin view where restore /
  /// delete-now actions live outside the thumbnail).
  final VoidCallback? onTap;

  /// Callback invoked when the card is long-pressed. When `null`, no
  /// long-press handler is registered.
  final VoidCallback? onLongPress;

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
  bool get _isSelected => widget.selectionIndex > 0;

  @override
  Widget build(BuildContext context) {
    // Calculate aspect ratio for container
    final aspectRatio = widget.clip.targetAspectRatio.value;
    final showDurationBadge =
        widget.showDurationBadge && !widget.clip.isStopMotion;

    final l10n = context.l10n;
    return Semantics(
      label: l10n.videoClipSemanticLabel(
        widget.clip.duration.toFormattedSeconds(),
      ),
      value: _isSelected
          ? l10n.videoClipSemanticValueSelected
          : l10n.videoClipSemanticValueNotSelected,
      button: true,
      selected: _isSelected,
      enabled: !widget.disabled,
      onTap: widget.disabled ? null : widget.onTap,
      onLongPress: widget.disabled ? null : widget.onLongPress,
      hint: widget.disabled
          ? l10n.videoClipSemanticHintDisabled
          : _isSelected
          ? l10n.videoClipSemanticHintDeselect
          : l10n.videoClipSemanticHintSelect,
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

                    /// Stop-motion marker + still count - top left
                    if (widget.clip.isStopMotion)
                      _StopMotionBadge(
                        frameCount: widget.clip.stopMotionFrames?.length ?? 0,
                      ),

                    /// Duration badge - bottom left. Hidden for stop-motion
                    /// recordings: their playback length (frame count / 12fps)
                    /// is a tiny, misleading value, so they read as a still
                    /// image marked only by the stop-motion badge.
                    if (showDurationBadge)
                      _DurationBadge(clip: widget.clip),

                    if (widget.clip.libraryTitle case final title?)
                      _TitleBadge(
                        title: title,
                        bottomOffset: showDurationBadge ? 32 : 8,
                      ),

                    /// Selection check circle - top right
                    if (widget.showSelectionIndicator)
                      _SelectionOverlay(selectionIndex: widget.selectionIndex),
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
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.clip});

  final DivineVideoClip clip;

  @override
  Widget build(BuildContext context) {
    final thumbnailPath = clip.thumbnailPath;
    if (thumbnailPath != null) {
      return Hero(
        tag: 'Video-Clip-Preview-${clip.id}',
        // Stop-motion clips use a full-resolution still as their thumbnail;
        // bound the decode to the grid cell so it doesn't cost tens of MB.
        child: ClipThumbnailImage(
          path: thumbnailPath,
          fit: BoxFit.cover,
          cacheHeight:
              (MediaQuery.sizeOf(context).width *
                      MediaQuery.devicePixelRatioOf(context) /
                      2)
                  .round(),
          placeholder: const DivineIcon(
            icon: DivineIconName.videoCamera,
            color: VineTheme.lightText,
            size: 32,
          ),
        ),
      );
    }

    return const DivineIcon(
      icon: DivineIconName.videoCamera,
      color: VineTheme.lightText,
      size: 32,
    );
  }
}

class _TitleBadge extends StatelessWidget {
  const _TitleBadge({required this.title, required this.bottomOffset});

  final String title;
  final double bottomOffset;

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      start: 8,
      end: 8,
      bottom: bottomOffset,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: VineTheme.scrim65,
          borderRadius: .circular(4),
        ),
        child: Padding(
          padding: const .symmetric(horizontal: 6, vertical: 3),
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: VineTheme.labelSmallFont(),
          ),
        ),
      ),
    );
  }
}

/// Marks a clip in the library as a stop-motion recording and shows how many
/// stills it holds (top-left corner).
class _StopMotionBadge extends StatelessWidget {
  const _StopMotionBadge({required this.frameCount});

  /// Number of captured stills in the set.
  final int frameCount;

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      start: 6,
      top: 6,
      child: Semantics(
        label: context.l10n.libraryStopMotionClipLabel,
        value: context.l10n.videoEditorStopMotionFramesCount(frameCount),
        // The icon + count are decorative here; the count is already announced
        // via the badge's semantics value, so exclude the visual content to
        // keep a single, clean semantics node.
        child: ExcludeSemantics(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: VineTheme.scrim65,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 3,
              children: [
                const DivineIcon(
                  icon: .imagesSquare,
                  color: VineTheme.lightText,
                  size: 14,
                ),
                Text('$frameCount', style: VineTheme.labelSmallFont()),
              ],
            ),
          ),
        ),
      ),
    );
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
    return PositionedDirectional(
      start: 8,
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

  bool get _isSelected => selectionIndex > 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PositionedDirectional(
          end: 8,
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
