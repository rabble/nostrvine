import 'package:flutter/widgets.dart';

/// Shared shutter gesture handling for recorder surfaces that support both
/// tap-to-toggle and long-press-to-record on the same target.
///
/// Contract:
/// - All recorder shutter surfaces that combine tap and long-press gestures
///   must route through this widget.
/// - A tap-started recording must never be stopped by an incidental
///   long-press release.
/// - In press-down mode, a press on an already-active recording (started by
///   any other source — volume key, BLE remote, toggle, or a dropped release)
///   must still stop it, so the button is never a dead control.
///
/// This encodes the issue #4409 regression guard once so new shutter surfaces
/// inherit the same behavior by default instead of reimplementing it.
class ShutterGestureDetector extends StatefulWidget {
  const ShutterGestureDetector({
    required this.child,
    required this.isEnabled,
    required this.isRecording,
    required this.onTapToggle,
    required this.onLongPressStartRecording,
    required this.onLongPressStopRecording,
    super.key,
    this.isLongPressSupported = true,
    this.startsRecordingOnPressDown = false,
    this.onLongPressMoveUpdate,
    this.behavior,
  });

  final Widget child;
  final bool isEnabled;
  final bool isRecording;
  final bool isLongPressSupported;
  final bool startsRecordingOnPressDown;
  final VoidCallback onTapToggle;
  final VoidCallback onLongPressStartRecording;
  final VoidCallback onLongPressStopRecording;
  final GestureLongPressMoveUpdateCallback? onLongPressMoveUpdate;
  final HitTestBehavior? behavior;

  @override
  State<ShutterGestureDetector> createState() => _ShutterGestureDetectorState();
}

class _ShutterGestureDetectorState extends State<ShutterGestureDetector> {
  bool _startedByLongPress = false;
  bool _startedByPressDown = false;

  void _handleTap() {
    _startedByLongPress = false;
    _startedByPressDown = false;
    widget.onTapToggle();
  }

  void _handleTapDown(TapDownDetails _) {
    if (widget.isRecording) {
      // A fresh press-down while recording is already active means this
      // gesture didn't start it (volume key, BLE remote, toggle, or a release
      // event that never arrived). Without stopping here the press-down button
      // is a dead control: _handlePressEnd bails on !_startedByPressDown and
      // tap / long-press handlers are disabled in press-down mode.
      _startedByPressDown = false;
      widget.onLongPressStopRecording();
      return;
    }
    _startedByPressDown = true;
    widget.onLongPressStartRecording();
  }

  void _handlePressEnd() {
    if (!_startedByPressDown) return;
    _startedByPressDown = false;
    widget.onLongPressStopRecording();
  }

  void _handleLongPressStart(LongPressStartDetails _) {
    if (widget.isRecording) return;
    _startedByLongPress = true;
    widget.onLongPressStartRecording();
  }

  void _handleLongPressUp() {
    if (!_startedByLongPress) return;
    _startedByLongPress = false;
    widget.onLongPressStopRecording();
  }

  @override
  Widget build(BuildContext context) {
    final usePressDownRecording =
        widget.isEnabled && widget.startsRecordingOnPressDown;

    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: usePressDownRecording ? _handleTapDown : null,
      onTapUp: usePressDownRecording ? (_) => _handlePressEnd() : null,
      onTapCancel: usePressDownRecording ? _handlePressEnd : null,
      onTap: widget.isEnabled && !widget.startsRecordingOnPressDown
          ? _handleTap
          : null,
      onLongPressStart:
          widget.isEnabled &&
              widget.isLongPressSupported &&
              !widget.startsRecordingOnPressDown
          ? _handleLongPressStart
          : null,
      onLongPressMoveUpdate:
          widget.isRecording &&
              widget.isLongPressSupported &&
              !widget.startsRecordingOnPressDown
          ? widget.onLongPressMoveUpdate
          : null,
      onLongPressUp:
          widget.isLongPressSupported && !widget.startsRecordingOnPressDown
          ? _handleLongPressUp
          : null,
      child: widget.child,
    );
  }
}
