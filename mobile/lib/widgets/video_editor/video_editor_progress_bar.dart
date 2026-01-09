// ABOUTME: Progress bar showing video clips as proportional segments
// ABOUTME: Each segment width reflects clip duration with rounded corners

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';

/// Displays a progress bar showing all video clips as segments.
class VideoProgressBar extends ConsumerStatefulWidget {
  /// Creates a video progress bar widget.
  const VideoProgressBar({super.key});

  @override
  ConsumerState<VideoProgressBar> createState() => _VideoProgressBarState();
}

class _VideoProgressBarState extends ConsumerState<VideoProgressBar>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  Duration _lastKnownPosition = Duration.zero;
  DateTime? _lastUpdateTime;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        _lastKnownPosition = ref.read(
          videoEditorProvider.select((s) => s.currentPosition),
        );
        _lastUpdateTime = DateTime.now();

        final isPlaying = ref.read(
          videoEditorProvider.select((s) => s.isPlaying),
        );
        if (isPlaying && !_ticker.isActive) {
          await _ticker.start();
        }

        setState(() {});
      }
    });

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

    return Container(
      height: 40,
      padding: const .symmetric(horizontal: 16),
      child: Row(
        spacing: 3,
        children: _buildSegments(
          clips,
          state.currentClipIndex,
          state.isReordering,
          _smoothPosition,
        ),
      ),
    );
  }

  /// Builds segment widgets for each clip with proportional widths.
  List<Widget> _buildSegments(
    List<RecordingClip> clips,
    int currentClipIndex,
    bool isReordering,
    Duration currentPosition,
  ) {
    // Calculate offset for current clip
    Duration clipStartOffset = Duration.zero;
    for (var i = 0; i < currentClipIndex && i < clips.length; i++) {
      clipStartOffset += clips[i].duration;
    }

    return List.generate(clips.length, (i) {
      final clip = clips[i];
      final isFirst = i == 0;
      final isLast = i == clips.length - 1;
      final isCompleted = i < currentClipIndex;
      final isCurrent = i == currentClipIndex;
      final isReorderingClip = isReordering && isCurrent;

      // Calculate progress within current clip (0.0 to 1.0)
      double clipProgress = 0.0;
      if (isCurrent && clip.duration.inMilliseconds > 0) {
        final positionInClip = currentPosition - clipStartOffset;
        clipProgress =
            (positionInClip.inMilliseconds / clip.duration.inMilliseconds)
                .clamp(0.0, 1.0);
      }

      // Determine color based on state
      final segmentColor = isReorderingClip
          ? const Color(0xFF27C58B)
          : isCompleted
          ? const Color(0xFF146346) // Green for completed
          : const Color(0xFF404040); // Gray for uncompleted

      return Expanded(
        flex: clip.duration.inMilliseconds,
        child: Stack(
          children: [
            AnimatedContainer(
              duration: isReordering
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
                alignment: Alignment.centerLeft,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFF27C58B),
                    borderRadius: .horizontal(
                      left: isFirst ? const .circular(999) : .zero,
                      right: clipProgress >= 0.99 && isLast
                          ? const .circular(999)
                          : .zero,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}
