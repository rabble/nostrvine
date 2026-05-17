import 'package:flutter/widgets.dart';

/// Shared gesture-arena gating for shutter widgets that expose both a
/// tap and a long-press to start/stop recording on the same target.
///
/// Tracks whether the in-progress recording was started by a long-press
/// on this widget. Without this guard, an incidental long-touch on the
/// shutter while a tap-started take is already running would call
/// `stopRecording` on release, producing a phantom click that
/// interrupts the take. See issue #4409.
mixin ShutterLongPressMixin<T extends StatefulWidget> on State<T> {
  bool _startedByLongPress = false;

  /// Wrap the tap handler. Resets the long-press flag, then invokes
  /// [toggle] (typically `notifier.toggleRecording`).
  void handleShutterTap(VoidCallback toggle) {
    _startedByLongPress = false;
    toggle();
  }

  /// Wrap the long-press-start handler. Only flips the flag and calls
  /// [start] when no recording is in progress; if a tap-started take
  /// is already running, the long-press is treated as incidental.
  void handleShutterLongPressStart({
    required bool isRecording,
    required VoidCallback start,
  }) {
    if (isRecording) return;
    _startedByLongPress = true;
    start();
  }

  /// Wrap the long-press-up handler. Only invokes [stop] if this
  /// long-press actually started the recording.
  void handleShutterLongPressUp(VoidCallback stop) {
    if (!_startedByLongPress) return;
    _startedByLongPress = false;
    stop();
  }
}
