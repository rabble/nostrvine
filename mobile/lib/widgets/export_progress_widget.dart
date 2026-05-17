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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact =
              constraints.maxWidth < 320 || constraints.maxHeight < 480;
          final outerPadding = isCompact ? 8.0 : 32.0;
          final innerPadding = isCompact ? 12.0 : 24.0;
          final iconSize = isCompact ? 40.0 : 64.0;
          final largeGap = isCompact ? 12.0 : 24.0;
          final smallGap = isCompact ? 8.0 : 16.0;

          return SingleChildScrollView(
            padding: EdgeInsets.all(outerPadding),
            child: Center(
              child: Card(
                color: VineTheme.cardBackground,
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: EdgeInsets.all(innerPadding),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon
                      Icon(
                        _getStageIcon(stage),
                        size: iconSize,
                        color: stage == ExportStage.complete
                            ? VineTheme.success
                            : stage == ExportStage.error
                            ? VineTheme.error
                            : VineTheme.whiteText,
                      ),
                      SizedBox(height: largeGap),

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
                      SizedBox(height: largeGap),

                      // Progress bar
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: VineTheme.cardBackground,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          VineTheme.success,
                        ),
                      ),
                      SizedBox(height: smallGap),

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
                        SizedBox(height: largeGap),
                        TextButton(
                          onPressed: onCancel,
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: VineTheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
