// ABOUTME: Overlay widget showing processing indicator for video clips
// ABOUTME: Displays circular progress indicator while clip is being processed/rendered

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:pro_video_editor/core/models/video/progress_model.dart';
import 'package:pro_video_editor/core/platform/platform_interface.dart';

class VideoClipEditorProcessingOverlay extends StatelessWidget {
  const VideoClipEditorProcessingOverlay({
    required this.clip,
    super.key,
    this.inactivePlaceholder,
    this.isCurrentClip = false,
    this.isProcessing = false,
  });

  /// The clip to show processing status for.
  final RecordingClip clip;
  final bool isProcessing;
  final bool isCurrentClip;
  final Widget? inactivePlaceholder;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: isProcessing || clip.isProcessing
          ? ColoredBox(
              key: ValueKey(
                'Processing-Clip-Overlay-${clip.id}-$isCurrentClip',
              ),
              color: Color.fromARGB(180, 0, 0, 0),
              child: Center(
                // Without RepaintBoundary, the progress indicator repaints
                // the entire screen while it's running.
                child: RepaintBoundary(
                  child: StreamBuilder<ProgressModel>(
                    stream: ProVideoEditor.instance.progressStreamById(clip.id),
                    builder: (context, snapshot) {
                      final progress = snapshot.data?.progress ?? 0;
                      return _PartialCircleSpinner(progress: progress);
                    },
                  ),
                ),
              ),
            )
          : inactivePlaceholder ?? const SizedBox.shrink(),
    );
  }
}

/// Custom circular progress spinner.
/// Animates like a clock from 0 to 360 degrees based on progress.
/// Uses implicit animation for smooth transitions between progress values.
class _PartialCircleSpinner extends StatefulWidget {
  const _PartialCircleSpinner({required this.progress});

  final double progress;

  @override
  State<_PartialCircleSpinner> createState() => _PartialCircleSpinnerState();
}

class _PartialCircleSpinnerState extends State<_PartialCircleSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, value: widget.progress);
  }

  @override
  void didUpdateWidget(_PartialCircleSpinner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.progress != oldWidget.progress) {
      _controller.animateTo(
        widget.progress,
        duration: const Duration(milliseconds: 200),
        curve: Curves.linear,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: 24,
          height: 24,
          child: CustomPaint(
            painter: _PartialCirclePainter(progress: _controller.value),
          ),
        );
      },
    );
  }
}

class _PartialCirclePainter extends CustomPainter {
  _PartialCirclePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final center = Offset(radius, radius);

    // Background circle - the empty/remaining area
    final backgroundPaint = Paint()
      ..color = const Color(0xFF737778)
      ..style = .fill;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Progress pie slice - filled from center to edge like a clock
    final progressPaint = Paint()
      ..color = Colors.white
      ..style = .fill;

    // Draw filled pie slice from 0 to progress, starting from top (12 o'clock)
    const startAngle = -pi / 2;
    final sweepAngle = pi * 2 * progress.clamp(0.0, 1.0);

    if (sweepAngle > 0) {
      canvas.drawArc(
        .fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true, // true = connect to center, creates filled pie slice
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_PartialCirclePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
