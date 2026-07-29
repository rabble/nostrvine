// ABOUTME: Turns a looping player's position stream into a restart signal, so
// ABOUTME: a second player can be re-aligned to it.

import 'dart:async';

/// A backwards jump smaller than this is treated as player jitter rather than
/// a loop restart.
///
/// Position updates arrive from the native side and are not monotonic to the
/// millisecond; a genuine wrap goes back by most of the clip's length, so the
/// gap between the two cases is wide.
const Duration kLoopRestartThreshold = Duration(milliseconds: 250);

/// Emits every time [positions] jumps backwards, i.e. the looping player
/// wrapped around to the start.
///
/// Used to restart a chroma-key backdrop together with the clip it sits
/// behind: the two run on independent native clocks and cannot be kept in
/// lockstep, but re-aligning them at the loop boundary is what the exported
/// composition does too — the backdrop starts at the clip's first frame and
/// tiles from there.
Stream<void> loopRestarts(
  Stream<Duration> positions, {
  Duration threshold = kLoopRestartThreshold,
}) {
  Duration? previous;
  return positions.transform(
    StreamTransformer<Duration, void>.fromHandlers(
      handleData: (position, sink) {
        final last = previous;
        previous = position;
        if (last != null && last - position >= threshold) sink.add(null);
      },
    ),
  );
}
