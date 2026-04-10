// ABOUTME: BLoC for managing overlay items (layers, filters, sounds) on the
// ABOUTME: video editor timeline. Handles add/remove/move/trim/select/drag
// ABOUTME: and collapse state for all three strip types.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/models/timeline_overlay_item.dart';

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
    on<TimelineOverlayItemAdded>(_onItemAdded);
    on<TimelineOverlayItemRemoved>(_onItemRemoved);
    on<TimelineOverlayItemMoved>(_onItemMoved);
    on<TimelineOverlayItemTrimmed>(_onItemTrimmed);
    on<TimelineOverlayItemSelected>(_onItemSelected);
    on<TimelineOverlayDragStarted>(_onDragStarted);
    on<TimelineOverlayDragEnded>(_onDragEnded);
    on<TimelineOverlayCollapseToggled>(_onCollapseToggled);
  }

  void _onItemAdded(
    TimelineOverlayItemAdded event,
    Emitter<TimelineOverlayState> emit,
  ) {
    emit(state.copyWith(items: [...state.items, event.item]));
  }

  void _onItemRemoved(
    TimelineOverlayItemRemoved event,
    Emitter<TimelineOverlayState> emit,
  ) {
    final updated = state.items.where((i) => i.id != event.itemId).toList();
    emit(
      state.copyWith(
        items: _compactRows(updated),
        clearSelectedItemId: state.selectedItemId == event.itemId,
        clearDraggingItemId: state.draggingItemId == event.itemId,
      ),
    );
  }

  void _onItemMoved(
    TimelineOverlayItemMoved event,
    Emitter<TimelineOverlayState> emit,
  ) {
    final updated = state.items.map((item) {
      if (item.id != event.itemId) return item;
      return item.copyWith(
        startTime: event.startTime ?? item.startTime,
        row: event.row ?? item.row,
      );
    }).toList();
    emit(state.copyWith(items: updated));
  }

  void _onItemTrimmed(
    TimelineOverlayItemTrimmed event,
    Emitter<TimelineOverlayState> emit,
  ) {
    // event.isStart distinguishes drag-start from drag-update.
    // Reserved for future undo support (see ClipEditorBloc pattern).
    final updated = state.items.map((item) {
      if (item.id != event.itemId) return item;
      return item.copyWith(
        trimStart: event.trimStart,
        trimEnd: event.trimEnd,
      );
    }).toList();
    emit(state.copyWith(items: updated));
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
