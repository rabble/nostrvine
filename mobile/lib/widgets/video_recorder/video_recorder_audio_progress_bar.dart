// ABOUTME: Audio progress bar widget for video recorder
// ABOUTME: Shows waveform visualization with recording progress overlay
// ABOUTME: Uses BLoC for waveform state, Riverpod for existing recorder state

import 'dart:typed_data';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/sound_waveform/sound_waveform_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/providers/video_recorder_provider.dart';

/// Constants for waveform bar rendering.
abstract final class _WaveformConstants {
  static const barWidth = 2.0;
  static const barSpacing = 1.0;
  static const barStep = barWidth + barSpacing;
  static const minBarHeight = 1.0;
  static const emptyBarHeight = 4.0;
  static const barRadius = Radius.circular(1);
  static const waveformHeight = 72.0;
}

/// Audio progress bar that displays waveform with recording progress.
///
/// Shows left channel on top and right channel (mirrored) on bottom.
/// Only visible during active recording when a sound is selected.
///
/// Uses [SoundWaveformBloc] for waveform extraction (new BLoC pattern)
/// and existing Riverpod providers for recorder state (legacy).
class VideoRecorderAudioProgressBar extends ConsumerWidget {
  /// Creates an audio progress bar widget.
  const VideoRecorderAudioProgressBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRecording = ref.watch(
      videoRecorderProvider.select((s) => s.isRecording),
    );
    final selectedSound = ref.watch(selectedSoundProvider);

    return Positioned(
      top: 24,
      left: 0,
      right: 0,
      child: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.ease,
          child: !isRecording || selectedSound == null
              ? const SizedBox.shrink(
                  key: ValueKey('Empty-Video-Recorder-Audio-Track'),
                )
              : BlocBuilder<SoundWaveformBloc, SoundWaveformState>(
                  builder: (context, waveformState) {
                    return switch (waveformState) {
                      SoundWaveformLoaded(
                        :final leftChannel,
                        :final rightChannel,
                        :final duration,
                      ) =>
                        _AudioWaveformProgress(
                          leftChannel: leftChannel,
                          rightChannel: rightChannel,
                          audioDuration: duration,
                        ),
                      SoundWaveformInitial() => const SizedBox.shrink(),
                      SoundWaveformLoading() ||
                      SoundWaveformError() => const _EmptyWaveformPlaceholder(),
                    };
                  },
                ),
        ),
      ),
    );
  }
}

/// Empty waveform placeholder shown when no waveform data is available.
class _EmptyWaveformPlaceholder extends StatelessWidget {
  const _EmptyWaveformPlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: VineTheme.scrim15,
        borderRadius: BorderRadius.circular(4),
      ),
      child: CustomPaint(
        size: const Size(double.infinity, _WaveformConstants.waveformHeight),
        painter: _EmptyWaveformPainter(
          barColor: VineTheme.whiteText.withValues(alpha: 0.32),
        ),
      ),
    );
  }
}

/// Painter for empty waveform placeholder with uniform bars.
class _EmptyWaveformPainter extends CustomPainter {
  _EmptyWaveformPainter({required this.barColor});

  final Color barColor;

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = (size.width / _WaveformConstants.barStep).floor();
    final halfHeight = size.height / 2;
    const totalHeight = _WaveformConstants.emptyBarHeight * 2;

    final paint = Paint()
      ..color = barColor
      ..style = .fill;

    for (var i = 0; i < barCount; i++) {
      final x = i * _WaveformConstants.barStep;
      canvas.drawRRect(
        .fromRectAndRadius(
          .fromLTWH(
            x,
            halfHeight - _WaveformConstants.emptyBarHeight,
            _WaveformConstants.barWidth,
            totalHeight,
          ),
          _WaveformConstants.barRadius,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_EmptyWaveformPainter oldDelegate) {
    return oldDelegate.barColor != barColor;
  }
}

class _AudioWaveformProgress extends ConsumerWidget {
  const _AudioWaveformProgress({
    required this.leftChannel,
    this.rightChannel,
    required this.audioDuration,
  });

  final Float32List leftChannel;
  final Float32List? rightChannel;
  final Duration audioDuration;

  /// Maximum allowed recording duration.
  static const Duration _maxDuration = VideoEditorConstants.maxDuration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      clipManagerProvider.select(
        (s) => (clips: s.clips, activeRecording: s.activeRecordingDuration),
      ),
    );

    // Calculate total recorded duration
    var recordedDuration = Duration.zero;
    for (final clip in state.clips) {
      recordedDuration += clip.duration;
    }
    recordedDuration += state.activeRecording;

    // Calculate progress as ratio of recorded to max duration
    final progress =
        recordedDuration.inMilliseconds /
        _maxDuration.inMilliseconds.clamp(1, double.infinity);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: VineTheme.scrim15,
        borderRadius: .circular(4),
      ),
      child: CustomPaint(
        size: const Size(double.infinity, _WaveformConstants.waveformHeight),
        foregroundPainter: _WaveformProgressPainter(
          leftChannel: leftChannel,
          rightChannel: rightChannel,
          progress: progress.clamp(0.0, 1.0),
          activeColor: VineTheme.whiteText,
          inactiveColor: VineTheme.whiteText.withValues(alpha: 0.32),
          activeBackgroundColor: VineTheme.scrim15,
          audioDuration: audioDuration,
          maxDuration: _maxDuration,
        ),
      ),
    );
  }
}

