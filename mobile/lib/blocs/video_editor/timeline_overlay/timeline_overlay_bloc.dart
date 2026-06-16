// ABOUTME: BLoC for managing overlay items (layers, filters, sounds) on the
// ABOUTME: video editor timeline. Handles add/remove/move/trim/select/drag
// ABOUTME: and collapse state for all three strip types.

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
    on<TimelineOverlayItemMoved>(_onItemMoved);
    on<TimelineOverlayItemTrimmed>(_onItemTrimmed);
    on<TimelineOverlayItemSelected>(_onItemSelected);
    on<TimelineOverlayDragStarted>(_onDragStarted);
    on<TimelineOverlayDragMoved>(_onDragMoved);
    on<TimelineOverlayDragEnded>(_onDragEnded);
    on<TimelineOverlayTrimStarted>(_onTrimStarted);
    on<TimelineOverlayTrimEnded>(_onTrimEnded);
    on<TimelineOverlayCollapseToggled>(_onCollapseToggled);
    on<TimelineOverlayTotalDurationChanged>(_onTotalDurationChanged);
    on<TimelineMarkerAdded>(_onMarkerAdded);
    on<TimelineMarkerRemoved>(_onMarkerRemoved);
    on<TimelineMarkersRebased>(_onMarkersRebased);
    on<TimelineOverlayWaveformLoaded>(_onWaveformLoaded);
    on<TimelineOverlayAnchoredAudioRebased>(_onAnchoredAudioRebased);
    on<TimelineOverlayAudioVolumeChanged>(
      _onAudioVolumeChanged,
      transformer: sequential(),
    );
    on<TimelineOverlayAllAudioVolumeChanged>(
      _onAllAudioVolumeChanged,
      transformer: sequential(),
    );
  }

  static const _markerMatchTolerance = Duration(milliseconds: 50);

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
        _soundItem(
          track,
          total: total,
          leftChannel: leftCache[track.id],
          rightChannel: rightCache[track.id],
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

    // Detect volume-only differences from undo/redo restores.
    // AudioEvent.== excludes volume, so Equatable would otherwise suppress the
    // emit when only volumes changed. Incrementing audioTracksPlayerRevision
    // makes the state distinct without touching audioTracksRevision (which
    // would trigger the write-to-history listener and corrupt the undo stack).
    final currentVolumes = {
      for (final t in state.audioTracks) t.id: t.volume,
    };
    final volumeRestoredByUndo = event.audioTracks.any(
      (t) =>
          currentVolumes.containsKey(t.id) && currentVolumes[t.id] != t.volume,
    );

    emit(
      state.copyWith(
        items: newItems,
        audioTracks: event.audioTracks,
        clearSelectedItemId: !selectedStillExists,
        // Preserve draggingItemId/trimmingItemId when active so the
        // BlocListener in the canvas doesn't fire mid-gesture.
        clearDraggingItemId: state.draggingItemId == null,
        clearTrimmingItemId: state.trimmingItemId == null,
        audioTracksPlayerRevision: volumeRestoredByUndo
            ? state.audioTracksPlayerRevision + 1
            : state.audioTracksPlayerRevision,
        timelineMarkers: _clampMarkers(event.timelineMarkers, total),
      ),
    );
  }

  /// Builds the timeline item for one audio [track].
  ///
  /// [maxDuration] (remaining audio after [TimelineOverlayItem.startOffset])
  /// is derived from the same full-source basis as
  /// [TimelineOverlayItem.sourceDuration] so the two never drift — the same
  /// `sourceDuration - startOffset` relationship [_onItemTrimmed] applies
  /// live during a trim drag.
  static TimelineOverlayItem _soundItem(
    AudioEvent track, {
    required Duration total,
    Float32List? leftChannel,
    Float32List? rightChannel,
  }) {
    final sourceDuration = track.duration != null
        ? Duration(milliseconds: (track.duration! * 1000).round())
        : null;

    return TimelineOverlayItem(
      id: track.id,
      type: .sound,
      startTime: track.startTime,
      endTime: _clampEnd(track.endTime ?? .zero, total),
      label: track.title ?? track.pubkey,
      maxDuration: sourceDuration != null
          ? sourceDuration - track.startOffset
          : VideoEditorConstants.maxDuration,
      sourceDuration: sourceDuration,
      startOffset: track.startOffset,
      waveformLeftChannel: leftChannel,
      waveformRightChannel: rightChannel,
      audioSource: track.isOriginalSound
          ? AudioSource.original
          : AudioSource.custom,
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
    final newStartOffset = event.startOffset ?? item.startOffset;

    // A left-trim advances the source offset. The full item refresh from
    // editor history (which recomputes maxDuration) does not run mid-drag, so
    // keep maxDuration in step here too — otherwise the live waveform window
    // (and the trim move-conversion) would read a stale remaining-audio value.
    final newMaxDuration =
        event.startOffset != null && item.sourceDuration != null
        ? item.sourceDuration! - newStartOffset
        : item.maxDuration;

    items[idx] = item.copyWith(
      startTime: newStart,
      endTime: newEnd,
      startOffset: newStartOffset,
      maxDuration: newMaxDuration,
    );

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

    emit(
      state.copyWith(
        items: _recalculateRows(updated),
        timelineMarkers: _clampMarkers(state.timelineMarkers, totalDuration),
      ),
    );
  }

  void _onMarkerAdded(
    TimelineMarkerAdded event,
    Emitter<TimelineOverlayState> emit,
  ) {
    if (event.totalDuration <= Duration.zero) return;

    final clampedPosition = _clampDuration(
      event.position,
      event.totalDuration,
    );
    final markers = List<Duration>.from(state.timelineMarkers);
    final alreadyExists = markers.any(
      (marker) => (marker - clampedPosition).abs() <= _markerMatchTolerance,
    );

    if (alreadyExists) return;

    markers.add(clampedPosition);
    markers.sort();
    emit(
      state.copyWith(
        timelineMarkers: markers,
        timelineMarkersRevision: state.timelineMarkersRevision + 1,
      ),
    );
  }

  void _onMarkerRemoved(
    TimelineMarkerRemoved event,
    Emitter<TimelineOverlayState> emit,
  ) {
    final markers = List<Duration>.from(state.timelineMarkers);
    final existingIndex = markers.indexWhere(
      (marker) => (marker - event.position).abs() <= _markerMatchTolerance,
    );

    if (existingIndex == -1) return;

    markers.removeAt(existingIndex);
    markers.sort();
    emit(
      state.copyWith(
        timelineMarkers: markers,
        timelineMarkersRevision: state.timelineMarkersRevision + 1,
      ),
    );
  }

  void _onMarkersRebased(
    TimelineMarkersRebased event,
    Emitter<TimelineOverlayState> emit,
  ) {
    final markers = event.markers.toSet().toList()..sort();
    emit(state.copyWith(timelineMarkers: markers));
  }

  static List<Duration> _clampMarkers(
    List<Duration> markers,
    Duration totalDuration,
  ) {
    final clamped = {
      for (final marker in markers) _clampDuration(marker, totalDuration),
    }.toList()..sort();
    return clamped;
  }

  static Duration _clampDuration(Duration value, Duration max) {
    if (value < Duration.zero) return Duration.zero;
    if (value > max) return max;
    return value;
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

  void _onAnchoredAudioRebased(
    TimelineOverlayAnchoredAudioRebased event,
    Emitter<TimelineOverlayState> emit,
  ) {
    final byId = {for (final track in event.audioTracks) track.id: track};

    var changed = false;
    final updatedItems = <TimelineOverlayItem>[];
    for (final item in state.items) {
      final track = item.type == TimelineOverlayType.sound
          ? byId[item.id]
          : null;
      if (track == null) {
        updatedItems.add(item);
        continue;
      }
      final newEnd = track.endTime ?? item.endTime;
      if (item.startTime == track.startTime && item.endTime == newEnd) {
        updatedItems.add(item);
        continue;
      }
      changed = true;
      updatedItems.add(
        item.copyWith(startTime: track.startTime, endTime: newEnd),
      );
    }

    // Visual-only live update: positions move with the trim, but rows,
    // audioTracks, history, and the native player are left untouched and
    // reconciled on release. Skip the emit when nothing moved.
    if (!changed) return;
    emit(state.copyWith(items: updatedItems));
  }

  void _onAudioVolumeChanged(
    TimelineOverlayAudioVolumeChanged event,
    Emitter<TimelineOverlayState> emit,
  ) {
    final index = state.audioTracks.indexWhere(
      (track) => track.id == event.trackId,
    );
    if (index == -1) return;
    final nextVolume = event.volume.clamp(0.0, 1.0);
    if (state.audioTracks[index].volume == nextVolume) return;
    final updated = List<AudioEvent>.of(state.audioTracks);
    updated[index] = updated[index].copyWith(volume: nextVolume);
    emit(
      state.copyWith(
        audioTracks: updated,
        audioTracksRevision: state.audioTracksRevision + 1,
      ),
    );
  }

  void _onAllAudioVolumeChanged(
    TimelineOverlayAllAudioVolumeChanged event,
    Emitter<TimelineOverlayState> emit,
  ) {
    final nextVolume = event.volume.clamp(0.0, 1.0);
    final affected = state.audioTracks.where(
      (t) => !t.isClipAnchoredOriginalSound,
    );
    if (affected.isEmpty) return;
    if (affected.every((t) => t.volume == nextVolume)) return;
    final updated = state.audioTracks
        .map(
          (t) => t.isClipAnchoredOriginalSound
              ? t
              : t.copyWith(volume: nextVolume),
        )
        .toList(growable: false);
    emit(
      state.copyWith(
        audioTracks: updated,
        audioTracksRevision: state.audioTracksRevision + 1,
      ),
    );
  }
}
