import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/video_editor_utils.dart';
import 'package:sound_service/sound_service.dart';

class AudioEditorSelectionOverlay extends StatelessWidget {
  const AudioEditorSelectionOverlay({
    required this.audio,
    required this.audioService,
    required this.onTogglePlayState,
    required this.onTapDone,
    super.key,
  });

  final AudioEvent audio;
  final AudioPlaybackService audioService;
  final VoidCallback onTogglePlayState;
  final VoidCallback onTapDone;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const .fromLTRB(8, 0, 8, 8),
        constraints: const BoxConstraints(minHeight: 56),
        padding: const .symmetric(horizontal: 16, vertical: 20),
        decoration: ShapeDecoration(
          color: VineTheme.containerLow,
          shape: RoundedRectangleBorder(borderRadius: .circular(24)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    audio.title ?? context.l10n.videoEditorAudioUntitledSound,
                    style: VineTheme.titleMediumFont(
                      color: VineTheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: .ellipsis,
                  ),
                  Text.rich(
                    TextSpan(
                      style: VineTheme.bodyMediumFont(
                        color: VineTheme.onSurfaceVariant,
                      ),
                      children: [
                        TextSpan(
                          text: Duration(
                            seconds: max((audio.duration ?? 0).toInt(), 1),
                          ).toMmSs(),
                          style: const TextStyle(
                            fontFeatures: [.tabularFigures()],
                          ),
                        ),
                        if (audio.source != null) ...[
                          const TextSpan(text: ' ∙ '),
                          TextSpan(text: audio.source),
                        ],
                      ],
                    ),
                    maxLines: 1,
                    overflow: .ellipsis,
                  ),
                ],
              ),
            ),

            _AudioPlaybackProgressButton(
              audioService: audioService,
              onPressed: onTogglePlayState,
            ),
            DivineIconButton(
              type: .tertiary,
              size: .small,
              icon: .caretRight,
              semanticLabel: context.l10n.videoEditorDoneSemanticLabel,
              onPressed: onTapDone,
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioPlaybackProgressButton extends StatelessWidget {
  const _AudioPlaybackProgressButton({
    required this.audioService,
    required this.onPressed,
  });

  final AudioPlaybackService audioService;
  final VoidCallback onPressed;

  static const double _buttonVisualSize = 42;
  static const double _buttonBorderRadius = 16;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: audioService.playingStream,
      initialData: audioService.isPlaying,
      builder: (context, playingSnapshot) {
        final isPlaying = playingSnapshot.data ?? false;
        return StreamBuilder<Duration?>(
          stream: audioService.durationStream,
          initialData: audioService.duration,
          builder: (context, durationSnapshot) {
            return StreamBuilder<Duration>(
              stream: audioService.positionStream,
              initialData: Duration.zero,
              builder: (context, positionSnapshot) {
                final durationMs = durationSnapshot.data?.inMilliseconds ?? 0;
                final positionMs = positionSnapshot.data?.inMilliseconds ?? 0;
                final progress = durationMs <= 0
                    ? 0.0
                    : (positionMs / durationMs).clamp(0.0, 1.0);

                return SizedBox.square(
                  dimension: _buttonVisualSize,
                  child: CustomPaint(
                    foregroundPainter: _CircularProgressBorderPainter(
                      progress: progress,
                      borderRadius: _buttonBorderRadius,
                    ),
                    child: Center(
                      child: DivineIconButton(
                        type: .ghostSecondary,
                        icon: isPlaying ? .pauseFill : .playFill,
                        semanticLabel: isPlaying
                            ? context
                                  .l10n
                                  .videoEditorAudioPausePreviewSemanticLabel
                            : context
                                  .l10n
                                  .videoEditorAudioPlayPreviewSemanticLabel,
                        onPressed: onPressed,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _CircularProgressBorderPainter extends CustomPainter {
  const _CircularProgressBorderPainter({
    required this.progress,
    required this.borderRadius,
  });

  final double progress;
  final double borderRadius;
  static const double _innerInset = 1;

  @override
  void paint(Canvas canvas, Size size) {
    final clampedProgress = progress.clamp(0.0, 1.0);
    if (clampedProgress <= 0) {
      return;
    }

    final strokePaint = Paint()
      ..color = VineTheme.primary
      ..style = .stroke
      ..strokeWidth = 2
      ..strokeCap = .round;

    final rect = Offset.zero & size;
    final insetRect = rect.deflate((strokePaint.strokeWidth / 2) + _innerInset);
    final radius = borderRadius.clamp(0.0, insetRect.shortestSide / 2);

    // Build the rounded-rect path manually starting at top-center going
    // clockwise, so path offset 0 is exactly the visual top-center.
    final left = insetRect.left;
    final top = insetRect.top;
    final right = insetRect.right;
    final bottom = insetRect.bottom;
    final centerX = insetRect.center.dx;

    final path = Path()
      ..moveTo(centerX, top)
      // Top edge: top-center -> top-right corner start.
      ..lineTo(right - radius, top)
      // Top-right corner.
      ..arcToPoint(Offset(right, top + radius), radius: Radius.circular(radius))
      // Right edge.
      ..lineTo(right, bottom - radius)
      // Bottom-right corner.
      ..arcToPoint(
        Offset(right - radius, bottom),
        radius: Radius.circular(radius),
      )
      // Bottom edge.
      ..lineTo(left + radius, bottom)
      // Bottom-left corner.
      ..arcToPoint(
        Offset(left, bottom - radius),
        radius: Radius.circular(radius),
      )
      // Left edge.
      ..lineTo(left, top + radius)
      // Top-left corner.
      ..arcToPoint(Offset(left + radius, top), radius: Radius.circular(radius))
      // Back to top-center to close the loop.
      ..lineTo(centerX, top);

    final metric = path.computeMetrics().firstOrNull;
    if (metric == null) {
      return;
    }

    final drawLength = metric.length * clampedProgress;
    final progressPath = metric.extractPath(0, drawLength);

    canvas.drawPath(progressPath, strokePaint);
  }

  @override
  bool shouldRepaint(_CircularProgressBorderPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        borderRadius != oldDelegate.borderRadius;
  }
}
