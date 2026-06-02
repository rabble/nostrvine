import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/extensions/video_editor_extensions.dart';
import 'package:openvine/extensions/video_editor_history_extensions.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_control_bar.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_timeline_clip_strip.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_timeline_overlay_strip.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_body.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_geometry.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_header.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_markers.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_playhead.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_volume.dart';

/// Interactive timeline editor for composing video clips.
///
/// Displays a scrollable ruler with time markers, clip thumbnail
/// strips, and a fixed-center playhead. Reads playback position and
/// duration from [VideoEditorMainBloc] and clip data from
/// [ClipEditorBloc].
class VideoEditorTimelineScaffold extends StatefulWidget {
  const VideoEditorTimelineScaffold({super.key});

  @override
  State<VideoEditorTimelineScaffold> createState() =>
      _VideoEditorTimelineState();
}

class _VideoEditorTimelineState extends State<VideoEditorTimelineScaffold> {
  /// Duration for the user-triggered timeline hide/show animation.
  static const _timelineToggleDuration = Duration(milliseconds: 220);

  late final ScrollController _scrollController;
  late final ScrollController _verticalScrollController;
  bool _isUserScrolling = false;

  double _pixelsPerSecond = TimelineConstants.pixelsPerSecond;

  /// Cached total duration from clip editor — used by scroll listeners
  /// that fire outside the build phase.
  Duration _totalDuration = Duration.zero;

  /// Playhead time derived from scroll offset — always matches the visual
  /// playhead regardless of zoom level.
  final _playheadPosition = ValueNotifier<Duration>(Duration.zero);
  final _volumePreviewNotifier = ValueNotifier<double?>(null);

  /// Active pointer positions — when ≥ 2 we compute pinch scale.
  final Map<int, Offset> _pointerPositions = {};

  /// Distance between two pointers when the pinch started.
  double _pinchBaseDistance = 0;

  /// [_pixelsPerSecond] captured when the pinch started.
  double _pinchBasePps = 0;

  bool get _isPinching => _pointerPositions.length >= 2;

  /// Throttle timestamp — limits BLoC event frequency during scrubbing.
  /// The native seek backpressure is handled by the canvas.
  int _lastSeekMs = 0;
  static const _seekThrottleMs = 16;

