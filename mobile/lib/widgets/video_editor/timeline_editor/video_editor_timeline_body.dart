import 'dart:typed_data';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_timeline_clip_strip.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_timeline_overlay_strip.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_timeline_overlay_strips.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/utils/hit_expanded_box.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/utils/vertical_only_clipper.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_rules_indicator.dart';

class VideoEditorTimelineBody extends StatelessWidget {
  const VideoEditorTimelineBody({
    required this.totalDuration,
    required this.pixelsPerSecond,
    required this.scrollController,
    required this.scrollPadding,
    required this.clips,
    required this.totalWidth,
    required this.isInteracting,
    required this.onReorder,
    required this.onReorderChanged,
    required this.playheadPosition,
    super.key,
    this.trimmingClipId,
    this.onTrimChanged,
    this.onTrimDragChanged,
    this.onClipTapped,
    this.onOverlayItemMoved,
    this.onOverlayItemMoving,
    this.onOverlayItemTrimmed,
    this.onOverlayTrimDragChanged,
    this.onOverlayItemTapped,
    this.onOverlayDragStarted,
    this.onOverlayDragEnded,
  });

  final Duration totalDuration;
  final double pixelsPerSecond;
  final ScrollController scrollController;
  final double scrollPadding;
  final List<DivineVideoClip> clips;
  final double totalWidth;
  final bool isInteracting;

  static const _scrollBottomPadding = 100;

  /// Computes cumulative clip-boundary positions in milliseconds.
  /// Each clip edge (start of first clip + end of each clip) creates a
  /// potential snap target for overlay items.
  static List<int> _clipEdgesMs(List<DivineVideoClip> clips) {
    final edges = <int>[0];
    var runningMs = 0;
    for (final clip in clips) {
      runningMs += clip.trimmedDuration.inMilliseconds;
      edges.add(runningMs);
    }
    return edges;
  }

  final ValueChanged<List<DivineVideoClip>>? onReorder;
  final ValueChanged<bool>? onReorderChanged;
  final String? trimmingClipId;
  final ClipTrimCallback? onTrimChanged;
  final ValueChanged<bool>? onTrimDragChanged;
  final ValueChanged<int>? onClipTapped;
  final OverlayMoveCallback? onOverlayItemMoved;
  final OverlayMovingCallback? onOverlayItemMoving;
  final OverlayTrimCallback? onOverlayItemTrimmed;
  final ValueChanged<bool>? onOverlayTrimDragChanged;
  final ValueChanged<TimelineOverlayItem>? onOverlayItemTapped;
  final ValueChanged<TimelineOverlayItem>? onOverlayDragStarted;
  final VoidCallback? onOverlayDragEnded;
  final ValueNotifier<Duration> playheadPosition;

