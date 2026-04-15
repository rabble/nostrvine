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

  static List<TimelineOverlayItem> _itemsOfType(
    List<TimelineOverlayItem> items,
    TimelineOverlayType type,
  ) {
    final filtered = items.where((i) => i.type == type).toList()
      ..sort((a, b) {
        final rowCmp = a.row.compareTo(b.row);
        if (rowCmp != 0) return rowCmp;
        return a.startTime.compareTo(b.startTime);
      });
    return filtered;
  }

  static int _rowCountForType(
    List<TimelineOverlayItem> items,
    TimelineOverlayType type,
  ) {
    var maxRow = -1;
    for (final item in items) {
      if (item.type == type && item.row > maxRow) {
        maxRow = item.row;
      }
    }
    return maxRow + 1;
  }

  @override
  Widget build(BuildContext context) {
    final (:items, :selectedItemId, :collapsedTypes) = context.select(
      (TimelineOverlayBloc b) => (
        items: b.state.items,
        selectedItemId: b.state.selectedItemId,
        collapsedTypes: b.state.collapsedTypes,
      ),
    );

    final soundItems = _itemsOfType(items, .sound);
    final filterItems = _itemsOfType(items, .filter);
    final layerItems = _itemsOfType(items, .layer);
    final stripConfigs = [
      (
        items: soundItems,
        type: TimelineOverlayType.sound,
        color: VineTheme.accentVioletBackground,
        rowHeight: TimelineConstants.soundOverlayRowHeight,
      ),
      (
        items: filterItems,
        type: TimelineOverlayType.filter,
        color: VineTheme.success,
        rowHeight: TimelineConstants.overlayRowHeight,
      ),
      (
        items: layerItems,
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
                rowCount: _rowCountForType(items, config.type),
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
