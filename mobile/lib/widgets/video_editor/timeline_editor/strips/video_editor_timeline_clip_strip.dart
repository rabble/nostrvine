// ---------------------------------------------------------------------------
// Clip thumbnail strip — horizontal row of clip containers
// ---------------------------------------------------------------------------

import 'dart:async';
import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/timeline_constants.dart';

class VideoEditorTimelineClipStrip extends StatelessWidget {
  const VideoEditorTimelineClipStrip({
    required this.clips,
    required this.totalWidth,
    required this.pixelsPerSecond,
    super.key,
  });

  final List<DivineVideoClip> clips;
  final double totalWidth;
  final double pixelsPerSecond;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: TimelineConstants.thumbnailStripHeight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < clips.length; i++) ...[
            if (i > 0) const SizedBox(width: TimelineConstants.clipGap),
            _ClipContainer(
              key: ValueKey('clip-container-${clips[i].id}'),
              clip: clips[i],
              width: _clipWidth(clips[i]),
            ),
          ],
        ],
      ),
    );
  }

  double _clipWidth(DivineVideoClip clip) {
    if (clips.length == 1) return totalWidth;
    return clip.durationInSeconds * pixelsPerSecond;
  }
}

// ---------------------------------------------------------------------------
// Single clip — rounded border + thumbnail images filling the width
// ---------------------------------------------------------------------------

class _ClipContainer extends StatefulWidget {
  const _ClipContainer({
    required this.clip,
    required this.width,
    super.key,
  });

  final DivineVideoClip clip;
  final double width;

  @override
  State<_ClipContainer> createState() => _ClipContainerState();
}

class _ClipContainerState extends State<_ClipContainer> {
  List<StripThumbnail> _stripThumbnails = const [];
  StreamSubscription<List<StripThumbnail>>? _subscription;
  bool _loaded = false;

  int get _thumbnailCount =>
      (widget.width / TimelineConstants.thumbnailWidth).ceil().clamp(1, 100);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _loadStripThumbnails();
    }
  }

  @override
  void didUpdateWidget(_ClipContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clip.id != widget.clip.id) {
      _cancelAndCleanup();
      _loadStripThumbnails();
    }
  }

  @override
  void dispose() {
    _cancelAndCleanup();
    super.dispose();
  }

  void _cancelAndCleanup() {
    _subscription?.cancel();
    _subscription = null;
    // Fire and forgot
    _deleteFiles(_stripThumbnails);
    _stripThumbnails = const [];
  }

  /// Deletes thumbnail files asynchronously to avoid blocking the UI thread.
  static Future<void> _deleteFiles(List<StripThumbnail> thumbnails) async {
    for (final thumb in thumbnails) {
      try {
        await File(thumb.path).delete();
      } catch (_) {}
    }
  }

  void _loadStripThumbnails() {
    final videoPath = widget.clip.video.file?.path;
    if (videoPath == null) return;

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final outputSize = Size(
      TimelineConstants.thumbnailWidth * dpr,
      TimelineConstants.thumbnailStripHeight * dpr,
    );

    _subscription =
        VideoThumbnailService.generateStripThumbnails(
          videoPath: videoPath,
          clipId: widget.clip.id,
          duration: widget.clip.duration,
          outputSize: outputSize,
        ).listen((thumbnails) {
          if (mounted) setState(() => _stripThumbnails = thumbnails);
        });
  }

  /// Maps a visual slot index to the nearest available [StripThumbnail] path.
  String? _thumbnailForSlot(int slotIndex, int slotCount) {
    if (_stripThumbnails.isEmpty) return null;

    final durationMs = widget.clip.duration.inMilliseconds;
    if (durationMs <= 0) return _stripThumbnails.first.path;

    // Time at the center of this visual slot.
    final slotTimeMs = durationMs * (slotIndex + 0.5) / slotCount;

    // Find the thumbnail closest in time.
    var bestIndex = 0;
    var bestDist = (slotTimeMs - _stripThumbnails[0].timestamp.inMilliseconds)
        .abs();
    for (var i = 1; i < _stripThumbnails.length; i++) {
      final dist = (slotTimeMs - _stripThumbnails[i].timestamp.inMilliseconds)
          .abs();
      if (dist < bestDist) {
        bestDist = dist;
        bestIndex = i;
      }
    }
    return _stripThumbnails[bestIndex].path;
  }

  @override
  Widget build(BuildContext context) {
    final count = _thumbnailCount;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
          TimelineConstants.thumbnailRadius,
        ),
        border: Border.all(color: VineTheme.onSurfaceMuted),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          TimelineConstants.thumbnailRadius,
        ),
        child: SizedBox(
          width: widget.width,
          height: TimelineConstants.thumbnailStripHeight,
          child: Row(
            children: [
              for (int i = 0; i < count; i++)
                SizedBox(
                  width: widget.width / count,
                  height: TimelineConstants.thumbnailStripHeight,
                  child: _ThumbnailImage(
                    thumbnailPath: widget.clip.thumbnailPath,
                    stripThumbnailPath: _thumbnailForSlot(i, count),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThumbnailImage extends StatelessWidget {
  const _ThumbnailImage({
    required this.thumbnailPath,
    this.stripThumbnailPath,
  });

  final String? thumbnailPath;
  final String? stripThumbnailPath;

  @override
  Widget build(BuildContext context) {
    final fallback = thumbnailPath != null
        ? Image.file(
            File(thumbnailPath!),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: VineTheme.surfaceContainerHigh),
          )
        : const ColoredBox(color: VineTheme.surfaceContainerHigh);

    if (stripThumbnailPath == null) return fallback;

    return Image.file(
      File(stripThumbnailPath!),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}
