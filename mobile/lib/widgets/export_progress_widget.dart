// ABOUTME: Widget displaying export progress with stage tracking
// ABOUTME: Shows progress bar, percentage, stage text, and optional cancel button

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/models/export_progress.dart';

class ExportProgressWidget extends StatelessWidget {
  const ExportProgressWidget({
    required this.stage,
    required this.progress,
    super.key,
    this.onCancel,
  });

  final ExportStage stage;
  final double progress; // 0.0 to 1.0
  final VoidCallback? onCancel;

  String _getStageText(ExportStage stage) {
    switch (stage) {
      case ExportStage.concatenating:
        return 'Combining clips...';
      case ExportStage.applyingTextOverlay:
        return 'Adding text overlay...';
      case ExportStage.mixingAudio:
        return 'Adding sound...';
      case ExportStage.generatingThumbnail:
        return 'Generating thumbnail...';
      case ExportStage.complete:
        return 'Export complete!';
      case ExportStage.error:
        return 'Export failed';
    }
  }

  IconData _getStageIcon(ExportStage stage) {
    switch (stage) {
      case ExportStage.complete:
        return Icons.check_circle;
      case ExportStage.error:
        return Icons.error;
      default:
        return Icons.movie_creation;
    }
  }

  @override
  Widget build(BuildContext context) {
    final percentageText = '${(progress * 100).toInt()}%';

    return ColoredBox(
      color: VineTheme.backgroundColor.withValues(alpha: 0.9),
      child: Center(
        child: Card(
          color: VineTheme.cardBackground,
          margin: const EdgeInsets.all(32.0),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Icon(
                  _getStageIcon(stage),
                  size: 64,
                  color: stage == ExportStage.complete
                      ? VineTheme.success
                      : stage == ExportStage.error
                      ? VineTheme.error
                      : VineTheme.whiteText,
                ),
                const SizedBox(height: 24),

                // Stage text
                Text(
                  _getStageText(stage),
                  style: const TextStyle(
                    color: VineTheme.whiteText,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Progress bar
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: VineTheme.cardBackground,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    VineTheme.success,
                  ),
                ),
                const SizedBox(height: 16),

                // Percentage
                Text(
                  percentageText,
                  style: const TextStyle(
                    color: VineTheme.whiteText,
                    fontSize: 16,
                  ),
                ),

                // Cancel button (if provided)
                if (onCancel != null) ...[
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: onCancel,
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: VineTheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