  @override
  Widget build(BuildContext context) {
    final (isReordering) = context.select(
      (VideoEditorMainBloc b) => b.state.isReordering,
    );

    final clipTrimExpand = trimmingClipId != null
        ? TimelineConstants.trimHandleWidth + TimelineConstants.trimHitAreaExtra
        : 0.0;

    // Also expand for overlay trim handles when an overlay item is selected.
    final overlaySelectedId = context.select(
      (TimelineOverlayBloc b) => b.state.selectedItemId,
    );
    final overlayTrimExpand = overlaySelectedId != null
        ? TimelineConstants.trimHandleWidth + TimelineConstants.trimHitAreaExtra
        : 0.0;

    final trimExpand = clipTrimExpand > overlayTrimExpand
        ? clipTrimExpand
        : overlayTrimExpand;
    final showMaxDurationOverlays =
        !isReordering && totalDuration > VideoEditorConstants.maxDuration;

    return HitExpandedBox(
      expandLeft: trimExpand,
      expandRight: trimExpand,
      child: Stack(
        fit: .passthrough,
        clipBehavior: .none,
        children: [
          // Keep stack slots stable during drag-reorder to avoid gesture drops.
          _TimelineMaxDurationStripeOverlay(
            pixelsPerSecond: pixelsPerSecond,
            visible: showMaxDurationOverlays,
          ),

          Column(
            crossAxisAlignment: .start,
            mainAxisSize: .min,
            children: [
              /// Rules Indicator
              AnimatedOpacity(
                opacity: isReordering ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: VideoEditorTimelineRulesIndicator(
                  totalDuration: totalDuration,
                  pixelsPerSecond: pixelsPerSecond,
                  scrollController: scrollController,
                  scrollPadding: scrollPadding,
                ),
              ),
              const SizedBox(height: 4),

              /// Video-Clips
              VideoEditorTimelineClipStrip(
                clips: clips,
                totalWidth: totalWidth,
                pixelsPerSecond: pixelsPerSecond,
                scrollController: scrollController,
                isInteracting: isInteracting,
                onReorder: onReorder,
                onReorderChanged: onReorderChanged,
                trimmingClipId: trimmingClipId,
                onTrimChanged: onTrimChanged,
                onTrimDragChanged: onTrimDragChanged,
                onClipTapped: onClipTapped,
              ),

              /// Layers, Filters and Audio-Tracks
              Expanded(
                child: AnimatedOpacity(
                  opacity: isReordering ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: ClipRect(
                    clipper: const VerticalOnlyClipper(),
                    child: SingleChildScrollView(
                      clipBehavior: .none,
                      padding: .only(
                        top: 4,
                        bottom:
                            _scrollBottomPadding +
                            MediaQuery.paddingOf(context).bottom,
                      ),
                      child: IgnorePointer(
                        ignoring: isReordering,
                        child: TimelineOverlayStrips(
                          totalWidth: totalWidth,
                          pixelsPerSecond: pixelsPerSecond,
                          totalDuration: totalDuration,
                          clipEdgesMs: _clipEdgesMs(clips),
                          playheadPosition: playheadPosition,
                          onItemTapped: onOverlayItemTapped,
                          onItemMoved: onOverlayItemMoved,
                          onItemMoving: onOverlayItemMoving,
                          onItemTrimmed: onOverlayItemTrimmed,
                          onTrimDragChanged: onOverlayTrimDragChanged,
                          onDragStarted: onOverlayDragStarted,
                          onDragEnded: onOverlayDragEnded,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          _TimelineMaxDurationDimOverlay(
            pixelsPerSecond: pixelsPerSecond,
            visible: showMaxDurationOverlays,
          ),
        ],
      ),
    );
  }
}

class _TimelineMaxDurationStripeOverlay extends StatelessWidget {
  const _TimelineMaxDurationStripeOverlay({
    required this.pixelsPerSecond,
    required this.visible,
  });

  final double pixelsPerSecond;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final outsideExtendWidth = MediaQuery.sizeOf(context).width / 2;

    return Positioned(
      left:
          VideoEditorConstants.maxDuration.inMilliseconds /
          1000 *
          pixelsPerSecond,
      top: 0,
      bottom: 0,
      right: -outsideExtendWidth,
      child: IgnorePointer(
        child: Visibility(
          visible: visible,
          maintainState: true,
          child: const CustomPaint(
            painter: _TimelineOutsideAreaPainter(
              stripeColor: VineTheme.onSurfaceDisabled,
            ),
            child: SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _TimelineMaxDurationDimOverlay extends StatelessWidget {
  const _TimelineMaxDurationDimOverlay({
    required this.pixelsPerSecond,
    required this.visible,
  });

  final double pixelsPerSecond;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final outsideExtendWidth = MediaQuery.sizeOf(context).width / 2;

    return Positioned(
      left:
          VideoEditorConstants.maxDuration.inMilliseconds /
          1000 *
          pixelsPerSecond,
      top: 0,
      bottom: 0,
      right: -outsideExtendWidth,
      child: IgnorePointer(
        child: Visibility(
          visible: visible,
          maintainState: true,
          child: ColoredBox(
            color: VineTheme.surfaceContainerHigh.withValues(alpha: 0.3),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _TimelineOutsideAreaPainter extends CustomPainter {
  const _TimelineOutsideAreaPainter({
    required this.stripeColor,
  });

  static const _stripeRotationRadians = 1.05;
  static const double _stripeWidth = 5;
  static const double _stripeGap = 10;
  static final Float64List _stripeTransformStorage =
      (Matrix4.identity()..rotateZ(_stripeRotationRadians)).storage;

  final Color stripeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final stripePaint = Paint()
      ..color = stripeColor
      ..strokeWidth = _stripeWidth
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = false;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.transform(_stripeTransformStorage);

    final drawHeight = (size.height * 3).ceilToDouble();
    final drawWidth = (size.width * 3).ceilToDouble();
    final startX = -drawWidth - ((-drawWidth) % _stripeGap);
    for (var x = startX; x <= drawWidth; x += _stripeGap) {
      canvas.drawLine(
        Offset(x, -drawHeight),
        Offset(x, drawHeight),
        stripePaint,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TimelineOutsideAreaPainter oldDelegate) {
    return oldDelegate.stripeColor != stripeColor;
  }
}
