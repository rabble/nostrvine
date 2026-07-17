// ABOUTME: Translucent waveform band drawn over a timeline clip's thumbnails.
// ABOUTME: Bars grow up from the clip's bottom edge and scale with clip volume.

import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/models/video_editor/clip_waveform.dart';

/// The clip's audio waveform, drawn translucently over its thumbnails.
///
/// Sized and positioned by the caller to span the clip's *full source*
/// duration, so the bars stay glued to the frames as the tile is trimmed,
/// zoomed, or scrolled.
class ClipWaveformOverlay extends StatelessWidget {
  const ClipWaveformOverlay({
    required this.waveform,
    required this.clipDuration,
    required this.volume,
    super.key,
  });

  final ClipWaveform waveform;

  /// Duration of the clip's source file — the span [waveform] is stretched
  /// across the overlay's width against.
  final Duration clipDuration;

  /// The clip's volume. Scales the bar heights, so muting flattens the band
  /// to its baseline instead of leaving a misleading loud waveform.
  final double volume;

  @override
  Widget build(BuildContext context) {
    if (waveform.isEmpty) return const SizedBox.shrink();

    return ExcludeSemantics(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: ClipWaveformPainter(
              waveform: waveform,
              clipDuration: clipDuration,
              volume: volume,
              color: VineTheme.whiteText.withValues(
                alpha: TimelineConstants.clipWaveformOpacity,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints [waveform] as bottom-anchored bars across the full paint width.
@visibleForTesting
class ClipWaveformPainter extends CustomPainter {
  const ClipWaveformPainter({
    required this.waveform,
    required this.clipDuration,
    required this.volume,
    required this.color,
  });

  final ClipWaveform waveform;
  final Duration clipDuration;
  final double volume;
  final Color color;

  static const double _barStep =
      TimelineConstants.clipWaveformBarWidth +
      TimelineConstants.clipWaveformBarSpacing;

  @override
  void paint(Canvas canvas, Size size) {
    final clipMs = clipDuration.inMilliseconds;
    if (waveform.isEmpty || clipMs <= 0 || size.width <= 0) return;

    // An audio track that ends before the video does covers only the leading
    // part of the tile; anything past it stays bare rather than stretching the
    // samples over silence.
    final audioFraction = (waveform.duration.inMilliseconds / clipMs).clamp(
      0.0,
      1.0,
    );
    final bandWidth = size.width * audioFraction;
    final barCount = (bandWidth / _barStep).floor();
    if (barCount <= 0) return;

    final band = math.min(
      TimelineConstants.clipWaveformBandHeight,
      size.height,
    );
    final paint = Paint()..color = color;
    final peaks = waveform.peaks;

    // Normalize against the clip's own loudest sample, so a quietly recorded
    // clip still fills the band. The floor keeps near-silence flat instead of
    // amplifying room noise into a convincing-looking waveform.
    final normalizer = math.max(
      waveform.peak,
      TimelineConstants.clipWaveformNormalizerFloor,
    );

    for (var i = 0; i < barCount; i++) {
      // Peak across every sample the bar covers — averaging (or point
      // sampling) would alias transients away at low zoom, where one bar
      // spans dozens of samples.
      final from = (i * peaks.length ~/ barCount).clamp(0, peaks.length - 1);
      final to = math.max(from + 1, (i + 1) * peaks.length ~/ barCount);
      var amplitude = 0.0;
      for (var s = from; s < to && s < peaks.length; s++) {
        amplitude = math.max(amplitude, peaks[s]);
      }

      // Compress the normalized amplitude: audio spends most of its time far
      // below its peak, so a linear band reads as a flat line with occasional
      // spikes. The curve lifts the body without flattening the transients.
      final scaled = math.pow(
        (amplitude / normalizer).clamp(0.0, 1.0),
        TimelineConstants.clipWaveformCurve,
      );

      final height =
          (scaled * volume * band * TimelineConstants.clipWaveformGain).clamp(
            TimelineConstants.clipWaveformMinBarHeight,
            band,
          );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            i * _barStep,
            size.height - height,
            TimelineConstants.clipWaveformBarWidth,
            height,
          ),
          const Radius.circular(TimelineConstants.clipWaveformBarWidth / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(ClipWaveformPainter oldDelegate) =>
      oldDelegate.waveform != waveform ||
      oldDelegate.clipDuration != clipDuration ||
      oldDelegate.volume != volume ||
      oldDelegate.color != color;
}
