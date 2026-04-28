// ABOUTME: BLoC for managing overlay items (layers, filters, sounds) on the
// ABOUTME: video editor timeline. Handles add/remove/move/trim/select/drag
// ABOUTME: and collapse state for all three strip types.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

part 'timeline_overlay_event.dart';
part 'timeline_overlay_state.dart';

/// Manages overlay items (layers, filters, sounds) on the timeline.
///
/// Each item lives in a typed strip and can be repositioned in time
/// (horizontal) and in z-order / row (vertical). Rows are created
/// dynamically when items are dragged beyond existing rows.
///
/// **Transition seam**: Waveform extraction is currently triggered from the
/// widget layer (which calls into [ProVideoEditor] and dispatches
/// [TimelineOverlayWaveformLoaded]). The target architecture moves this
/// I/O behind an injected service so the BLoC owns the full lifecycle.
/// See the follow-up migration issue.
class TimelineOverlayBloc
    extends Bloc<TimelineOverlayEvent, TimelineOverlayState> {
  TimelineOverlayBloc() : super(const TimelineOverlayState()) {
    on<TimelineOverlayItemsUpdate>(_onUpdateItems);
    on<TimelineOverlayItemMoved>(_onItemMoved, transformer: restartable());
    on<TimelineOverlayItemTrimmed>(_onItemTrimmed, transformer: restartable());
    on<TimelineOverlayItemSelected>(_onItemSelected);
    on<TimelineOverlayDragStarted>(_onDragStarted);
    on<TimelineOverlayDragMoved>(_onDragMoved);
    on<TimelineOverlayDragEnded>(_onDragEnded);
    on<TimelineOverlayTrimStarted>(_onTrimStarted);
    on<TimelineOverlayTrimEnded>(_onTrimEnded);
    on<TimelineOverlayCollapseToggled>(_onCollapseToggled);
    on<TimelineOverlayTotalDurationChanged>(_onTotalDurationChanged);
    on<TimelineOverlayWaveformLoaded>(_onWaveformLoaded);
  }

  void _onUpdateItems(
    TimelineOverlayItemsUpdate event,
    Emitter<TimelineOverlayState> emit,
  ) {
    // Cache waveform data from previous state so we don't lose it
    // when items are rebuilt.
    final leftCache = <String, Float32List>{
      for (final item in state.items)
        if (item.waveformLeftChannel != null)
          item.id: item.waveformLeftChannel!,
    };
    final rightCache = <String, Float32List>{
      for (final item in state.items)
        if (item.waveformRightChannel != null)
          item.id: item.waveformRightChannel!,
    };

    final total = event.totalVideoDuration;

    final sounds = <TimelineOverlayItem>[
      for (final track in event.audioTracks)
        TimelineOverlayItem(
          id: track.id,
          type: .sound,
          startTime: track.startTime,
          endTime: _clampEnd(track.endTime ?? .zero, total),
          label: track.title ?? track.pubkey,
          maxDuration: track.duration != null
              ? Duration(
                  milliseconds: math.min(
                    (track.duration! * 1000).round() -
                        track.startOffset.inMilliseconds,
                    VideoEditorConstants.maxDuration.inMilliseconds,
                  ),
                )
              : VideoEditorConstants.maxDuration,
          waveformLeftChannel: leftCache[track.id],
          waveformRightChannel: rightCache[track.id],
        ),
    ];

    final filters = <TimelineOverlayItem>[
      for (var i = 0; i < event.filters.length; i++)
        // Skip no-op FilterStates (empty matrices) that are inserted by
        // _removeFilter to "clear" the filter in the editor history.
        if (event.filters[i].isNotEmpty)
          TimelineOverlayItem(
            id: event.filters[i].id,
            type: .filter,
            startTime: event.filters[i].startTime ?? .zero,
            endTime: _clampEnd(event.filters[i].endTime ?? total, total),
            label: event.filters[i].name,
          ),
    ];

    final layers = <TimelineOverlayItem>[
      for (final layer in event.layers)
        TimelineOverlayItem(
          id: layer.id,
          type: .layer,
          startTime: layer.startTime ?? .zero,
          endTime: _clampEnd(layer.endTime ?? total, total),
          label: _labelForLayer(layer),
          layer: layer,
        ),
    ];

    final newItems = [
      ..._assignRows(sounds),
      ..._assignRows(filters),
      ..._assignRows(layers),
    ];

    // Only clear selection if the selected item no longer exists.
    final selectedStillExists =
        state.selectedItemId != null &&
        newItems.any((i) => i.id == state.selectedItemId);

    emit(
      state.copyWith(
        items: newItems,
        audioTracks: event.audioTracks,
        clearSelectedItemId: !selectedStillExists,
        // Preserve draggingItemId/trimmingItemId when active so the
        // BlocListener in the canvas doesn't fire mid-gesture.
        clearDraggingItemId: state.draggingItemId == null,
        clearTrimmingItemId: state.trimmingItemId == null,
      ),
    );
  }

  /// Gently compacts rows for items that already have row assignments.
  ///
  /// Groups items by [TimelineOverlayType] and runs [_compactRows]
  /// independently per type.
  static List<TimelineOverlayItem> _recalculateRows(
    List<TimelineOverlayItem> items,
  ) {
    final grouped = <TimelineOverlayType, List<TimelineOverlayItem>>{};
    for (final item in items) {
      (grouped[item.type] ??= []).add(item);
    }
    return [for (final group in grouped.values) ..._compactRows(group)];
  }

  /// Compacts rows gradually.
  ///
  /// 0. Resolve same-row overlaps by pushing the later item down.
  /// 1. Completely empty rows are collapsed (items shift through).
  /// 2. Each item may then shift up by at most **one** row if
  ///    its target row has no temporal overlap.
  ///
  /// Items are processed from lowest to highest row so upstream
  /// moves can cascade within a single pass.
  static List<TimelineOverlayItem> _compactRows(
    List<TimelineOverlayItem> items,
  ) {
    if (items.isEmpty) return items;

    // Step 0: Resolve same-row overlaps.
    // Process items from lowest row upward. When two items on the
    // same row overlap, push the later-added one down.
    final resolved = List<TimelineOverlayItem>.from(items);
    for (var i = 0; i < resolved.length; i++) {
      for (var j = i + 1; j < resolved.length; j++) {
        final a = resolved[i];
        final b = resolved[j];
        if (a.row == b.row &&
            a.startTime < b.endTime &&
            b.startTime < a.endTime) {
          resolved[j] = b.copyWith(row: b.row + 1);
        }
      }
    }

    // Step 1: Collapse completely empty rows.
    final usedRows = <int>{for (final item in resolved) item.row};
    final sortedUsed = usedRows.toList()..sort();
    final rowMap = {
      for (var i = 0; i < sortedUsed.length; i++) sortedUsed[i]: i,
    };
    final result = [
      for (final item in resolved) item.copyWith(row: rowMap[item.row]),
    ];

    // Step 2: Try to shift each item up by 1 row if no overlap.
    // Process from lowest row first so cascading works naturally.
    result.sort((a, b) => a.row.compareTo(b.row));
    for (var i = 0; i < result.length; i++) {
      final item = result[i];
      if (item.row <= 0) continue;

      final hasOverlap = result.any(
        (other) =>
            other.id != item.id &&
            other.row == item.row - 1 &&
            item.startTime < other.endTime &&
            other.startTime < item.endTime,
      );
      if (!hasOverlap) {
        result[i] = item.copyWith(row: item.row - 1);
      }
    }

    return result;
  }

  /// Packs items into the fewest rows while preserving list order.
  ///
  /// An item's row must be strictly greater than the row of any
  /// temporally overlapping item that was placed before it. This
  /// prevents items from visually "jumping over" earlier items.
  /// Non-overlapping items can share a row.
  static List<TimelineOverlayItem> _assignRows(
    List<TimelineOverlayItem> items,
  ) {
    if (items.isEmpty) return items;

    final result = <TimelineOverlayItem>[];

    for (final item in items) {
      var row = 0;
      for (final placed in result) {
        if (item.startTime < placed.endTime &&
            placed.startTime < item.endTime &&
            placed.row >= row) {
          row = placed.row + 1;
        }
      }
      result.add(item.copyWith(row: row));
    }

    return result;
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
          i.startTime < moved.endTime &&
          moved.startTime < i.endTime,
    );

    if (hasOverlap) {
      if (event.insertAbove) {
        // Keep the moved item at its row; push existing items down.
        items = _shiftRowsDown(items, moved.type, moved.row, moved.id);
        items[idx] = moved;
      } else {
        // Place the moved item one row below; push existing items down.
        final targetRow = moved.row + 1;
        items = _shiftRowsDown(items, moved.type, targetRow, moved.id);
        items[idx] = moved.copyWith(row: targetRow);
      }
    } else {
      items[idx] = moved;
    }

    emit(state.copyWith(items: items));
  }

  /// Shift all items of [type] with row >= [fromRow] down by one row,
  /// excluding the item with [excludeId].
  static List<TimelineOverlayItem> _shiftRowsDown(
    List<TimelineOverlayItem> items,
    TimelineOverlayType type,
    int fromRow,
    String excludeId,
  ) {
    return items.map((i) {
      if (i.id != excludeId && i.type == type && i.row >= fromRow) {
        return i.copyWith(row: i.row + 1);
      }
      return i;
    }).toList();
  }

  void _onItemTrimmed(
    TimelineOverlayItemTrimmed event,
    Emitter<TimelineOverlayState> emit,
  ) {
    final items = List<TimelineOverlayItem>.from(state.items);
    final idx = items.indexWhere((i) => i.id == event.itemId);
    if (idx == -1) return;

    final item = items[idx];

    final newStart = event.startTime ?? item.startTime;
    final newEnd = event.endTime ?? item.endTime;

    items[idx] = item.copyWith(startTime: newStart, endTime: newEnd);

    // Only re-assign rows for the changed type; other types are unaffected.
    final changedType = item.type;
    final unchanged = items.where((el) => el.type != changedType).toList();
    final reassigned = _assignRows(
      items.where((el) => el.type == changedType).toList(),
    );

    emit(
      state.copyWith(
        items: [...unchanged, ...reassigned],
        trimPosition: event.isStart ? newStart : newEnd,
      ),
    );
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

  void _onDragMoved(
    TimelineOverlayDragMoved event,
    Emitter<TimelineOverlayState> emit,
  ) {
    if (state.draggingItemId == null) return;
    emit(state.copyWith(dragPosition: event.position));
  }

  void _onDragEnded(
    TimelineOverlayDragEnded event,
    Emitter<TimelineOverlayState> emit,
  ) {
    // Compact rows so there are no empty gaps.
    emit(
      state.copyWith(
        items: _recalculateRows(state.items),
        clearDraggingItemId: true,
        clearDragPosition: true,
      ),
    );
  }

  void _onTrimStarted(
    TimelineOverlayTrimStarted event,
    Emitter<TimelineOverlayState> emit,
  ) {
    emit(state.copyWith(trimmingItemId: event.itemId));
  }

  void _onTrimEnded(
    TimelineOverlayTrimEnded event,
    Emitter<TimelineOverlayState> emit,
  ) {
    emit(
      state.copyWith(
        items: _recalculateRows(state.items),
        clearTrimmingItemId: true,
        clearTrimPosition: true,
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
    final totalDuration = event.totalDuration;
    if (totalDuration <= Duration.zero) return;

    final updated = <TimelineOverlayItem>[];
    for (final item in state.items) {
      if (item.startTime >= totalDuration) continue;

      final clampedEnd = _clampEnd(item.endTime, totalDuration);
      if (clampedEnd <= item.startTime) continue;

      updated.add(
        clampedEnd == item.endTime ? item : item.copyWith(endTime: clampedEnd),
      );
    }

    emit(state.copyWith(items: _recalculateRows(updated)));
  }

  /// Returns [endTime] clamped to [totalDuration].
  static Duration _clampEnd(Duration endTime, Duration totalDuration) =>
      endTime > totalDuration ? totalDuration : endTime;

  void _onWaveformLoaded(
    TimelineOverlayWaveformLoaded event,
    Emitter<TimelineOverlayState> emit,
  ) {
    final updated = [
      for (final item in state.items)
        if (item.id == event.itemId)
          item.copyWith(
            waveformLeftChannel: event.leftChannel,
            waveformRightChannel: event.rightChannel,
          )
        else
          item,
    ];
    emit(state.copyWith(items: updated));
  }
}
