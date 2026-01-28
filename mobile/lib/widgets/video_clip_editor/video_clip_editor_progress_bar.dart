// ABOUTME: Progress bar showing video clips as proportional segments
// ABOUTME: Each segment width reflects clip duration with rounded corners

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:divine_ui/divine_ui.dart';

/// Displays a progress bar showing all video clips as segments.
class VideoClipEditorProgressBar extends ConsumerStatefulWidget {
  /// Creates a video progress bar widget.
  const VideoClipEditorProgressBar({super.key});

  @override
  ConsumerState<VideoClipEditorProgressBar> createState() =>
      _VideoProgressBarState();
}

class _VideoProgressBarState extends ConsumerState<VideoClipEditorProgressBar>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  Duration _lastKnownPosition = Duration.zero;
  DateTime? _lastUpdateTime;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);

    ref
      ..listenManual(videoEditorProvider.select((s) => s.isPlaying), (
        previous,
        next,
      ) async {
        if (next) {
          _lastUpdateTime = DateTime.now();
          if (!_ticker.isActive) {
            await _ticker.start();
          }
        } else {
          // Calculate current interpolated position before stopping
          if (_lastUpdateTime != null) {
            final elapsed = DateTime.now().difference(_lastUpdateTime!);
            _lastKnownPosition = _lastKnownPosition + elapsed;
          }
          _ticker.stop();
          if (mounted) setState(() {});
        }
      })
      ..listenManual(videoEditorProvider.select((s) => s.currentPosition), (
        previous,
        next,
      ) {
        if ((next - _lastKnownPosition).abs() >
            const Duration(milliseconds: 50)) {
          _lastKnownPosition = next;
          _lastUpdateTime = DateTime.now();
          if (mounted) setState(() {});
        }
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize position on first build (called before build)
    if (_lastUpdateTime == null) {
      _lastKnownPosition = ref.read(
        videoEditorProvider.select((s) => s.currentPosition),
      );
      _lastUpdateTime = DateTime.now();

      final isPlaying = ref.read(
        videoEditorProvider.select((s) => s.isPlaying),
      );
      if (isPlaying && !_ticker.isActive) {
        _ticker.start();
      }
    }
  }

  void _onTick(Duration elapsed) {
    if (mounted) setState(() {});
  }

  Duration get _smoothPosition {
    final isPlaying = ref.read(videoEditorProvider.select((s) => s.isPlaying));

    if (!isPlaying || _lastUpdateTime == null) {
      return _lastKnownPosition;
    }

    final elapsed = DateTime.now().difference(_lastUpdateTime!);
    return _lastKnownPosition + elapsed;
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clips = ref.watch(clipManagerProvider.select((state) => state.clips));
    final state = ref.watch(
      videoEditorProvider.select(
        (s) => (
          currentClipIndex: s.currentClipIndex,
          isReordering: s.isReordering,
        ),
      ),
    );
    // Calculate offset for current clip
    Duration clipStartOffset = Duration.zero;
    for (var i = 0; i < state.currentClipIndex && i < clips.length; i++) {
      clipStartOffset += clips[i].duration;
    }
    // TODO(@hm21): Improve the progress animation, especially on Android, as it is not always smooth.
    return RepaintBoundary(
      child: Row(
        spacing: 3,
        children: List.generate(clips.length, (i) {
          final clip = clips[i];
          final isFirst = i == 0;
          final isLast = i == clips.length - 1;
          final isCompleted = i < state.currentClipIndex;
          final isCurrent = i == state.currentClipIndex;
          final isReorderingClip = state.isReordering && isCurrent;

          // Calculate progress within current clip (0.0 to 1.0)
          double clipProgress = 0.0;
          if (isCurrent && clip.duration.inMilliseconds > 0) {
            final positionInClip = _smoothPosition - clipStartOffset;
            clipProgress =
                (positionInClip.inMilliseconds / clip.duration.inMilliseconds)
                    .clamp(0.0, 1.0);
          }

          // Determine color based on state
          final segmentColor = isReorderingClip
              ? VineTheme.tabIndicatorGreen
              : isCompleted
              ? const Color(0xFF146346) // Dark-Green for completed
              : const Color(0xFF404040); // Gray for uncompleted

          return Expanded(
            flex: clip.duration.inMilliseconds,
            child: Stack(
              alignment: .centerLeft,
              children: [
                AnimatedContainer(
                  duration: state.isReordering
                      ? Duration.zero
                      : const Duration(milliseconds: 100),
                  height: 8,
                  decoration: BoxDecoration(
                    color: segmentColor,
                    border: isReorderingClip
                        ? Border.all(
                            color: const Color(0xFFEBDE3B),
                            width: 3,
                            strokeAlign: BorderSide.strokeAlignOutside,
                          )
                        : null,
                    borderRadius: .horizontal(
                      left: isFirst || isReorderingClip
                          ? const .circular(999)
                          : .zero,
                      right: isLast || isReorderingClip
                          ? const .circular(999)
                          : .zero,
                    ),
                  ),
                ),
                // Progress overlay for current clip
                if (isCurrent && clipProgress > 0)
                  FractionallySizedBox(
                    widthFactor: clipProgress,
                    alignment: .centerLeft,
                    child: Stack(
                      alignment: .centerRight,
                      children: [
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: VineTheme.tabIndicatorGreen,
                            borderRadius: .horizontal(
                              left: isFirst ? const .circular(999) : .zero,
                              right: clipProgress >= 0.99 && isLast
                                  ? const .circular(999)
                                  : .zero,
                            ),
                          ),
                        ),
                        Container(
                          width: 4,
                          height: 32,
                          decoration: ShapeDecoration(
                            color: const Color(0xF1FFFFFF),
                            shape: RoundedRectangleBorder(
                              borderRadius: .circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
