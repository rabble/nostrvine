// ABOUTME: Progress bar showing video clips as proportional segments
// ABOUTME: Each segment width reflects clip duration with rounded corners

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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

class _ClipProgressOverlayState extends State<_ClipProgressOverlay>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;

  double _progress = 0;
  double _lastNativeProgress = 0;
  DateTime _lastNativeUpdate = DateTime.now();
  bool _isPlaying = false;

  double _calculateProgress(Duration currentPosition) {
    final totalDuration = widget.clipDuration.inMilliseconds;
    if (totalDuration <= 0) return 0;

    final positionInClip = currentPosition - widget.clipStartOffset;
    return (positionInClip.inMilliseconds / totalDuration).clamp(0, 1);
  }

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  void _onTick(Duration _) {
    final elapsed = DateTime.now().difference(_lastNativeUpdate);
    final totalMs = widget.clipDuration.inMilliseconds;
    if (totalMs <= 0) return;

    final elapsedFraction = elapsed.inMilliseconds / totalMs;
    var interpolated = _lastNativeProgress + elapsedFraction;
    interpolated = interpolated.clamp(0, 1);

    if (mounted) setState(() => _progress = interpolated);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  void deactivate() {
    // Safety net: stop the ticker when the widget is removed from the tree.
    // The primary stop happens in build() via context.select(isPlaying).
    if (_ticker.isActive) _ticker.stop();
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    final (hasPlayedOnce, currentPosition, isPlaying) = context.select(
      (ClipEditorBloc bloc) => (
        bloc.state.hasPlayedOnce,
        bloc.state.currentPosition,
        bloc.state.isPlaying,
      ),
    );

    final nativeProgress = hasPlayedOnce
        ? _calculateProgress(currentPosition)
        : 0.0;

    // Update anchor when BLoC emits a new position.
    if (nativeProgress != _lastNativeProgress) {
      // Detect reset (loop) — snap instead of interpolate.
      final isReset = nativeProgress < _lastNativeProgress - 0.1;
      _lastNativeProgress = nativeProgress;
      _lastNativeUpdate = DateTime.now();
      if (isReset) _progress = nativeProgress;
    }

    // Start/stop ticker based on playback state.
    // context.select guarantees a rebuild whenever isPlaying changes in the
    // BLoC, so the ticker always stops promptly when playback pauses.
    if (isPlaying != _isPlaying) {
      _isPlaying = isPlaying;
      if (isPlaying && !_ticker.isActive) {
        // Reset anchor so the first tick doesn't see a huge elapsed gap
        // from the time spent paused.
        _lastNativeProgress = nativeProgress;
        _lastNativeUpdate = DateTime.now();
        _progress = nativeProgress;
        _ticker.start();
      } else if (!isPlaying && _ticker.isActive) {
        _ticker.stop();
        _progress = nativeProgress;
      }
    }

    final displayProgress = isPlaying ? _progress : nativeProgress;

    if (displayProgress <= 0) {
      return const SizedBox.shrink();
    }

    return FractionallySizedBox(
      widthFactor: displayProgress,
      alignment: .centerLeft,
      child: Stack(
        alignment: .centerRight,
        children: [
          _ProgressFill(isFirst: widget.isFirst, isLast: widget.isLast),
          const _ProgressHandle(),
        ],
      ),
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
