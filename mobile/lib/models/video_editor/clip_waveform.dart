// ABOUTME: A video clip's audio waveform, reduced to one peak per sample.
// ABOUTME: Produced by ClipWaveformManager, drawn by the timeline clip strip.

import 'package:flutter/foundation.dart';

/// A clip's audio waveform, reduced to one peak per sample.
@immutable
class ClipWaveform {
  const ClipWaveform({
    required this.peaks,
    required this.duration,
    required this.peak,
  });

  /// A waveform with no samples — used for clips whose file carries no
  /// readable audio track.
  const ClipWaveform.empty()
    : peaks = const [],
      duration = Duration.zero,
      peak = 0;

  /// Peak amplitude (0..1) per sample, spanning [duration] of the source file.
  ///
  /// Stereo sources are merged to the louder channel per sample: the strip
  /// draws a single band, so a per-channel split would only halve the detail.
  final List<double> peaks;

  /// Span of audio [peaks] covers. Can be shorter than the clip's video
  /// duration when the audio track ends early.
  final Duration duration;

  /// The loudest sample in [peaks]. Real recordings rarely approach full scale,
  /// so the strip normalizes against this instead of against 1.0 — otherwise a
  /// perfectly audible clip draws as a barely-there ripple.
  final double peak;

  bool get isEmpty => peaks.isEmpty || duration <= Duration.zero;
}