/// Custom painter for stereo waveform with progress overlay.
///
/// The waveform is scaled to show only [maxDuration] worth of audio:
/// - If audio is longer than maxDuration, only the first maxDuration is shown
/// - If audio is shorter than maxDuration, waveform fills proportionally
class _WaveformProgressPainter extends CustomPainter {
  _WaveformProgressPainter({
    required this.leftChannel,
    this.rightChannel,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
    this.activeBackgroundColor,
    required this.audioDuration,
    required this.maxDuration,
  });

  final Float32List leftChannel;
  final Float32List? rightChannel;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;
  final Color? activeBackgroundColor;
  final Duration audioDuration;
  final Duration maxDuration;

  @override
  void paint(Canvas canvas, Size size) {
    if (leftChannel.isEmpty) return;

    final halfHeight = size.height / 2;

    // Calculate visible duration and ratios
    final audioMs = audioDuration.inMilliseconds.toDouble();
    final maxMs = maxDuration.inMilliseconds.toDouble();
    final visibleMs = audioMs.clamp(0.0, maxMs);

    // How much of the bar should be filled with waveform
    // (1.0 if audio >= maxDuration, less if audio is shorter)
    final barFillRatio = visibleMs / maxMs;

    // How much of the samples we need to display
    // (1.0 if audio <= maxDuration, less if audio is longer)
    final sampleRatio = visibleMs / audioMs;

    final waveformWidth = size.width * barFillRatio;
    final visibleSampleCount = (leftChannel.length * sampleRatio).ceil();

    // Calculate the x position where progress ends
    final progressX = size.width * progress;

    // Draw active background if provided
    if (activeBackgroundColor != null && progressX > 0) {
      final bgPaint = Paint()
        ..color = activeBackgroundColor!
        ..style = PaintingStyle.fill;
      canvas.drawRect(Rect.fromLTWH(0, 0, progressX, size.height), bgPaint);
    }

    // Draw both channels as connected bars (no gap in center)
    final rightSamples = rightChannel ?? leftChannel;
    _drawStereoWaveform(
      canvas: canvas,
      leftSamples: leftChannel,
      rightSamples: rightSamples,
      centerY: halfHeight,
      halfHeight: halfHeight,
      waveformWidth: waveformWidth,
      visibleSampleCount: visibleSampleCount,
      progressX: progressX,
    );

    // Draw placeholder bars for remaining empty space (if audio < maxDuration)
    if (barFillRatio < 1.0) {
      final waveformBarCount = (waveformWidth / _WaveformConstants.barStep)
          .floor();
      final emptyStartX = waveformBarCount * _WaveformConstants.barStep;

      _drawEmptyBars(
        canvas: canvas,
        startX: emptyStartX,
        endX: size.width,
        centerY: halfHeight,
        progressX: progressX,
      );
    }
  }

  /// Draws minimal amplitude bars in the empty area where no waveform data.
  void _drawEmptyBars({
    required Canvas canvas,
    required double startX,
    required double endX,
    required double centerY,
    required double progressX,
  }) {
    const totalHeight = _WaveformConstants.minBarHeight * 2;

    var x = startX;
    while (x < endX) {
      final isActive = x <= progressX;
      final paint = Paint()
        ..color = isActive ? activeColor : inactiveColor
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x,
            centerY - _WaveformConstants.minBarHeight,
            _WaveformConstants.barWidth,
            totalHeight,
          ),
          _WaveformConstants.barRadius,
        ),
        paint,
      );
      x += _WaveformConstants.barStep;
    }
  }

  /// Draws both channels as connected vertical bars (no gap in center).
  void _drawStereoWaveform({
    required Canvas canvas,
    required Float32List leftSamples,
    required Float32List rightSamples,
    required double centerY,
    required double halfHeight,
    required double waveformWidth,
    required int visibleSampleCount,
    required double progressX,
  }) {
    const barWidth = 2.0;
    const barSpacing = 1.0;
    const minBarHeight = 1.0; // Match empty bars minimum
    final barStep = barWidth + barSpacing;
    final barCount = (waveformWidth / barStep).floor();

    if (barCount <= 0 || visibleSampleCount <= 0) return;

    for (var i = 0; i < barCount; i++) {
      final x = i * barStep;

      // Map bar position to sample index within visible samples
      final sampleIndex = ((i / barCount) * visibleSampleCount).floor();

      // Get amplitudes (0.0-1.0)
      final leftAmp = sampleIndex < leftSamples.length
          ? leftSamples[sampleIndex].abs().clamp(0.0, 1.0)
          : 0.0;
      final rightAmp = sampleIndex < rightSamples.length
          ? rightSamples[sampleIndex].abs().clamp(0.0, 1.0)
          : 0.0;

      // Calculate bar heights (minimum for visibility)
      final topHeight = (leftAmp * halfHeight * 0.9).clamp(
        minBarHeight,
        halfHeight,
      );
      final bottomHeight = (rightAmp * halfHeight * 0.9).clamp(
        minBarHeight,
        halfHeight,
      );

      // Total height spans from top of left channel to bottom of right channel
      final totalHeight = topHeight + bottomHeight;
      final topY = centerY - topHeight;

      // Determine color based on progress
      final isActive = x <= progressX;
      final paint = Paint()
        ..color = isActive ? activeColor : inactiveColor
        ..style = .fill;

      // Draw single connected bar spanning both channels
      canvas.drawRRect(
        .fromRectAndRadius(
          .fromLTWH(x, topY, barWidth, totalHeight),
          const .circular(1),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor ||
        oldDelegate.leftChannel != leftChannel ||
        oldDelegate.rightChannel != rightChannel ||
        oldDelegate.audioDuration != audioDuration ||
        oldDelegate.maxDuration != maxDuration;
  }
}