  /// Whether a trim handle drag is in progress — disables scroll physics.
  bool _isTrimming = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_updatePlayheadTime);
    _verticalScrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_updatePlayheadTime)
      ..dispose();
    _verticalScrollController.dispose();
    _playheadPosition.dispose();
    _volumePreviewNotifier.dispose();
    super.dispose();
  }

  double _contentWidth(Duration totalDuration) =>
      totalDuration.inMilliseconds / 1000.0 * _pixelsPerSecond;

  @override
  Widget build(BuildContext context) {
    final (:clips, :totalDuration, :isEditing, :currentClipIndex) = context
        .select(
          (ClipEditorBloc b) => (
            clips: b.state.clips,
            totalDuration: b.state.totalDuration,
            isEditing: b.state.isEditing,
            currentClipIndex: b.state.currentClipIndex,
          ),
        );
    if (clips.isEmpty) return const SizedBox.shrink();

    final trimmingClipId =
        isEditing && currentClipIndex >= 0 && currentClipIndex < clips.length
        ? clips[currentClipIndex].id
        : null;

    _totalDuration = totalDuration;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final halfScreen = screenWidth / 2;
    final totalWidth = _contentWidth(totalDuration);

    final hasSelectedOverlay = context.select(
      (TimelineOverlayBloc b) => b.state.selectedItemId != null,
    );

    final isTimelineHiddenByUser = context.select(
      (VideoEditorMainBloc b) => b.state.isTimelineHiddenByUser,
    );
    // Sync layers from main editor to timeline overlay bloc, and
    // sync scroll to playback position while not user-scrolling.
    return MultiBlocListener(
      listeners: [
        BlocListener<ClipEditorBloc, ClipEditorState>(
          listenWhen: (prev, curr) => prev.totalDuration != curr.totalDuration,
          listener: (context, state) {
            _totalDuration = state.totalDuration;
            context.read<TimelineOverlayBloc>().add(
              TimelineOverlayTotalDurationChanged(state.totalDuration),
            );
          },
        ),
        BlocListener<VideoEditorMainBloc, VideoEditorMainState>(
          listenWhen: (prev, curr) =>
              !_isUserScrolling && prev.currentPosition != curr.currentPosition,
          listener: (context, state) =>
              _syncScrollToPosition(state.currentPosition, totalDuration),
        ),
        BlocListener<VideoEditorMainBloc, VideoEditorMainState>(
          listenWhen: (prev, curr) =>
              !prev.isVolumeEditMode && curr.isVolumeEditMode,
          listener: (context, state) {
            final clipBloc = context.read<ClipEditorBloc>();
            if (clipBloc.state.isEditing) {
              clipBloc.add(const ClipEditorEditingToggled());
            }
            context.read<TimelineOverlayBloc>().add(
              const TimelineOverlayItemSelected(null),
            );
          },
        ),
        BlocListener<VideoEditorMainBloc, VideoEditorMainState>(
          listenWhen: (prev, curr) =>
              prev.isVolumeEditMode && !curr.isVolumeEditMode,
          listener: (context, state) {
            if (_verticalScrollController.hasClients) {
              _verticalScrollController.jumpTo(0);
            }
            _volumePreviewNotifier.value = null;
          },
        ),
        BlocListener<VideoEditorMainBloc, VideoEditorMainState>(
          listenWhen: (prev, curr) =>
              prev.isTimelineHiddenByUser != curr.isTimelineHiddenByUser,
          listener: (context, state) {
            final clipBloc = context.read<ClipEditorBloc>();
            if (clipBloc.state.isEditing) {
              clipBloc.add(const ClipEditorEditingToggled());
            }

            final bloc = context.read<TimelineOverlayBloc>();
            bloc.add(const TimelineOverlayItemSelected(null));
          },
        ),
      ],
      child: GestureDetector(
        onTap: isEditing || hasSelectedOverlay ? _onBackgroundTapped : null,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          alignment: .bottomCenter,
          children: [
            Column(
              crossAxisAlignment: .stretch,
              children: [
                VideoEditorTimelineHeader(
                  playheadPosition: _playheadPosition,
                  volumePreviewNotifier: _volumePreviewNotifier,
                ),
                const Padding(
                  padding: .only(top: 12),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: VineTheme.outlinedDisabled,
                  ),
                ),

                AnimatedContainer(
                  duration: _timelineToggleDuration,
                  height: isTimelineHiddenByUser
                      ? MediaQuery.viewPaddingOf(context).bottom
                      : TimelineConstants.height,
                  child: OverflowBox(
                    alignment: .topCenter,
                    minHeight: TimelineConstants.height,
                    maxHeight: TimelineConstants.height,
                    child: _TimelineInteractiveBody(
                      playheadPosition: _playheadPosition,
                      totalDuration: totalDuration,
                      formatPosition: (pos) {
                        final totalSeconds = pos.inMilliseconds / 1000.0;
                        final minutes = totalSeconds ~/ 60;
                        final seconds = (totalSeconds % 60).toStringAsFixed(1);
                        return context.l10n.videoEditorTimelinePositionFormat(
                          minutes,
                          seconds,
                        );
                      },
                      onStepPosition: _stepPosition,
                      onPointerDown: _onPointerDown,
                      onPointerMove: _onPointerMove,
                      onPointerUp: _onPointerUp,
                      onPointerCancel: _onPointerCancel,
                      onScrollNotification: _handleScrollNotification,
                      scrollController: _scrollController,
                      isPinching: _isPinching,
                      isTrimming: _isTrimming,
                      halfScreen: halfScreen,
                      pixelsPerSecond: _pixelsPerSecond,
                      clips: clips,
                      totalWidth: totalWidth,
                      isInteracting: _isUserScrolling || _isPinching,
                      onReorder: _onClipsReordered,
                      onReorderChanged: _onReorderChanged,
                      trimmingClipId: trimmingClipId,
                      onTrimChanged: _onClipTrimChange,
                      onTrimDragChanged: _onTrimDragChanged,
                      onClipTapped: _onClipTapped,
                      onOverlayItemMoved: _onOverlayItemMoved,
                      onOverlayItemMoving: _onOverlayItemMoving,
                      onOverlayItemTrimmed: _onOverlayItemTrimmed,
                      onOverlayTrimDragChanged: _onOverlayTrimDragChanged,
                      onOverlayItemTapped: _onOverlayItemTapped,
                      onOverlayDragStarted: _onOverlayDragStarted,
                      onOverlayDragEnded: _onOverlayDragEnded,
                      verticalScrollController: _verticalScrollController,
                      volumePreviewNotifier: _volumePreviewNotifier,
                    ),
                  ),
                ),
              ],
            ),

            TimelineControlsBar(
              isEditing: isEditing,
              playheadPosition: _playheadPosition,
            ),
          ],
        ),
      ),
    );
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _isUserScrolling = true;
      // Explicitly pause video while scrubbing so seekTo shows each frame.
      context.read<VideoEditorMainBloc>().add(
        const VideoEditorExternalPauseRequested(isPaused: true),
      );
    } else if (notification is ScrollUpdateNotification && _isUserScrolling) {
      _syncPositionFromScroll();
    } else if (notification is ScrollEndNotification) {
      if (_isUserScrolling) {
        _isUserScrolling = false;
        _syncPositionFromScroll(force: true);
      }
    }
    return false;
  }

  // -- Reorder callbacks ----------------------------------------------------

  void _onClipsReordered(List<DivineVideoClip> reorderedClips) {
    context.read<ClipEditorBloc>().add(ClipEditorInitialized(reorderedClips));
    context.read<VideoEditorMainBloc>().add(
      const VideoEditorExternalPauseRequested(isPaused: true),
    );
    // Persist reorder as a new history entry so it can be undone.
    final editor = VideoEditorScope.of(context).editor;
    editor?.setClipState(reorderedClips);
  }

  void _onReorderChanged(bool isReordering) {
    final bloc = context.read<VideoEditorMainBloc>();
    bloc.add(VideoEditorReorderingChanged(isReordering: isReordering));
    if (isReordering) {
      bloc.add(const VideoEditorExternalPauseRequested(isPaused: true));
      // Exit clip trim mode so handles disappear during reorder.
      final clipEditorBloc = context.read<ClipEditorBloc>();
      if (clipEditorBloc.state.isEditing) {
        clipEditorBloc.add(const ClipEditorEditingToggled());
      }
      // Deselect overlay item so trim handles disappear during reorder.
      context.read<TimelineOverlayBloc>().add(
        const TimelineOverlayItemSelected(null),
      );
    }
  }

  // -- Trim callbacks -------------------------------------------------------

  void _onClipTrimChange({
    required String clipId,
    required bool isStart,
    required Duration trimStart,
    required Duration trimEnd,
  }) {
    context.read<ClipEditorBloc>().add(
      ClipEditorTrimUpdated(
        clipId: clipId,
        isStart: isStart,
        trimStart: trimStart,
        trimEnd: trimEnd,
      ),
    );
  }

  void _onTrimDragChanged(bool isTrimming) {
    setState(() => _isTrimming = isTrimming);
    final editor = VideoEditorScope.of(context).requireEditor;
    final clipEditorBloc = context.read<ClipEditorBloc>();

    if (isTrimming) {
      clipEditorBloc.add(const ClipEditorTrimDragStarted());

      context.read<VideoEditorMainBloc>().add(
        const VideoEditorExternalPauseRequested(isPaused: true),
      );
    } else {
      clipEditorBloc.add(const ClipEditorTrimDragEnded());

      final clips = clipEditorBloc.state.clips.map((e) => e.toJson()).toList();

      editor.addHistory(
        meta: {
          ...editor.stateManager.activeMeta,
          VideoEditorConstants.clipsStateHistoryKey: clips,
        },
      );
    }
  }

  // -- Clip tap callback ----------------------------------------------------

  void _onClipTapped(int index) {
    // Deselect any overlay item when a clip is tapped.
    context.read<TimelineOverlayBloc>().add(
      const TimelineOverlayItemSelected(null),
    );

    final bloc = context.read<ClipEditorBloc>();
    final state = bloc.state;
    if (index == state.currentClipIndex) {
      // Same clip: toggle editing on/off.
      bloc.add(const ClipEditorEditingToggled());
    } else {
      // Different clip: select it and enter editing if not already active.
      bloc.add(ClipEditorClipSelected(index));
      if (!state.isEditing) {
        bloc.add(const ClipEditorEditingStarted());
      }
    }
  }

  void _onBackgroundTapped() {
    final bloc = context.read<ClipEditorBloc>();
    if (bloc.state.isEditing) {
      bloc.add(const ClipEditorEditingToggled());
    }
    // Deselect any overlay item.
    context.read<TimelineOverlayBloc>().add(
      const TimelineOverlayItemSelected(null),
    );
  }

  // -- Overlay callbacks ----------------------------------------------------

  void _onOverlayItemMoved({
    required TimelineOverlayItem item,
    required Duration startTime,
    required int row,
    required bool insertAbove,
  }) {
    // Sync the new time position to the editor before updating BLoC state so
    // the canvas reflects the move immediately.
    final editor = VideoEditorScope.of(context).requireEditor;
    final duration = item.duration;

    // Compute the correct list insertion index from current BLoC row
    // assignments. targetRow is a visual row number, but the editor
    // list may have multiple items per row (non-overlapping items
    // share rows). Using targetRow directly as a list index would
    // misplace the item.
    final targetIdx = _targetListIndex(
      type: item.type,
      draggedItemId: item.id,
      targetRow: row,
      insertAbove: insertAbove,
    );

    switch (item.type) {
      case .layer:
        final layers = editor.activeLayers;
        final layerIdx = layers.indexWhere((l) => l.id == item.id);

        editor.setLayerTimeline(
          index: layerIdx,
          startTime: startTime,
          endTime: startTime + duration,
          skipUpdateHistory: true,
        );

        // Reorder layers so the editor array matches the row order.
        // _assignRows derives rows from list position, so moving a
        // layer earlier/later in the list determines its row.
        _reorderEditorList(layers, layerIdx, targetIdx);

      case .filter:
        final filters = editor.stateManager.activeFilters;
        final filterIdx = filters.indexWhere((e) => e.id == item.id);

        editor.setFilterTimeline(
          index: filterIdx,
          startTime: startTime,
          endTime: startTime + duration,
          skipUpdateHistory: true,
        );

        _reorderEditorList(filters, filterIdx, targetIdx);

      case .sound:
        final audioTracks = editor.stateManager.audioTracks;
        final audioIdx = audioTracks.indexWhere((e) => e.id == item.id);

        editor.setSoundTimeline(
          index: audioIdx,
          startTime: startTime,
          endTime: startTime + duration,
          skipUpdateHistory: true,
        );

        _reorderEditorList(audioTracks, audioIdx, targetIdx);
    }

    context.read<TimelineOverlayBloc>().add(
      TimelineOverlayItemMoved(
        itemId: item.id,
        startTime: startTime,
        row: row,
        insertAbove: insertAbove,
      ),
    );
  }

  /// Returns the list index at which the dragged item should be
  /// inserted so that [_assignRows] places it on [targetRow].
  ///
  /// The BLoC items of the same [type] are in the same order as the
  /// editor list. By looking at their current row assignments we can
  /// map a visual row number to the correct list position — even when
  /// multiple non-overlapping items share a single row.
  ///
  /// The returned index is relative to the list *without* the dragged
  /// item (matching what [_reorderEditorList] has after `removeAt`).
  int _targetListIndex({
    required TimelineOverlayType type,
    required String draggedItemId,
    required int targetRow,
    required bool insertAbove,
  }) {
    final blocItems = context
        .read<TimelineOverlayBloc>()
        .state
        .items
        .where((i) => i.type == type && i.id != draggedItemId)
        .toList();

    if (insertAbove) {
      // Insert before the first item on or after targetRow.
      final idx = blocItems.indexWhere((i) => i.row >= targetRow);
      return idx == -1 ? blocItems.length : idx;
    } else {
      // Insert after the last item on or before targetRow.
      final idx = blocItems.lastIndexWhere((i) => i.row <= targetRow);
      return idx + 1;
    }
  }

  /// Reorders an editor list (layers, filters, audioTracks) so that the
  /// dragged element at [currentIdx] moves to [targetIdx].
  ///
  /// [targetIdx] is the insertion position in the list *after* removing
  /// the dragged element (computed by [_targetListIndex]).
  void _reorderEditorList<T>(List<T> list, int currentIdx, int targetIdx) {
    if (currentIdx < 0) return;

    final element = list.removeAt(currentIdx);
    list.insert(targetIdx.clamp(0, list.length), element);
  }

  void _onOverlayItemTrimmed({
    required TimelineOverlayItem item,
    required Duration startTime,
    required Duration endTime,
    required bool isStart,
  }) {
    final editor = VideoEditorScope.of(context).requireEditor;

    switch (item.type) {
      case .layer:
        final layers = editor.activeLayers;
        final layerIdx = layers.indexWhere((l) => l.id == item.id);

        editor.setLayerTimeline(
          index: layerIdx,
          startTime: startTime,
          endTime: endTime,
          skipUpdateHistory: true,
        );
      case .filter:
        final filters = editor.stateManager.activeFilters;
        final filterIdx = filters.indexWhere((e) => e.id == item.id);

        editor.setFilterTimeline(
          index: filterIdx,
          startTime: startTime,
          endTime: endTime,
          skipUpdateHistory: true,
        );
      case .sound:
        final audioTracks = editor.stateManager.audioTracks;
        final audioIdx = audioTracks.indexWhere((e) => e.id == item.id);

        editor.setSoundTimeline(
          index: audioIdx,
          startTime: startTime,
          endTime: endTime,
          skipUpdateHistory: true,
        );
    }

    context.read<TimelineOverlayBloc>().add(
      TimelineOverlayItemTrimmed(
        itemId: item.id,
        isStart: isStart,
        startTime: startTime,
        endTime: endTime,
      ),
    );
  }

  void _onOverlayTrimDragChanged(bool isTrimming) {
    setState(() => _isTrimming = isTrimming);
    final overlayBloc = context.read<TimelineOverlayBloc>();
    if (isTrimming) {
      // Snapshot history before the trim so undo restores the original
      // position — matches the pattern used by clip trim and overlay drag.
      VideoEditorScope.of(context).requireEditor.addHistory();
      context.read<VideoEditorMainBloc>().add(
        const VideoEditorExternalPauseRequested(isPaused: true),
      );
      final selectedId = overlayBloc.state.selectedItemId;
      if (selectedId != null) {
        overlayBloc.add(TimelineOverlayTrimStarted(selectedId));
      }
    } else {
      overlayBloc.add(const TimelineOverlayTrimEnded());
    }
  }

  void _onOverlayItemTapped(TimelineOverlayItem item) {
    // Exit clip editing when an overlay item is tapped.
    final clipBloc = context.read<ClipEditorBloc>();
    if (clipBloc.state.isEditing) {
      clipBloc.add(const ClipEditorEditingToggled());
    }

    final bloc = context.read<TimelineOverlayBloc>();
    if (bloc.state.selectedItemId == item.id) {
      bloc.add(const TimelineOverlayItemSelected(null));
    } else {
      bloc.add(TimelineOverlayItemSelected(item.id));
    }
  }

  void _onOverlayDragStarted(TimelineOverlayItem item) {
    // Snapshot history before the move so undo restores the original position.
    VideoEditorScope.of(context).requireEditor.addHistory();
    context.read<TimelineOverlayBloc>().add(
      TimelineOverlayDragStarted(item.id),
    );
    context.read<VideoEditorMainBloc>().add(
      const VideoEditorExternalPauseRequested(isPaused: true),
    );
  }

  void _onOverlayItemMoving({
    required TimelineOverlayItem item,
    required Duration startTime,
  }) {
    // Mirror the position live during drag so the canvas updates every frame,
    // just like trim does via setLayerTimeline/setFilterTimeline.
    final editor = VideoEditorScope.of(context).requireEditor;

    // Publish the live drag position to the BLoC so the canvas can
    // seek the player preview to the new startTime on every frame
    // (parallel to trimPosition for trim gestures).
    context.read<TimelineOverlayBloc>().add(
      TimelineOverlayDragMoved(startTime),
    );

    switch (item.type) {
      case .layer:
        final layers = editor.activeLayers;
        final layerIdx = layers.indexWhere((l) => l.id == item.id);

        editor.setLayerTimeline(
          index: layerIdx,
          startTime: startTime,
          endTime: startTime + item.duration,
          skipUpdateHistory: true,
        );
      case .filter:
        final filters = editor.stateManager.activeFilters;
        final filterIdx = filters.indexWhere((e) => e.id == item.id);

        editor.setFilterTimeline(
          index: filterIdx,
          startTime: startTime,
          endTime: startTime + item.duration,
          skipUpdateHistory: true,
        );
      case .sound:
        final audioTracks = editor.stateManager.audioTracks;
        final audioIdx = audioTracks.indexWhere((e) => e.id == item.id);

        editor.setSoundTimeline(
          index: audioIdx,
          startTime: startTime,
          endTime: startTime + item.duration,
          skipUpdateHistory: true,
        );
    }
  }

  void _onOverlayDragEnded() {
    context.read<TimelineOverlayBloc>().add(const TimelineOverlayDragEnded());
  }

  // -- Pointer tracking + manual pinch-to-zoom ------------------------------

  void _stepPosition(Duration current, Duration total, Duration step) {
    final ms = (current + step).inMilliseconds.clamp(0, total.inMilliseconds);
    final position = Duration(milliseconds: ms);
    context.read<VideoEditorMainBloc>().add(VideoEditorSeekRequested(position));
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointerPositions[event.pointer] = event.position;
    if (_pointerPositions.length == 2) {
      _pinchBaseDistance = _currentPointerDistance();
      _pinchBasePps = _pixelsPerSecond;
      setState(() {});
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_pointerPositions.containsKey(event.pointer)) return;
    _pointerPositions[event.pointer] = event.position;
    if (_pointerPositions.length >= 2 && _pinchBaseDistance > 0) {
      _updatePinchZoom();
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    final wasPinching = _isPinching;
    _pointerPositions.remove(event.pointer);
    _pinchBaseDistance = 0;
    if (wasPinching && !_isPinching) setState(() {});
  }

  void _onPointerCancel(PointerCancelEvent event) {
    final wasPinching = _isPinching;
    _pointerPositions.remove(event.pointer);
    _pinchBaseDistance = 0;
    if (wasPinching && !_isPinching) setState(() {});
  }

  double _currentPointerDistance() {
    final positions = _pointerPositions.values.toList();
    return (positions[0] - positions[1]).distance;
  }

  void _updatePinchZoom() {
    final currentDistance = _currentPointerDistance();
    final scale = currentDistance / _pinchBaseDistance;

    final newPps = (_pinchBasePps * scale).clamp(
      TimelineConstants.minPixelsPerSecond,
      TimelineConstants.maxPixelsPerSecond,
    );
    if (newPps == _pixelsPerSecond) return;

    // Anchor the zoom on the current playback position so inter-clip gaps
    // (which stay 1 px regardless of pixelsPerSecond) don't drift the
    // viewport off the playhead. Multiplying the raw scroll offset by the
    // zoom ratio would over-shoot by `clipsPassed × clipGap × (ratio - 1)`
    // px once the playhead is past clip 0.
    final clips = context.read<ClipEditorBloc>().state.clips;
    final anchorPosition = _scrollController.hasClients
        ? timelineScrollOffsetToPosition(
            clips,
            _scrollController.offset,
            _pixelsPerSecond,
            _totalDuration,
          )
        : Duration.zero;

    setState(() => _pixelsPerSecond = newPps);

    if (_scrollController.hasClients) {
      final newOffset = timelinePositionToScrollOffset(
        clips,
        anchorPosition,
        newPps,
      );
      _scrollController.jumpTo(
        newOffset.clamp(0, _scrollController.position.maxScrollExtent),
      );
    }
  }

  // -- Scroll ↔ position sync ------------------------------------------------

  /// Derives the time at the playhead from scroll offset.
  void _updatePlayheadTime() {
    if (!_scrollController.hasClients) return;
    _playheadPosition.value = _scrollOffsetToPosition(_scrollController.offset);
  }

  /// Converts a composite playback [position] to the corresponding scroll
  /// offset in the timeline content, accounting for the 1-px gap that
  /// [VideoEditorTimelineClipStrip] inserts between adjacent clips.
  ///
  /// Without this correction, the scroll target is up to
  /// `(clipIndex × clipGap)` pixels short of the trim-handle marker's
  /// actual visual position — noticeable at high zoom levels.
  double _positionToScrollOffset(Duration position) =>
      timelinePositionToScrollOffset(
        context.read<ClipEditorBloc>().state.clips,
        position,
        _pixelsPerSecond,
      );

  /// Inverse of [_positionToScrollOffset]: maps a [scrollOffset] back to a
  /// composite playback position, clamped to the current total duration.
  Duration _scrollOffsetToPosition(double scrollOffset) =>
      timelineScrollOffsetToPosition(
        context.read<ClipEditorBloc>().state.clips,
        scrollOffset,
        _pixelsPerSecond,
        _totalDuration,
      );

  void _syncScrollToPosition(Duration position, Duration totalDuration) {
    if (!_scrollController.hasClients) return;
    if (totalDuration == Duration.zero) return;

    final target = _positionToScrollOffset(position);
    final maxExtent = _scrollController.position.maxScrollExtent;
    _scrollController.animateTo(
      target.clamp(0, maxExtent),
      duration: const Duration(milliseconds: 200),
      curve: Curves.linear,
    );
  }

  void _syncPositionFromScroll({bool force = false}) {
    if (!_scrollController.hasClients) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!force && now - _lastSeekMs < _seekThrottleMs) return;
    _lastSeekMs = now;

    final position = _scrollOffsetToPosition(_scrollController.offset);
    context.read<VideoEditorMainBloc>().add(VideoEditorSeekRequested(position));
  }
}

