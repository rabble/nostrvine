import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_timeline_clip_strip.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/timeline_constants.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_left_actions.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_playhead.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_rules_indicator.dart';

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

  /// Throttle timestamp — limits how often native seekTo is called during
  /// scrubbing so the scroll stays fluid.
  int _lastSeekMs = 0;
  static const _seekThrottleMs = 80;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_updatePlayheadTime);
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

    return BlocSelector<
      VideoEditorMainBloc,
      VideoEditorMainState,
      ({Duration currentPosition, Duration totalDuration})
    >(
      selector: (state) => (
        currentPosition: state.currentPosition,
        totalDuration: state.totalDuration,
      ),
      builder: (context, playback) {
        final screenWidth = MediaQuery.sizeOf(context).width;
        final halfScreen = screenWidth / 2;
        final totalDuration = playback.totalDuration;
        final totalWidth = _contentWidth(totalDuration);

        return BlocListener<VideoEditorMainBloc, VideoEditorMainState>(
          listenWhen: (prev, curr) =>
              !_isUserScrolling && prev.currentPosition != curr.currentPosition,
          listener: (context, state) => _syncScrollToPosition(
            state.currentPosition,
            state.totalDuration,
            totalWidth,
          ),
          child: Container(
            color: VineTheme.backgroundCamera,
            height: 350, // FIXME(hm21): set correct height
            child: Stack(
              fit: .expand,
              children: [
                Listener(
                  onPointerDown: _onPointerDown,
                  onPointerMove: _onPointerMove,
                  onPointerUp: _onPointerUp,
                  onPointerCancel: _onPointerCancel,
                  child: Padding(
                    padding: const .only(bottom: 4),
                    child: NotificationListener<ScrollNotification>(
                      onNotification: _handleScrollNotification,
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        physics: _isPinching
                            ? const NeverScrollableScrollPhysics()
                            : const ClampingScrollPhysics(),
                        padding: .only(
                          left: halfScreen,
                          right: halfScreen,
                          bottom: MediaQuery.paddingOf(context).bottom,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          spacing: 4,
                          children: [
                            BlocSelector<
                              VideoEditorMainBloc,
                              VideoEditorMainState,
                              bool
                            >(
                              selector: (state) => state.isReordering,
                              builder: (context, isReordering) {
                                return AnimatedOpacity(
                                  opacity: isReordering ? 0.0 : 1.0,
                                  duration: const Duration(milliseconds: 200),
                                  child: VideoEditorTimelineRulesIndicator(
                                    totalDuration: totalDuration,
                                    pixelsPerSecond: _pixelsPerSecond,
                                  ),
                                );
                              },
                            ),
                            VideoEditorTimelineClipStrip(
                              clips: clips,
                              totalWidth: totalWidth,
                              pixelsPerSecond: _pixelsPerSecond,
                              scrollController: _scrollController,
                              isInteracting: _isUserScrolling || _isPinching,
                              onReorder: (reorderedClips) {
                                ref
                                    .read(clipManagerProvider.notifier)
                                    .replaceClips(reorderedClips);
                                context.read<ClipEditorBloc>().add(
                                  ClipEditorInitialized(reorderedClips),
                                );
                                // Keep video paused after reorder.
                                context.read<VideoEditorMainBloc>().add(
                                  const VideoEditorExternalPauseRequested(
                                    isPaused: true,
                                  ),
                                );
                              },
                              onReorderChanged: (isReordering) {
                                final bloc = context
                                    .read<VideoEditorMainBloc>();
                                bloc.add(
                                  VideoEditorReorderingChanged(
                                    isReordering: isReordering,
                                  ),
                                );
                                if (isReordering) {
                                  bloc.add(
                                    const VideoEditorExternalPauseRequested(
                                      isPaused: true,
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                BlocSelector<VideoEditorMainBloc, VideoEditorMainState, bool>(
                  selector: (state) => state.isReordering,
                  builder: (context, isReordering) {
                    return IgnorePointer(
                      ignoring: isReordering,
                      child: AnimatedOpacity(
                        opacity: isReordering ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: const VideoEditorTimelinePlayhead(),
                      ),
                    );
                  },
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: VideoEditorTimelineLeftActions(
                    playheadPosition: _playheadPosition,
                  ),
                ),

                BlocSelector<VideoEditorMainBloc, VideoEditorMainState, bool>(
                  selector: (state) => state.isReordering,
                  builder: (context, isReordering) {
                    return AnimatedOpacity(
                      opacity: isReordering ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        alignment: .topCenter,
                        padding: const EdgeInsets.only(
                          top: TimelineConstants.rulerHeight,
                        ),
                        child: const Divider(
                          height: 1,
                          thickness: 1,
                          color: VineTheme.outlinedDisabled,
                        ),
                      ),
                    );
                  },
                ),
              ],
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

  // -- Pointer tracking + manual pinch-to-zoom ------------------------------

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
    final ms = (seconds * 1000).round().clamp(0, 1 << 30);
    _playheadPosition.value = Duration(milliseconds: ms);
  }

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
    final ms = (seconds * 1000).round().clamp(0, 1 << 30);
    final position = Duration(milliseconds: ms);
    context.read<VideoEditorMainBloc>().add(
      VideoEditorSeekRequested(position),
    );
  }
}
