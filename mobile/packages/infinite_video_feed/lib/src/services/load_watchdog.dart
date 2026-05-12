import 'dart:async';

import 'package:divine_video_player/divine_video_player.dart';

/// Detects videos that stay in a buffering or idle state for longer than
/// a configured threshold and notifies the owner so it can fail over to
/// the next playback source.
///
/// One timer is kept per index; calling [start] for an index cancels and
/// restarts that index's watchdog. The watchdog auto-stops as soon as the
/// underlying controller leaves the loading states.
class LoadWatchdog {
  /// Creates a watchdog that fires [onSlowLoad] when the controller for
  /// an index stays buffering/idle longer than [threshold].
  LoadWatchdog({
    required Duration threshold,
    required void Function(int index) onSlowLoad,
    required void Function(String message) log,
  }) : _threshold = threshold,
       _onSlowLoad = onSlowLoad,
       _log = log;

  /// How long to give a controller to leave buffering/idle before
  /// triggering source failover.
  final Duration _threshold;

  /// Called when the watchdog times out. Receives the affected video index.
  final void Function(int) _onSlowLoad;
  final void Function(String) _log;

  final _timers = <int, Timer>{};
  final _stopwatches = <int, Stopwatch>{};

  /// Starts (or restarts) the watchdog for [index] using [controller] to
  /// read playback status. Does nothing when [controller] is null.
  void start(int index, DivineVideoPlayerController? controller) {
    stop(index);
    if (controller == null) return;

    final sw = Stopwatch()..start();
    _stopwatches[index] = sw;

    _timers[index] = Timer.periodic(const Duration(seconds: 1), (_) {
      final status = controller.state.status;

      if (!status.isBuffering && !status.isIdle) {
        stop(index);
        return;
      }

      if (sw.elapsed >= _threshold) {
        stop(index);
        _log(
          'Slow load index $index: '
          'elapsed=${sw.elapsed.inMilliseconds}ms — trying next source',
        );
        _onSlowLoad(index);
      }
    });
  }

  /// Cancels the watchdog for [index].
  void stop(int index) {
    _timers.remove(index)?.cancel();
    _stopwatches.remove(index)?.stop();
  }

  /// Cancels every watchdog. Safe to call from `State.dispose`.
  void disposeAll() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    for (final sw in _stopwatches.values) {
      sw.stop();
    }
    _stopwatches.clear();
  }
}
