import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/filter_editor/video_editor_filter_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/hit_expanded_box.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_timeline_clip_strip.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_timeline_overlay_strip.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_header.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_playhead.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_rules_indicator.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show EmojiLayer, PaintLayer, TextLayer, WidgetLayer;
import 'package:pro_image_editor/pro_image_editor.dart' as pie;

/// Interactive timeline editor for composing video clips.
///
/// Displays a scrollable ruler with time markers, clip thumbnail
/// strips, and a fixed-center playhead. Reads playback position and
/// duration from [VideoEditorMainBloc] and clip data from
/// [ClipEditorBloc].
class VideoEditorTimeline extends ConsumerStatefulWidget {
  const VideoEditorTimeline({super.key});

  @override
  ConsumerState<VideoEditorTimeline> createState() =>
      _VideoEditorTimelineState();
}

class _VideoEditorTimelineState extends ConsumerState<VideoEditorTimeline> {
  late final ScrollController _scrollController;
  bool _isUserScrolling = false;

  double _pixelsPerSecond = TimelineConstants.pixelsPerSecond;

  /// Cached total duration from clip editor — used by scroll listeners
  /// that fire outside the build phase.
  Duration _totalDuration = Duration.zero;

  /// Playhead time derived from scroll offset — always matches the visual
  /// playhead regardless of zoom level.
  final _playheadPosition = ValueNotifier<Duration>(Duration.zero);

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

