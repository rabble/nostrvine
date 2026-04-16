import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_timeline_overlay_strip.dart';

/// Watches [TimelineOverlayBloc] and renders layer / sound / filter strips.
///
/// Extracted into its own widget so that overlay state changes only rebuild
/// the overlay strips — not the clip strip or ruler.
class TimelineOverlayStrips extends StatelessWidget {
  const TimelineOverlayStrips({
    required this.totalWidth,
    required this.pixelsPerSecond,
    required this.totalDuration,
    required this.clipEdgesMs,
    required this.playheadPosition,
    super.key,
    this.onItemTapped,
    this.onItemMoved,
    this.onItemMoving,
    this.onItemTrimmed,
    this.onTrimDragChanged,
    this.onDragStarted,
    this.onDragEnded,
  });

  final double totalWidth;
  final double pixelsPerSecond;
  final Duration totalDuration;
  final List<int> clipEdgesMs;
  final ValueNotifier<Duration> playheadPosition;
  final ValueChanged<TimelineOverlayItem>? onItemTapped;
  final OverlayMoveCallback? onItemMoved;
  final OverlayMovingCallback? onItemMoving;
  final OverlayTrimCallback? onItemTrimmed;
  final ValueChanged<bool>? onTrimDragChanged;
  final ValueChanged<TimelineOverlayItem>? onDragStarted;
  final VoidCallback? onDragEnded;

  @override
  Widget build(BuildContext context) {
    final (:items, :selectedItemId, :collapsedTypes) = context.select(
      (TimelineOverlayBloc b) => (
        items: b.state.items,
        selectedItemId: b.state.selectedItemId,
        collapsedTypes: b.state.collapsedTypes,
      ),
    );

    final soundItems = <TimelineOverlayItem>[];
    final filterItems = <TimelineOverlayItem>[];
    final layerItems = <TimelineOverlayItem>[];

    var maxSoundRow = -1;
    var maxFilterRow = -1;
    var maxLayerRow = -1;

    for (final item in items) {
      switch (item.type) {
        case TimelineOverlayType.sound:
          soundItems.add(item);
          if (item.row > maxSoundRow) maxSoundRow = item.row;
        case TimelineOverlayType.filter:
          filterItems.add(item);
          if (item.row > maxFilterRow) maxFilterRow = item.row;
        case TimelineOverlayType.layer:
          layerItems.add(item);
          if (item.row > maxLayerRow) maxLayerRow = item.row;
      }
    }

    final soundRowCount = maxSoundRow + 1;
    final filterRowCount = maxFilterRow + 1;
    final layerRowCount = maxLayerRow + 1;

    final stripConfigs = [
      (
        items: soundItems,
        rowCount: soundRowCount,
        type: TimelineOverlayType.sound,
        color: VineTheme.accentVioletBackground,
        rowHeight: TimelineConstants.soundOverlayRowHeight,
      ),
      (
        items: filterItems,
        rowCount: filterRowCount,
        type: TimelineOverlayType.filter,
        color: VineTheme.success,
        rowHeight: TimelineConstants.overlayRowHeight,
      ),
      (
        items: layerItems,
        rowCount: layerRowCount,
        type: TimelineOverlayType.layer,
        color: VineTheme.primary,
        rowHeight: TimelineConstants.overlayRowHeight,
      ),
    ];

    // Build snap points from all overlay item edges + clip edges +
    // playhead, excluding the selected item so it doesn't snap to itself.
    final snapSet = <int>{};
    for (final item in items) {
      if (item.id == selectedItemId) continue;
      snapSet.add(item.startTime.inMilliseconds);
      snapSet.add(item.endTime.inMilliseconds);
    }
    snapSet.addAll(clipEdgesMs);
    snapSet.add(playheadPosition.value.inMilliseconds);
    final snapPointsMs = snapSet.toList();

    return Padding(
      padding: const .only(top: TimelineConstants.overlayStripGap),
      child: Column(
        spacing: TimelineConstants.overlayStripGap,
        crossAxisAlignment: .start,
        mainAxisSize: .min,
        children: [
          for (final config in stripConfigs)
            if (config.items.isNotEmpty)
              TimelineOverlayStrip(
                items: config.items,
                rowCount: config.rowCount,
                totalWidth: totalWidth,
                pixelsPerSecond: pixelsPerSecond,
                totalDuration: totalDuration,
                color: config.color,
                rowHeight: config.rowHeight,
                isCollapsed: collapsedTypes.contains(config.type),
                selectedItemId: selectedItemId,
                snapPointsMs: snapPointsMs,
                onItemTapped: onItemTapped,
                onItemMoved: onItemMoved,
                onItemMoving: onItemMoving,
                onTrimChanged: onItemTrimmed,
                onTrimDragChanged: onTrimDragChanged,
                onDragStarted: onDragStarted,
                onDragEnded: onDragEnded,
              ),
        ],
      ),
    );
  }
}
