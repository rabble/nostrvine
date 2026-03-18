// ABOUTME: Widget for smooth interpolated time display during video playback
// ABOUTME: Uses Ticker for 60 FPS updates between position updates from video player

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/utils/video_editor_utils.dart';

/// A reusable smooth time display widget that interpolates video position
/// updates.
///
/// Uses a Ticker to provide smooth ~60 FPS updates between video player
/// position updates.
class SmoothTimeDisplay extends StatefulWidget {
  /// Creates a smooth time display.
  const SmoothTimeDisplay({
    required this.isPlayingSelector,
    required this.currentPositionSelector,
    this.style,
    this.formatter,
    super.key,
  });

  /// Selector that extracts playing state from [ClipEditorState].
  final bool Function(ClipEditorState state) isPlayingSelector;

  /// Selector that extracts current position from [ClipEditorState].
  final Duration Function(ClipEditorState state) currentPositionSelector;

  /// Text style for the time display
  final TextStyle? style;

  /// Custom duration formatter. Defaults to 'SS.MS' format (e.g., "12.34")
  final String Function(Duration)? formatter;

  @override
  State<SmoothTimeDisplay> createState() => _SmoothTimeDisplayState();
}

class _SmoothTimeDisplayState extends State<SmoothTimeDisplay>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  Duration _lastKnownPosition = Duration.zero;
  DateTime? _lastUpdateTime;
  StreamSubscription<ClipEditorState>? _subscription;

  bool _previousIsPlaying = false;
  Duration _previousPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Set up BLoC subscription on first build
    if (_subscription == null) {
      final bloc = context.read<ClipEditorBloc>();
      final state = bloc.state;

      _lastKnownPosition = widget.currentPositionSelector(state);
      _lastUpdateTime = DateTime.now();
      _previousIsPlaying = widget.isPlayingSelector(state);
      _previousPosition = _lastKnownPosition;

      // Start ticker if already playing
      if (_previousIsPlaying && !_ticker.isActive) {
        _ticker.start();
      }

      _subscription = bloc.stream.listen(_onBlocStateChanged);
    }
  }

  void _onBlocStateChanged(ClipEditorState state) {
    final isPlaying = widget.isPlayingSelector(state);
    final position = widget.currentPositionSelector(state);

    // Handle play/pause changes
    if (isPlaying != _previousIsPlaying) {
      _previousIsPlaying = isPlaying;
      if (isPlaying) {
        _lastUpdateTime = DateTime.now();
        if (!_ticker.isActive) {
          _ticker.start();
        }
      } else {
        _ticker.stop();
        if (mounted) setState(() {});
      }
    }

    // Handle position changes
    if ((position - _previousPosition).abs() >
        const Duration(milliseconds: 10)) {
      _previousPosition = position;
      _lastKnownPosition = position;
      _lastUpdateTime = DateTime.now();
      if (mounted) setState(() {});
    }
  }

  void _onTick(Duration elapsed) {
    if (mounted) setState(() {});
  }

  Duration get _displayPosition {
    if (!_previousIsPlaying || _lastUpdateTime == null) {
      return _lastKnownPosition;
    }

    // Interpolate: add elapsed time since last update
    final elapsed = DateTime.now().difference(_lastUpdateTime!);
    return _lastKnownPosition + elapsed;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style =
        widget.style ??
        const TextStyle(
          color: VineTheme.whiteText,
          fontSize: 14,
          fontWeight: .w800,
          letterSpacing: 0.1,
          fontFeatures: [.tabularFigures()],
        );

    return RepaintBoundary(
      child: Text(_displayPosition.toFormattedSeconds(), style: style),
    );
  }
}