    // Sync filter state that may have changed while the timeline was unmounted
    // (e.g. a filter was applied in the sub-editor).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final filterState = context.read<VideoEditorFilterBloc>().state;
      final totalDuration = context.read<ClipEditorBloc>().state.totalDuration;
      _syncFilterToOverlay(context, filterState, totalDuration);
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_updatePlayheadTime)
      ..dispose();
    _playheadPosition.dispose();
    super.dispose();
  }

  double _contentWidth(Duration totalDuration) =>
      totalDuration.inMilliseconds / 1000.0 * _pixelsPerSecond;

  @override
  Widget build(BuildContext context) {
    final clips = context.select(
      (ClipEditorBloc b) => b.state.clips,
    );
    if (clips.isEmpty) return const SizedBox.shrink();

    return BlocSelector<VideoEditorMainBloc, VideoEditorMainState, bool>(
      selector: (state) => state.isReordering,
      builder: (context, isReordering) {
        final totalDuration = context.select(
          (ClipEditorBloc b) => b.state.totalDuration,
        );
        final isEditing = context.select(
          (ClipEditorBloc b) => b.state.isEditing,
        );
        final currentClipIndex = context.select(
          (ClipEditorBloc b) => b.state.currentClipIndex,
        );
        final trimmingClipId =
            isEditing &&
                currentClipIndex >= 0 &&
                currentClipIndex < clips.length
            ? clips[currentClipIndex].id
            : null;

        _totalDuration = totalDuration;
        final screenWidth = MediaQuery.sizeOf(context).width;
        final halfScreen = screenWidth / 2;
        final totalWidth = _contentWidth(totalDuration);

        final hasSelectedOverlay = context.select(
          (TimelineOverlayBloc b) => b.state.selectedItemId != null,
        );

        // Sync layers from main editor to timeline overlay bloc, and
        // sync scroll to playback position while not user-scrolling.
        return MultiBlocListener(
          listeners: [
            BlocListener<VideoEditorMainBloc, VideoEditorMainState>(
              listenWhen: (prev, curr) => prev.layers != curr.layers,
              listener: (context, state) {
                _syncLayersToOverlay(context, state.layers, totalDuration);
              },
            ),
            BlocListener<VideoEditorMainBloc, VideoEditorMainState>(
              listenWhen: (prev, curr) =>
                  !_isUserScrolling &&
                  prev.currentPosition != curr.currentPosition,
              listener: (context, state) => _syncScrollToPosition(
                state.currentPosition,
                totalDuration,
                totalWidth,
              ),
            ),
            BlocListener<ClipEditorBloc, ClipEditorState>(
              listenWhen: (prev, curr) =>
                  prev.totalDuration != curr.totalDuration,
              listener: (context, state) {
                context.read<TimelineOverlayBloc>().add(
                  TimelineOverlayTotalDurationChanged(state.totalDuration),
                );
              },
            ),
            BlocListener<VideoEditorFilterBloc, VideoEditorFilterState>(
              listenWhen: (prev, curr) =>
                  prev.hasFilter != curr.hasFilter ||
                  prev.selectedFilter?.name != curr.selectedFilter?.name,
              listener: (context, state) {
                _syncFilterToOverlay(context, state, totalDuration);
              },
            ),
          ],
          child: GestureDetector(
            onTap: isEditing || hasSelectedOverlay ? _onBackgroundTapped : null,
            behavior: HitTestBehavior.translucent,
            child: Container(
              color: VineTheme.backgroundCamera,
              height: TimelineConstants.height,
              child: Column(
                crossAxisAlignment: .stretch,
                children: [
                  VideoEditorTimelineHeader(
                    playheadPosition: _playheadPosition,
                  ),
                  const Padding(
                    padding: .only(top: 12),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: VineTheme.outlinedDisabled,
                    ),
                  ),

                  Expanded(
                    child: Stack(
                      fit: .expand,
                      children: [
                        // Scrollable timeline content.
                        ValueListenableBuilder<Duration>(
                          valueListenable: _playheadPosition,
                          builder: (context, position, child) {
                            final increased = Duration(
                              milliseconds:
                                  (position + const Duration(seconds: 1))
                                      .inMilliseconds
                                      .clamp(0, totalDuration.inMilliseconds),
                            );
                            final decreased = Duration(
                              milliseconds:
                                  (position - const Duration(seconds: 1))
                                      .inMilliseconds
                                      .clamp(0, totalDuration.inMilliseconds),
                            );
                            return Semantics(
                              label: 'Video timeline',
                              slider: true,
                              value: _formatPosition(position),
                              increasedValue: _formatPosition(increased),
                              decreasedValue: _formatPosition(decreased),
                              onIncrease: () => _stepPosition(
                                position,
                                totalDuration,
                                const Duration(seconds: 1),
                              ),
                              onDecrease: () => _stepPosition(
                                position,
                                totalDuration,
                                const Duration(seconds: -1),
                              ),
                              child: child ?? const SizedBox.shrink(),
                            );
                          },
                          // Pinch-to-zoom gesture tracking.
                          child: Listener(
                            onPointerDown: _onPointerDown,
                            onPointerMove: _onPointerMove,
                            onPointerUp: _onPointerUp,
                            onPointerCancel: _onPointerCancel,
                            child: NotificationListener<ScrollNotification>(
                              onNotification: _handleScrollNotification,
                              child: SingleChildScrollView(
                                controller: _scrollController,
                                scrollDirection: Axis.horizontal,
                                physics: _isPinching || _isTrimming
                                    ? const NeverScrollableScrollPhysics()
                                    : const ClampingScrollPhysics(),
                                clipBehavior: .none,
                                padding: .only(
                                  left: halfScreen,
                                  right: halfScreen,
                                  bottom: MediaQuery.paddingOf(context).bottom,
                                ),
                                child: _TimelineScrollContent(
                                  isReordering: isReordering,
                                  totalDuration: totalDuration,
                                  pixelsPerSecond: _pixelsPerSecond,
                                  scrollController: _scrollController,
                                  scrollPadding: halfScreen,
                                  clips: clips,
                                  totalWidth: totalWidth,
                                  isInteracting:
                                      _isUserScrolling || _isPinching,
                                  onReorder: _onClipsReordered,
                                  onReorderChanged: _onReorderChanged,
                                  trimmingClipId: trimmingClipId,
                                  onTrimChanged: _onTrimChanged,
                                  onTrimDragChanged: _onTrimDragChanged,
                                  onClipTapped: _onClipTapped,
                                  onOverlayItemMoved: _onOverlayItemMoved,
                                  onOverlayItemTrimmed: _onOverlayItemTrimmed,
                                  onOverlayTrimDragChanged:
                                      _onOverlayTrimDragChanged,
                                  onOverlayItemTapped: _onOverlayItemTapped,
                                  onOverlayDragStarted: _onOverlayDragStarted,
                                  onOverlayDragEnded: _onOverlayDragEnded,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Playhead
                        VideoEditorTimelinePlayhead(isVisible: !isReordering),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
    ref.read(clipManagerProvider.notifier).replaceClips(reorderedClips);
    context.read<ClipEditorBloc>().add(
      ClipEditorInitialized(reorderedClips),
    );
    context.read<VideoEditorMainBloc>().add(
      const VideoEditorExternalPauseRequested(isPaused: true),
    );
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

  void _onTrimChanged({
    required String clipId,
    required Duration trimStart,
    required Duration trimEnd,
    required bool isStart,
  }) {
    context.read<ClipEditorBloc>().add(
      ClipEditorTrimUpdated(
        clipId: clipId,
        trimStart: trimStart,
        trimEnd: trimEnd,
        isStart: isStart,
      ),
    );
  }

  void _onTrimDragChanged(bool isTrimming) {
    setState(() => _isTrimming = isTrimming);
    final clipEditorBloc = context.read<ClipEditorBloc>();
    if (isTrimming) {
      clipEditorBloc.add(const ClipEditorTrimDragStarted());
      context.read<VideoEditorMainBloc>().add(
        const VideoEditorExternalPauseRequested(isPaused: true),
      );
    } else {
      clipEditorBloc.add(const ClipEditorTrimDragEnded());
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
      // Different clip: select it and always enter editing.
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
    required String itemId,
    required Duration startTime,
    required int row,
    required bool insertAbove,
  }) {
    context.read<TimelineOverlayBloc>().add(
      TimelineOverlayItemMoved(
        itemId: itemId,
        startTime: startTime,
        row: row,
        insertAbove: insertAbove,
      ),
    );
  }

  void _onOverlayItemTrimmed({
    required String itemId,
    required Duration trimStart,
    required Duration trimEnd,
    required bool isStart,
    Duration? startTime,
    Duration? duration,
  }) {
    context.read<TimelineOverlayBloc>().add(
      TimelineOverlayItemTrimmed(
        itemId: itemId,
        trimStart: trimStart,
        trimEnd: trimEnd,
        isStart: isStart,
        startTime: startTime,
        duration: duration,
      ),
    );
  }

  void _onOverlayTrimDragChanged(bool isTrimming) {
    setState(() => _isTrimming = isTrimming);
    if (isTrimming) {
      context.read<VideoEditorMainBloc>().add(
        const VideoEditorExternalPauseRequested(isPaused: true),
      );
    }
  }

  void _onOverlayItemTapped(String itemId) {
    // Exit clip editing when an overlay item is tapped.
    final clipBloc = context.read<ClipEditorBloc>();
    if (clipBloc.state.isEditing) {
      clipBloc.add(const ClipEditorEditingToggled());
    }

    final bloc = context.read<TimelineOverlayBloc>();
    if (bloc.state.selectedItemId == itemId) {
      bloc.add(const TimelineOverlayItemSelected(null));
    } else {
      bloc.add(TimelineOverlayItemSelected(itemId));
    }
  }

  void _onOverlayDragStarted(String itemId) {
    context.read<TimelineOverlayBloc>().add(
      TimelineOverlayDragStarted(itemId),
    );
    context.read<VideoEditorMainBloc>().add(
      const VideoEditorExternalPauseRequested(isPaused: true),
    );
  }

  void _onOverlayDragEnded() {
    context.read<TimelineOverlayBloc>().add(
      const TimelineOverlayDragEnded(),
    );
  }

  // -- Pointer tracking + manual pinch-to-zoom ------------------------------

  static String _formatPosition(Duration position) {
    final totalSeconds = position.inMilliseconds / 1000.0;
    final minutes = totalSeconds ~/ 60;
    final seconds = (totalSeconds % 60).toStringAsFixed(1);
    return '${minutes}m ${seconds}s';
  }

  void _stepPosition(
    Duration current,
    Duration total,
    Duration step,
  ) {
    final ms = (current + step).inMilliseconds.clamp(
      0,
      total.inMilliseconds,
    );
    final position = Duration(milliseconds: ms);
    context.read<VideoEditorMainBloc>().add(
      VideoEditorSeekRequested(position),
    );
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
    _pointerPositions.remove(event.pointer);
    if (_pointerPositions.length < 2) {
      _pinchBaseDistance = 0;
      setState(() {});
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _pointerPositions.remove(event.pointer);
    if (_pointerPositions.length < 2) {
      _pinchBaseDistance = 0;
      setState(() {});
    }
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

    final ratio = newPps / _pixelsPerSecond;
    setState(() => _pixelsPerSecond = newPps);

    if (_scrollController.hasClients) {
      final newOffset = _scrollController.offset * ratio;
      _scrollController.jumpTo(
        newOffset.clamp(0, _scrollController.position.maxScrollExtent),
      );
    }
  }

  // -- Scroll ↔ position sync ------------------------------------------------

  /// Derives the time at the playhead from scroll offset.
  void _updatePlayheadTime() {
    if (!_scrollController.hasClients) return;
    final seconds = _scrollController.offset / _pixelsPerSecond;
    final ms = (seconds * 1000).round().clamp(
      0,
      _totalDuration.inMilliseconds,
    );
    _playheadPosition.value = Duration(milliseconds: ms);
  }

  /// Synchronises [VideoEditorMainState.layers] with the
  /// [TimelineOverlayBloc] by diffing IDs and dispatching add/remove events.
  void _syncLayersToOverlay(
    BuildContext context,
    List<pie.Layer> layers,
    Duration totalDuration,
  ) {
    final overlayBloc = context.read<TimelineOverlayBloc>();
    final existingIds = overlayBloc.state.items
        .where((i) => i.type == TimelineOverlayType.layer)
        .map((i) => i.id)
        .toSet();
    final currentIds = layers.map((l) => l.id).toSet();

    // Remove layers no longer present.
    for (final id in existingIds.difference(currentIds)) {
      overlayBloc.add(TimelineOverlayItemRemoved(id));
    }

    // Add new layers.
    for (final layer in layers) {
      if (!existingIds.contains(layer.id)) {
        overlayBloc.add(
          TimelineOverlayItemAdded(
            TimelineOverlayItem(
              id: layer.id,
              type: TimelineOverlayType.layer,
              startTime: Duration.zero,
              duration: totalDuration,
              label: _labelForLayer(layer),
            ),
          ),
        );
      }
    }
  }

  /// Synchronises the active filter with the [TimelineOverlayBloc].
  ///
  /// Uses a single `_filter` sentinel ID so only one filter strip exists.
  void _syncFilterToOverlay(
    BuildContext context,
    VideoEditorFilterState filterState,
    Duration totalDuration,
  ) {
    const filterId = '_filter';
    final overlayBloc = context.read<TimelineOverlayBloc>();
    final exists = overlayBloc.state.items.any((i) => i.id == filterId);

    if (filterState.hasFilter) {
      if (exists) {
        // Remove old, add new so the label updates.
        overlayBloc.add(const TimelineOverlayItemRemoved(filterId));
      }
      overlayBloc.add(
        TimelineOverlayItemAdded(
          TimelineOverlayItem(
            id: filterId,
            type: TimelineOverlayType.filter,
            startTime: Duration.zero,
            duration: totalDuration,
            label: filterState.selectedFilter!.name,
          ),
        ),
      );
    } else if (exists) {
      overlayBloc.add(const TimelineOverlayItemRemoved(filterId));
    }
  }

  /// Returns a human-readable label based on the layer type.
  static String _labelForLayer(pie.Layer layer) => switch (layer) {
    TextLayer(:final text) => text,
    PaintLayer() => 'Drawing',
    EmojiLayer(:final emoji) => emoji,
    WidgetLayer() => 'Sticker',
    _ => 'Layer',
  };

  void _syncScrollToPosition(
    Duration position,
    Duration totalDuration,
    double totalWidth,
  ) {
    if (!_scrollController.hasClients) return;
    if (totalDuration == Duration.zero) return;

    // Derive target directly from position × pixelsPerSecond so the
    // scroll is always consistent with the ruler/clip layout, even if
    // the player-reported duration differs from the sum of clip
    // durations (which determines maxScrollExtent).
    final target = position.inMilliseconds / 1000.0 * _pixelsPerSecond;
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

    final seconds = _scrollController.offset / _pixelsPerSecond;
    final ms = (seconds * 1000).round().clamp(
      0,
      _totalDuration.inMilliseconds,
    );
    final position = Duration(milliseconds: ms);
    context.read<VideoEditorMainBloc>().add(
      VideoEditorSeekRequested(position),
    );
  }
}

class _TimelineScrollContent extends StatelessWidget {
  const _TimelineScrollContent({
    required this.isReordering,
    required this.totalDuration,
    required this.pixelsPerSecond,
    required this.scrollController,
    required this.scrollPadding,
    required this.clips,
    required this.totalWidth,
    required this.isInteracting,
    required this.onReorder,
    required this.onReorderChanged,
    this.trimmingClipId,
    this.onTrimChanged,
    this.onTrimDragChanged,
    this.onClipTapped,
    this.onOverlayItemMoved,
    this.onOverlayItemTrimmed,
    this.onOverlayTrimDragChanged,
    this.onOverlayItemTapped,
    this.onOverlayDragStarted,
    this.onOverlayDragEnded,
  });

  final bool isReordering;
  final Duration totalDuration;
  final double pixelsPerSecond;
  final ScrollController scrollController;
  final double scrollPadding;
  final List<DivineVideoClip> clips;
  final double totalWidth;
  final bool isInteracting;

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
  final OverlayTrimCallback? onOverlayItemTrimmed;
  final ValueChanged<bool>? onOverlayTrimDragChanged;
  final ValueChanged<String>? onOverlayItemTapped;
  final ValueChanged<String>? onOverlayDragStarted;
  final VoidCallback? onOverlayDragEnded;

  @override
  Widget build(BuildContext context) {
    final clipTrimExpand = trimmingClipId != null
        ? TimelineConstants.trimHandleWidth + 12.0
        : 0.0;

    // Also expand for overlay trim handles when an overlay item is selected.
    final overlaySelectedId = context.select(
      (TimelineOverlayBloc b) => b.state.selectedItemId,
    );
    final overlayTrimExpand = overlaySelectedId != null
        ? TimelineConstants.trimHandleWidth + 12.0
        : 0.0;

    final trimExpand = clipTrimExpand > overlayTrimExpand
        ? clipTrimExpand
        : overlayTrimExpand;

    return HitExpandedBox(
      expandLeft: trimExpand,
      expandRight: trimExpand,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: 4,
            children: [
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
              Expanded(
                child: HitExpandedBox(
                  expandLeft: trimExpand,
                  expandRight: trimExpand,
                  child: AnimatedOpacity(
                    opacity: isReordering ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: SingleChildScrollView(
                      clipBehavior: Clip.none,
                      padding: const EdgeInsets.only(bottom: 80),
                      child: IgnorePointer(
                        ignoring: isReordering,
                        child: _TimelineOverlayStrips(
                          totalWidth: totalWidth,
                          pixelsPerSecond: pixelsPerSecond,
                          totalDuration: totalDuration,
                          clipEdgesMs: _clipEdgesMs(clips),
                          onItemTapped: onOverlayItemTapped,
                          onItemMoved: onOverlayItemMoved,
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
          // Semi-transparent overlay from 6.3s to the end.
          if (!isReordering)
            Positioned(
              left:
                  VideoEditorConstants.maxDuration.inMilliseconds /
                  1000 *
                  pixelsPerSecond,
              top: 0,
              bottom: 0,
              right: 0,
              child: IgnorePointer(
                child: ColoredBox(
                  color: VineTheme.surfaceContainerHigh.withValues(alpha: 0.6),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Watches [TimelineOverlayBloc] and renders layer / sound / filter strips.
///
/// Extracted into its own widget so that overlay state changes only rebuild
/// the overlay strips — not the clip strip or ruler.
class _TimelineOverlayStrips extends StatelessWidget {
  const _TimelineOverlayStrips({
    required this.totalWidth,
    required this.pixelsPerSecond,
    required this.totalDuration,
    required this.clipEdgesMs,
    this.onItemTapped,
    this.onItemMoved,
    this.onItemTrimmed,
    this.onTrimDragChanged,
    this.onDragStarted,
    this.onDragEnded,
  });

  final double totalWidth;
  final double pixelsPerSecond;
  final Duration totalDuration;
  final List<int> clipEdgesMs;
  final ValueChanged<String>? onItemTapped;
  final OverlayMoveCallback? onItemMoved;
  final OverlayTrimCallback? onItemTrimmed;
  final ValueChanged<bool>? onTrimDragChanged;
  final ValueChanged<String>? onDragStarted;
  final VoidCallback? onDragEnded;

  @override
  Widget build(BuildContext context) {
    final overlayState = context.watch<TimelineOverlayBloc>().state;

    final trimExp = overlayState.selectedItemId != null
        ? TimelineConstants.trimHandleWidth + 12.0
        : 0.0;

    // Build snap points from all overlay item edges + clip edges,
    // excluding the selected item so it doesn't snap to itself.
    final snapSet = <int>{};
    for (final item in overlayState.items) {
      if (item.id == overlayState.selectedItemId) continue;
      snapSet.add(item.startTime.inMilliseconds);
      snapSet.add(item.endTime.inMilliseconds);
    }
    snapSet.addAll(clipEdgesMs);
    final snapPointsMs = snapSet.toList();

    return HitExpandedBox(
      expandLeft: trimExp,
      expandRight: trimExp,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sound strip (red) — audio tracks.
          if (overlayState.hasItemsOfType(TimelineOverlayType.sound))
            HitExpandedBox(
              expandLeft: trimExp,
              expandRight: trimExp,
              child: Padding(
                padding: const EdgeInsets.only(
                  top: TimelineConstants.overlayStripGap,
                ),
                child: TimelineOverlayStrip(
                  items: overlayState.itemsOfType(TimelineOverlayType.sound),
                  rowCount: overlayState.rowCountForType(
                    TimelineOverlayType.sound,
                  ),
                  totalWidth: totalWidth,
                  pixelsPerSecond: pixelsPerSecond,
                  totalDuration: totalDuration,
                  color: const Color(0xFFE53935),
                  isCollapsed: overlayState.isTypeCollapsed(
                    TimelineOverlayType.sound,
                  ),
                  selectedItemId: overlayState.selectedItemId,
                  snapPointsMs: snapPointsMs,
                  onItemTapped: onItemTapped,
                  onItemMoved: onItemMoved,
                  onTrimChanged: onItemTrimmed,
                  onTrimDragChanged: onTrimDragChanged,
                  onDragStarted: onDragStarted,
                  onDragEnded: onDragEnded,
                ),
              ),
            ),
          // Filter strip (green) — visual effects.
          if (overlayState.hasItemsOfType(TimelineOverlayType.filter))
            HitExpandedBox(
              expandLeft: trimExp,
              expandRight: trimExp,
              child: Padding(
                padding: const EdgeInsets.only(
                  top: TimelineConstants.overlayStripGap,
                ),
                child: TimelineOverlayStrip(
                  items: overlayState.itemsOfType(TimelineOverlayType.filter),
                  rowCount: overlayState.rowCountForType(
                    TimelineOverlayType.filter,
                  ),
                  totalWidth: totalWidth,
                  pixelsPerSecond: pixelsPerSecond,
                  totalDuration: totalDuration,
                  color: Colors.orange,
                  isCollapsed: overlayState.isTypeCollapsed(
                    TimelineOverlayType.filter,
                  ),
                  selectedItemId: overlayState.selectedItemId,
                  snapPointsMs: snapPointsMs,
                  onItemTapped: onItemTapped,
                  onItemMoved: onItemMoved,
                  onTrimChanged: onItemTrimmed,
                  onTrimDragChanged: onTrimDragChanged,
                  onDragStarted: onDragStarted,
                  onDragEnded: onDragEnded,
                ),
              ),
            ),
          // Layer strip (pink) — text, drawings, stickers.
          if (overlayState.hasItemsOfType(TimelineOverlayType.layer))
            HitExpandedBox(
              expandLeft: trimExp,
              expandRight: trimExp,
              child: Padding(
                padding: const EdgeInsets.only(
                  top: TimelineConstants.overlayStripTopGap,
                ),
                child: TimelineOverlayStrip(
                  items: overlayState.itemsOfType(TimelineOverlayType.layer),
                  rowCount: overlayState.rowCountForType(
                    TimelineOverlayType.layer,
                  ),
                  totalWidth: totalWidth,
                  pixelsPerSecond: pixelsPerSecond,
                  totalDuration: totalDuration,
                  color: const Color(0xFFE91E8C),
                  isCollapsed: overlayState.isTypeCollapsed(
                    TimelineOverlayType.layer,
                  ),
                  selectedItemId: overlayState.selectedItemId,
                  snapPointsMs: snapPointsMs,
                  onItemTapped: onItemTapped,
                  onItemMoved: onItemMoved,
                  onTrimChanged: onItemTrimmed,
                  onTrimDragChanged: onTrimDragChanged,
                  onDragStarted: onDragStarted,
                  onDragEnded: onDragEnded,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
