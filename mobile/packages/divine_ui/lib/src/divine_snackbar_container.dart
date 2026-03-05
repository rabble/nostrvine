import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// {@template divine_snackbar_container}
/// A styled snackbar content widget from the Divine design system.
///
/// Supports the following variants:
/// - Text only
/// - Text with close button
/// - Text with action button
/// - Text with action and close button
///
/// Each variant has a default (dark) and error (red) color scheme.
/// {@endtemplate}
class DivineSnackbarContainer extends StatelessWidget {
  /// {@macro divine_snackbar_container}
  const DivineSnackbarContainer({
    required this.label,
    this.error = false,
    this.actionLabel,
    this.onActionPressed,
    this.onClose,
    super.key,
  });

  /// The label of the snackbar.
  final String label;

  /// If the snackbar indicates an error.
  final bool error;

  /// The label of the action button.
  final String? actionLabel;

  /// Callback when the action button is pressed.
  final VoidCallback? onActionPressed;

  /// Callback when the close button is pressed.
  ///
  /// When provided, a close (X) icon is displayed on the trailing edge.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final textStyle = VineTheme.bodyFont(fontWeight: FontWeight.w600);
    final bannerText = Text(
      label,
      style: textStyle.copyWith(
        color: error ? VineTheme.likeRed : null,
      ),
    );

    final hasAction = actionLabel != null && onActionPressed != null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: error ? VineTheme.errorContainer : VineTheme.cardBackground,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: bannerText),
            if (hasAction)
              TextButton(
                onPressed: onActionPressed,
                child: Text(
                  actionLabel!,
                  style: textStyle.copyWith(
                    fontWeight: FontWeight.w800,
                    color: error ? VineTheme.likeRed : VineTheme.vineGreen,
                  ),
                ),
              ),
            if (onClose != null)
              Semantics(
                label: 'Close',
                button: true,
                child: GestureDetector(
                  onTap: onClose,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: EdgeInsets.only(left: hasAction ? 8 : 0),
                    child: DivineIcon(
                      icon: DivineIconName.x,
                      size: 20,
                      color: error ? VineTheme.likeRed : VineTheme.whiteText,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
