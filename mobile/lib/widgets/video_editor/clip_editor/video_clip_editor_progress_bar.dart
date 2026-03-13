// ABOUTME: Progress bar showing video clips as proportional segments
// ABOUTME: Each segment width reflects clip duration with rounded corners

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';

/// Displays a progress bar showing all video clips as segments.
class VideoClipEditorProgressBar extends StatelessWidget {
  /// Creates a video progress bar widget.
  const VideoClipEditorProgressBar({super.key});

  @override
  Widget build(BuildContext context) {
    final (currentClipIndex, isReordering, clips) = context.select(
      (ClipEditorBloc bloc) => (
        bloc.state.currentClipIndex,
        bloc.state.isReordering,
        bloc.state.clips,
      ),
    );

    // Calculate offset for current clip
    Duration clipStartOffset = Duration.zero;
    for (var i = 0; i < currentClipIndex && i < clips.length; i++) {
      clipStartOffset += clips[i].duration;
    }

    return Row(
      spacing: 3,
      children: List.generate(clips.length, (i) {
        final clip = clips[i];
        final isFirst = i == 0;
        final isLast = i == clips.length - 1;
        final isCompleted = i < currentClipIndex;
        final isCurrent = i == currentClipIndex;
        final isReorderingClip = isReordering && isCurrent;

        // Determine color based on state
        final segmentColor = isReorderingClip
            ? VineTheme.primary
            : isCompleted
            ? VineTheme.primary.withAlpha(128)
            : VineTheme.onSurfaceDisabled;

        return Expanded(
          flex: clip.duration.inMilliseconds,
          child: Stack(
            alignment: .centerLeft,
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
                          color: VineTheme.accentYellow,
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
              // Progress overlay for current clip with Tween animation
              if (isCurrent)
                RepaintBoundary(
                  child: _ClipProgressOverlay(
                    clipStartOffset: clipStartOffset,
                    clipDuration: clip.duration,
                    isFirst: isFirst,
                    isLast: isLast,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _ClipProgressOverlay extends StatefulWidget {
  const _ClipProgressOverlay({
    required this.clipStartOffset,
    required this.clipDuration,
    required this.isFirst,
    required this.isLast,
  });

  final Duration clipStartOffset;
  final Duration clipDuration;
  final bool isFirst;
  final bool isLast;

  @override
  State<_ClipProgressOverlay> createState() => _ClipProgressOverlayState();
}

class _ClipProgressOverlayState extends State<_ClipProgressOverlay> {
  double _previousProgress = 0.0;

  double _calculateProgress(Duration currentPosition) {
    final totalDuration = widget.clipDuration.inMilliseconds;
    if (totalDuration <= 0) return 0.0;

    final positionInClip = currentPosition - widget.clipStartOffset;
    return (positionInClip.inMilliseconds / totalDuration).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final (hasPlayedOnce, currentPosition) = context.select(
      (ClipEditorBloc bloc) => (
        bloc.state.hasPlayedOnce,
        bloc.state.currentPosition,
      ),
    );

    final clipProgress = hasPlayedOnce
        ? _calculateProgress(currentPosition)
        : 0.0;

    // Detect reset (loop) - don't animate backwards
    final isReset = clipProgress < _previousProgress - 0.1;
    _previousProgress = clipProgress;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: clipProgress),
      duration: isReset ? Duration.zero : const Duration(milliseconds: 90),
      child: Stack(
        alignment: .centerRight,
        children: [
          _ProgressFill(isFirst: widget.isFirst, isLast: widget.isLast),
          const _ProgressHandle(),
        ],
      ),

      builder: (context, progress, child) {
        if (progress <= 0) {
          return const SizedBox.shrink();
        }
        return FractionallySizedBox(
          widthFactor: progress,
          alignment: .centerLeft,
          child: child,
        );
      },
    );
  }
}

class _ProgressFill extends StatelessWidget {
  const _ProgressFill({required this.isFirst, required this.isLast});

  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: VineTheme.tabIndicatorGreen,
        borderRadius: .horizontal(
          left: isFirst ? const .circular(999) : .zero,
          right: isLast ? const .circular(999) : .zero,
        ),
      ),
    );
  }
}

class _ProgressHandle extends StatelessWidget {
  const _ProgressHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 32,
      decoration: ShapeDecoration(
        color: VineTheme.onSurface,
        shape: RoundedRectangleBorder(borderRadius: .circular(8)),
      ),
    );
  }
}