class _TimelineInteractiveBody extends StatelessWidget {
  const _TimelineInteractiveBody({
    required this.playheadPosition,
    required this.totalDuration,
    required this.formatPosition,
    required this.onStepPosition,
    required this.onPointerDown,
    required this.onPointerMove,
    required this.onPointerUp,
    required this.onPointerCancel,
    required this.onScrollNotification,
    required this.scrollController,
    required this.isPinching,
    required this.isTrimming,
    required this.halfScreen,
    required this.pixelsPerSecond,
    required this.clips,
    required this.totalWidth,
    required this.isInteracting,
    required this.onReorder,
    required this.onReorderChanged,
    required this.trimmingClipId,
    required this.onTrimChanged,
    required this.onTrimDragChanged,
    required this.onClipTapped,
    required this.onOverlayItemMoved,
    required this.onOverlayItemMoving,
    required this.onOverlayItemTrimmed,
    required this.onOverlayTrimDragChanged,
    required this.onOverlayItemTapped,
    required this.onOverlayDragStarted,
    required this.onOverlayDragEnded,
    required this.verticalScrollController,
    required this.volumePreviewNotifier,
  });

  final ValueNotifier<Duration> playheadPosition;
  final Duration totalDuration;
  final String Function(Duration) formatPosition;
  final void Function(Duration, Duration, Duration) onStepPosition;
  final PointerDownEventListener onPointerDown;
  final PointerMoveEventListener onPointerMove;
  final PointerUpEventListener onPointerUp;
  final PointerCancelEventListener onPointerCancel;
  final bool Function(ScrollNotification) onScrollNotification;
  final ScrollController scrollController;
  final bool isPinching;
  final bool isTrimming;
  final double halfScreen;
  final double pixelsPerSecond;
  final List<DivineVideoClip> clips;
  final double totalWidth;
  final bool isInteracting;
  final void Function(List<DivineVideoClip>) onReorder;
  final ValueChanged<bool> onReorderChanged;
  final String? trimmingClipId;
  final ClipTrimCallback onTrimChanged;
  final ValueChanged<bool> onTrimDragChanged;
  final ValueChanged<int> onClipTapped;
  final OverlayMoveCallback onOverlayItemMoved;
  final OverlayMovingCallback onOverlayItemMoving;
  final OverlayTrimCallback onOverlayItemTrimmed;
  final ValueChanged<bool> onOverlayTrimDragChanged;
  final ValueChanged<TimelineOverlayItem> onOverlayItemTapped;
  final ValueChanged<TimelineOverlayItem> onOverlayDragStarted;
  final VoidCallback onOverlayDragEnded;
  final ScrollController verticalScrollController;
  final ValueNotifier<double?> volumePreviewNotifier;

