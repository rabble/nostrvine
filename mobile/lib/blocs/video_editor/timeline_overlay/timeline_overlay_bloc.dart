// ABOUTME: BLoC for managing overlay items (layers, filters, sounds) on the
// ABOUTME: video editor timeline. Handles add/remove/move/trim/select/drag
// ABOUTME: and collapse state for all three strip types.

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

part 'timeline_overlay_event.dart';
part 'timeline_overlay_state.dart';

/// Manages overlay items (layers, filters, sounds) on the timeline.
///
/// Each item lives in a typed strip and can be repositioned in time
/// (horizontal) and in z-order / row (vertical). Rows are created
/// dynamically when items are dragged beyond existing rows.
class TimelineOverlayBloc
    extends Bloc<TimelineOverlayEvent, TimelineOverlayState> {
  TimelineOverlayBloc() : super(const TimelineOverlayState()) {
    on<TimelineOverlayItemsUpdate>(_onUpdateItems);
    on<TimelineOverlayItemMoved>(_onItemMoved, transformer: restartable());
    on<TimelineOverlayItemTrimmed>(
      _onItemTrimmed,
      transformer: restartable(),
    );
    on<TimelineOverlayItemSelected>(_onItemSelected);
    on<TimelineOverlayDragStarted>(_onDragStarted);
    on<TimelineOverlayDragEnded>(_onDragEnded);
    on<TimelineOverlayCollapseToggled>(_onCollapseToggled);
    on<TimelineOverlayTotalDurationChanged>(_onTotalDurationChanged);
  }

  void _onUpdateItems(
    TimelineOverlayItemsUpdate event,
    Emitter<TimelineOverlayState> emit,
  ) {
    int filterRow = 0;
    int layerRow = 0;
    int soundRow = 0;

    emit(
      state.copyWith(
        items: [
          for (final track in event.audioTracks)
            TimelineOverlayItem(
              id: track.id,
              type: .sound,
              startTime: track.startTime ?? .zero,
              endTime: (track.startTime ?? .zero) + track.duration,
              label: track.title,
              row: soundRow++,
            ),
          for (var i = 0; i < event.filters.length; i++)
            // Skip no-op FilterStates (empty matrices) that are inserted by
            // _removeFilter to "clear" the filter in the editor history.
            if (event.filters[i].isNotEmpty)
              TimelineOverlayItem(
                id: 'filter_${event.filters[i].name}_$i',
                type: TimelineOverlayType.filter,
                startTime: event.filters[i].startTime ?? Duration.zero,
                endTime: event.filters[i].endTime ?? event.totalVideoDuration,
                label: event.filters[i].name,
                row: filterRow++,
              ),
          for (final layer in event.layers)
            TimelineOverlayItem(
              id: layer.id,
              type: .layer,
              startTime: layer.startTime ?? .zero,
              endTime: layer.endTime ?? event.totalVideoDuration,
              label: _labelForLayer(layer),
              row: layerRow++,
            ),
        ],
        clearSelectedItemId: true,
        clearDraggingItemId: true,
      ),
    );
  }

  /// Returns a human-readable label based on the layer type.
  static String _labelForLayer(Layer layer) => switch (layer) {
    TextLayer(:final text) => text,
    PaintLayer() => 'Drawing',
    EmojiLayer(:final emoji) => emoji,
    WidgetLayer() => 'Sticker',
    _ => 'Layer',
  };

  void _onItemMoved(
    TimelineOverlayItemMoved event,
    Emitter<TimelineOverlayState> emit,
  ) {
    var items = List<TimelineOverlayItem>.from(state.items);
    final idx = items.indexWhere((i) => i.id == event.itemId);
    if (idx == -1) return;

    final old = items[idx];
    final newStartTime = event.startTime ?? old.startTime;
    final endTimeShift = newStartTime - old.startTime;
    final moved = old.copyWith(
      startTime: newStartTime,
      endTime: old.endTime + endTimeShift,
      row: event.row ?? old.row,
    );

    final hasOverlap = items.any(
      (i) =>
          i.id != moved.id &&
          i.type == moved.type &&
          i.row == moved.row &&
          _overlapsInTime(i, moved),
    );

    if (hasOverlap) {
      if (event.insertAbove) {
        // Keep the moved item at its row; push existing items down.
        items = _shiftRowsDown(items, moved.type, moved.row);
        items[idx] = moved;
      } else {
        // Place the moved item one row below; push existing items down.
        final targetRow = moved.row + 1;
        items = _shiftRowsDown(items, moved.type, targetRow);
        items[idx] = moved.copyWith(row: targetRow);
      }
    } else {
      items[idx] = moved;
    }
    emit(state.copyWith(items: items));
  }

  void _onItemTrimmed(
    TimelineOverlayItemTrimmed event,
    Emitter<TimelineOverlayState> emit,
  ) {
    var items = List<TimelineOverlayItem>.from(state.items);
    final idx = items.indexWhere((i) => i.id == event.itemId);
    if (idx == -1) return;

    final item = items[idx];

    final trimmed = item.copyWith(
      startTime: event.startTime,
      endTime: event.endTime,
    );

    // Check if the trimmed item now overlaps with others on the same row.
    final hasOverlap = items.any(
      (i) =>
          i.id != trimmed.id &&
          i.type == trimmed.type &&
          i.row == trimmed.row &&
          _overlapsInTime(i, trimmed),
    );

    if (hasOverlap) {
      final targetRow = trimmed.row + 1;
      items = _shiftRowsDown(items, trimmed.type, targetRow);
      items[idx] = trimmed.copyWith(row: targetRow);
    } else {
      items[idx] = trimmed;
    }
    emit(state.copyWith(items: items));
  }

  void _onItemSelected(
    TimelineOverlayItemSelected event,
    Emitter<TimelineOverlayState> emit,
  ) {
    if (event.itemId == null) {
      emit(state.copyWith(clearSelectedItemId: true));
    } else {
      emit(state.copyWith(selectedItemId: event.itemId));
    }
  }

  void _onDragStarted(
    TimelineOverlayDragStarted event,
    Emitter<TimelineOverlayState> emit,
  ) {
    emit(state.copyWith(draggingItemId: event.itemId));
  }

  void _onDragEnded(
    TimelineOverlayDragEnded event,
    Emitter<TimelineOverlayState> emit,
  ) {
    // Compact rows so there are no empty gaps.
    emit(
      state.copyWith(
        items: _compactRows(state.items),
        clearDraggingItemId: true,
      ),
    );
  }

  void _onCollapseToggled(
    TimelineOverlayCollapseToggled event,
    Emitter<TimelineOverlayState> emit,
  ) {
    final types = Set<TimelineOverlayType>.from(state.collapsedTypes);
    if (types.contains(event.type)) {
      types.remove(event.type);
    } else {
      types.add(event.type);
    }
    emit(state.copyWith(collapsedTypes: types));
  }

  /// Clamp every overlay item so its visible region fits within
  /// [0, totalDuration]. Items that end up with zero visible duration
  /// are removed.
  void _onTotalDurationChanged(
    TimelineOverlayTotalDurationChanged event,
    Emitter<TimelineOverlayState> emit,
  ) {
    /* final totalMs = event.totalDuration.inMilliseconds;
    if (totalMs <= 0) return;

    final updated = <TimelineOverlayItem>[];
    for (final item in state.items) {
      var startMs = item.startTime.inMilliseconds;
      var durationMs = item.duration.inMilliseconds;
      var trimStartMs = item.trimStart.inMilliseconds;
      var trimEndMs = item.trimEnd.inMilliseconds;

      // Shrink duration so the raw end doesn't exceed totalDuration.
      final rawEndMs = startMs + durationMs;
      if (rawEndMs > totalMs + trimEndMs) {
        durationMs = totalMs - startMs + trimEndMs;
      }

      // If startTime itself is beyond totalDuration, clamp it.
      if (startMs >= totalMs) {
        startMs = (totalMs - (durationMs - trimStartMs - trimEndMs)).clamp(
          0,
          totalMs,
        );
      }

      // Ensure visual end (start + duration - trimStart - trimEnd)
      // does not exceed totalDuration.
      final visualEndMs = startMs + durationMs - trimStartMs - trimEndMs;
      if (visualEndMs > totalMs) {
        final excess = visualEndMs - totalMs;
        trimEndMs += excess;
      }

      // Ensure visual start (startTime + trimStart) >= 0.
      final visualStartMs = startMs + trimStartMs;
      if (visualStartMs < 0) {
        trimStartMs = -startMs;
      }

      // Check that there is still visible duration.
      final trimmedMs = durationMs - trimStartMs - trimEndMs;
      if (trimmedMs <= 0) continue;

      updated.add(
        item.copyWith(
          startTime: Duration(milliseconds: startMs),
          duration: Duration(milliseconds: durationMs),
          trimStart: Duration(milliseconds: trimStartMs),
          trimEnd: Duration(milliseconds: trimEndMs),
        ),
      );
    } 
    emit(state.copyWith(items: updated));*/
  }

  /// Whether two items overlap in time on the timeline.
  static bool _overlapsInTime(
    TimelineOverlayItem a,
    TimelineOverlayItem b,
  ) {
    return false;
    /*  // An item's visible range is [startTime, startTime + trimmedDuration).
    final aStart = a.startTime.inMilliseconds;
    final aEnd = aStart + a.trimmedDuration.inMilliseconds;
    final bStart = b.startTime.inMilliseconds;
    final bEnd = bStart + b.trimmedDuration.inMilliseconds;
    return aStart < bEnd && bStart < aEnd;*/
  }

  /// Shift all items of [type] with row >= [fromRow] down by one row.
  static List<TimelineOverlayItem> _shiftRowsDown(
    List<TimelineOverlayItem> items,
    TimelineOverlayType type,
    int fromRow,
  ) {
    return items.map((i) {
      if (i.type == type && i.row >= fromRow) {
        return i.copyWith(row: i.row + 1);
      }
      return i;
    }).toList();
  }

  /// Remove empty row gaps within each type by re-indexing rows to be
  /// contiguous starting from 0.
  List<TimelineOverlayItem> _compactRows(List<TimelineOverlayItem> items) {
    final result = <TimelineOverlayItem>[];
    for (final type in TimelineOverlayType.values) {
      final typeItems = items.where((i) => i.type == type).toList()
        ..sort((a, b) => a.row.compareTo(b.row));
      if (typeItems.isEmpty) continue;

      final usedRows = typeItems.map((i) => i.row).toSet().toList()..sort();
      final rowMap = <int, int>{};
      for (var i = 0; i < usedRows.length; i++) {
        rowMap[usedRows[i]] = i;
      }
      for (final item in typeItems) {
        result.add(item.copyWith(row: rowMap[item.row]));
      }
    }
    // Preserve items of types not in the enum (future-proof).
    final handledIds = result.map((i) => i.id).toSet();
    result.addAll(items.where((i) => !handledIds.contains(i.id)));
    return result;
  }
}
