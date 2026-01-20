// ABOUTME: Thumbnail card widget for displaying video clips in grid layout
// ABOUTME: Shows thumbnail with duration badge, selection state, and tap handlers

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:openvine/models/saved_clip.dart';
import 'package:openvine/platform_io.dart';
import 'package:divine_ui/divine_ui.dart';
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
    this.isSelected = false,
    this.disabled = false,
    super.key,
  });

  /// The clip data to display, including thumbnail path, duration, and
  /// aspect ratio.
  final SavedClip clip;

  /// Callback invoked when the card is tapped.
  final VoidCallback onTap;

  /// Callback invoked when the card is long-pressed.
  final VoidCallback onLongPress;

  /// Whether this clip is currently selected, showing green border and
  /// check icon.
  final bool isSelected;

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
    final aspectRatio = widget.clip.aspectRatio == 'vertical' ? 9 / 16 : 1.0;

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
                color: Colors.grey.shade800,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    /// Thumbnail or placeholder
                    _Thumbnail(clip: widget.clip),

                    /// Duration badge - bottom left
                    _DurationBadge(clip: widget.clip),

                    /// Selection check circle - top right
                    AnimatedSwitcher(
                      duration: Duration(milliseconds: 120),
                      child: widget.isSelected
                          ? const _SelectionOverlay()
                          : const SizedBox.shrink(),
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

  final SavedClip clip;

  @override
  State<_Thumbnail> createState() => _ThumbnailState();
}

class _ThumbnailState extends State<_Thumbnail> {
  /// Cached future that resolves to whether the thumbnail file exists.
  /// Initialized once in [initState] to avoid repeated file system checks.
  late Future<bool> _thumbnailExistsFuture;

  @override
  void initState() {
    super.initState();
    _thumbnailExistsFuture = _checkThumbnailExists();
  }

  /// Asynchronously checks if the thumbnail file exists
  Future<bool> _checkThumbnailExists() async {
    if (widget.clip.thumbnailPath == null) {
      return false;
    }
    return File(widget.clip.thumbnailPath!).exists();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _thumbnailExistsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == .waiting) {
          return const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
              ),
            ),
          );
        }

        if ((snapshot.data ?? false) && widget.clip.thumbnailPath != null) {
          return Hero(
            tag: 'Video-Clip-Preview-${widget.clip.id}',
            child: Image.file(File(widget.clip.thumbnailPath!), fit: .cover),
          );
        }

        return const Icon(Icons.videocam, color: Colors.grey, size: 32);
      },
    );
  }
}

/// Builds the duration badge shown at the bottom-left corner.
///
/// Displays the clip duration in seconds with 2 decimal places.
class _DurationBadge extends StatelessWidget {
  const _DurationBadge({required this.clip});

  final SavedClip clip;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 12,
      bottom: 12,
      child: Container(
        padding: const .symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: .circular(4),
        ),
        child: Text(
          clip.durationInSeconds.toStringAsFixed(2),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontFamily: 'BricolageGrotesque',
            fontWeight: .w800,
            height: 1.43,
            letterSpacing: 0.10,
            fontFeatures: [.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// Builds the selection overlay with green border and check icon.
///
/// Returns a list containing:
/// - A [DecoratedBox] for the 4px green border
/// - A positioned check icon in a circular green background
class _SelectionOverlay extends StatelessWidget {
  const _SelectionOverlay();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: .circular(4),
              border: .all(color: VineTheme.tabIndicatorGreen, width: 4),
            ),
          ),
        ),
        Positioned(
          right: 14,
          top: 14,
          child: Container(
            width: 32,
            height: 32,
            padding: const .all(8),
            decoration: const BoxDecoration(
              shape: .circle,
              color: VineTheme.tabIndicatorGreen,
            ),
            child: SvgPicture.asset(
              'assets/icon/Check.svg',
              colorFilter: const ColorFilter.mode(Color(0xFF002C1C), .srcIn),
            ),
          ),
        ),
      ],
    );
  }
}