  @override
  Widget build(BuildContext context) {
    final isVolumeEditMode = context.select(
      (VideoEditorMainBloc b) => b.state.isVolumeEditMode,
    );
    final soundItemCount = context.select(
      (TimelineOverlayBloc b) => b.state.items
          .where((i) => i.type == TimelineOverlayType.sound)
          .length,
    );
    final rawVolumeContentHeight =
        TimelineConstants.rulerHeight +
        4 +
        clips.length *
            (TimelineConstants.thumbnailStripHeight +
                TimelineConstants.thumbnailVerticalRowGap) -
        TimelineConstants.thumbnailVerticalRowGap +
        4 +
        TimelineConstants.overlayStripGap +
        soundItemCount * TimelineConstants.soundOverlayRowHeight;
    final volumeContentHeight =
        rawVolumeContentHeight > TimelineConstants.height
        ? rawVolumeContentHeight
        : TimelineConstants.height;

    return Stack(
      fit: .expand,
      children: [
        SingleChildScrollView(
          controller: verticalScrollController,
          physics: isVolumeEditMode
              ? const ClampingScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          child: ClipRect(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              height: isVolumeEditMode
                  ? volumeContentHeight
                  : TimelineConstants.height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ValueListenableBuilder<Duration>(
                    valueListenable: playheadPosition,
                    builder: (context, position, child) {
                      final increased = Duration(
                        milliseconds: (position + const Duration(seconds: 1))
                            .inMilliseconds
                            .clamp(0, totalDuration.inMilliseconds),
                      );
                      final decreased = Duration(
                        milliseconds: (position - const Duration(seconds: 1))
                            .inMilliseconds
                            .clamp(0, totalDuration.inMilliseconds),
                      );
                      return Semantics(
                        label:
                            context.l10n.videoEditorVideoTimelineSemanticLabel,
                        slider: true,
                        value: formatPosition(position),
                        increasedValue: formatPosition(increased),
                        decreasedValue: formatPosition(decreased),
                        onIncrease: () => onStepPosition(
                          position,
                          totalDuration,
                          const Duration(seconds: 1),
                        ),
                        onDecrease: () => onStepPosition(
                          position,
                          totalDuration,
                          const Duration(seconds: -1),
                        ),
                        child: child ?? const SizedBox.shrink(),
                      );
                    },
                    child: Listener(
                      onPointerDown: onPointerDown,
                      onPointerMove: onPointerMove,
                      onPointerUp: onPointerUp,
                      onPointerCancel: onPointerCancel,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: onScrollNotification,
                        child: SingleChildScrollView(
                          controller: scrollController,
                          scrollDirection: Axis.horizontal,
                          physics: isPinching || isTrimming
                              ? const NeverScrollableScrollPhysics()
                              : const ClampingScrollPhysics(),
                          clipBehavior: .none,
                          padding: .symmetric(horizontal: halfScreen),
                          child: VideoEditorTimelineBody(
                            totalDuration: totalDuration,
                            pixelsPerSecond: pixelsPerSecond,
                            scrollController: scrollController,
                            scrollPadding: halfScreen,
                            clips: clips,
                            totalWidth: totalWidth,
                            isInteracting: isInteracting,
                            onReorder: onReorder,
                            onReorderChanged: onReorderChanged,
                            trimmingClipId: trimmingClipId,
                            onTrimChanged: onTrimChanged,
                            onTrimDragChanged: onTrimDragChanged,
                            onClipTapped: isVolumeEditMode
                                ? null
                                : onClipTapped,
                            onOverlayItemMoved: onOverlayItemMoved,
                            onOverlayItemMoving: onOverlayItemMoving,
                            onOverlayItemTrimmed: onOverlayItemTrimmed,
                            onOverlayTrimDragChanged: onOverlayTrimDragChanged,
                            onOverlayItemTapped: isVolumeEditMode
                                ? null
                                : onOverlayItemTapped,
                            onOverlayDragStarted: onOverlayDragStarted,
                            onOverlayDragEnded: onOverlayDragEnded,
                            playheadPosition: playheadPosition,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    child: ClipRect(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        transitionBuilder: (child, animation) =>
                            SlideTransition(
                              position:
                                  Tween<Offset>(
                                    begin: const Offset(-1.0, 0.0),
                                    end: Offset.zero,
                                  ).animate(
                                    CurvedAnimation(
                                      parent: animation,
                                      curve: Curves.easeInOut,
                                    ),
                                  ),
                              child: child,
                            ),
                        layoutBuilder: (currentChild, previousChildren) =>
                            Stack(
                              alignment: Alignment.centerLeft,
                              children: <Widget>[
                                ...previousChildren,
                                ?currentChild,
                              ],
                            ),
                        child: isVolumeEditMode
                            ? VideoEditorTimelineVolume(
                                key: const ValueKey('volume'),
                                volumePreviewNotifier: volumePreviewNotifier,
                              )
                            : const SizedBox.shrink(key: ValueKey('empty')),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        VideoEditorTimelineMarkers(
          scrollController: scrollController,
          scrollPadding: halfScreen,
          pixelsPerSecond: pixelsPerSecond,
        ),
        const VideoEditorTimelinePlayhead(),
      ],
    );
  }
}
