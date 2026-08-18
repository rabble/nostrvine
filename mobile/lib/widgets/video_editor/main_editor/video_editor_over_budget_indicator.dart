import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';

/// Overlay indicator shown when the video editor exceeds the max duration.
///
/// Displays a semi-transparent scrim with a label and description centered
/// on screen to inform the user that the total clip duration exceeds the
/// maximum allowed duration.
class OverBudgetIndicator extends StatelessWidget {
  const OverBudgetIndicator({
    required this.maxDurationSeconds,
    super.key,
  });

  /// The maximum allowed duration in seconds.
  final int maxDurationSeconds;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return IgnorePointer(
      child: ColoredBox(
        color: context.vineColors.background.withValues(alpha: 0.85),
        child: SizedBox.expand(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l10n.videoEditorOverBudgetLabel,
                  style: VineTheme.titleLargeFont(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.videoEditorOverBudgetDescription(maxDurationSeconds),
                  style: VineTheme.bodyMediumFont(
                    color: VineTheme.secondaryText,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
