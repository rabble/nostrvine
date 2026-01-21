import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/utils/video_editor_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

/// A reusable smooth time display widget that interpolates video position
/// updates.
///
/// Uses a Ticker to provide smooth ~60 FPS updates between video player
/// position updates.
class SmoothTimeDisplay extends ConsumerStatefulWidget {
  /// Creates a smooth time display.
  const SmoothTimeDisplay({
    required this.isPlayingSelector,
    required this.currentPositionSelector,
    this.style,
    this.formatter,
    super.key,
  });

  /// Provider selector that returns whether video is currently playing
  final ProviderListenable<bool> isPlayingSelector;

  /// Provider selector that returns current video position
  final ProviderListenable<Duration> currentPositionSelector;

  /// Text style for the time display
  final TextStyle? style;

  /// Custom duration formatter. Defaults to 'SS.MS' format (e.g., "12.34")
  final String Function(Duration)? formatter;

  @override
  ConsumerState<SmoothTimeDisplay> createState() => _SmoothTimeDisplayState();
}

class _SmoothTimeDisplayState extends ConsumerState<SmoothTimeDisplay>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  Duration _lastKnownPosition = Duration.zero;
  DateTime? _lastUpdateTime;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);

    // Initialize with current position
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _lastKnownPosition = ref.read(widget.currentPositionSelector);
        _lastUpdateTime = DateTime.now();

        // Start ticker if already playing
        final isPlaying = ref.read(widget.isPlayingSelector);
        if (isPlaying && !_ticker.isActive) {
          _ticker.start();
        }

        setState(() {});
      }
    });

    // Listen to playing state changes
    ref
      ..listenManual(widget.isPlayingSelector, (previous, next) async {
        if (next) {
          // Start ticker when playing
          _lastUpdateTime = DateTime.now();
          if (!_ticker.isActive) {
            await _ticker.start();
          }
        } else {
          // Stop ticker when paused
          _ticker.stop();
          if (mounted) {
            setState(() {});
          }
        }
      })
      // Listen to position changes
      ..listenManual(widget.currentPositionSelector, (previous, next) {
        if ((next - _lastKnownPosition).abs() >
            const Duration(milliseconds: 50)) {
          _lastKnownPosition = next;
          _lastUpdateTime = DateTime.now();
          if (mounted) {
            setState(() {});
          }
        }
      });
  }

  void _onTick(Duration elapsed) {
    // Only called when ticker is active (i.e., when playing)
    if (mounted) {
      setState(() {});
    }
  }

  Duration get _displayPosition {
    final isPlaying = ref.read(widget.isPlayingSelector);

    if (!isPlaying || _lastUpdateTime == null) {
      return _lastKnownPosition;
    }

    // Interpolate: add elapsed time since last update
    final elapsed = DateTime.now().difference(_lastUpdateTime!);
    return _lastKnownPosition + elapsed;
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style =
        widget.style ??
        const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: .w800,
          letterSpacing: 0.1,
        );

    return Text(_displayPosition.toFormattedSeconds(), style: style);
  }
}
