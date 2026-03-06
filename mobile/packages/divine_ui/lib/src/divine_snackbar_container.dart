import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// {@template divine_snackbar_container}
/// A container widget for displaying snackbars in Divine UI.
/// {@endtemplate}
class DivineSnackbarContainer extends StatelessWidget {
  /// {@macro divine_snackbar_container}
  const DivineSnackbarContainer({
    required this.label,
    this.error = false,
    this.actionLabel,
    this.onActionPressed,
    super.key,
  });

  /// Returns a fully styled [SnackBar] wrapping a [DivineSnackbarContainer].
  static SnackBar snackBar(
    String message, {
    bool error = false,
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) => SnackBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
    padding: EdgeInsets.zero,
    behavior: SnackBarBehavior.floating,
    content: DivineSnackbarContainer(
      label: message,
      error: error,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
    ),
  );

  /// The label of the snackbar.
  final String label;

  /// If the snackbar indicates an error.
  final bool error;

  /// The label of the action button.
  final String? actionLabel;

  /// Callback when the action button is pressed.
  final VoidCallback? onActionPressed;

  @override
  Widget build(BuildContext context) {
    final textStyle = VineTheme.bodyFont(fontWeight: FontWeight.w600);
    late final Widget bannerText;
    if (error) {
      bannerText = Text(
        label,
        style: textStyle.copyWith(color: VineTheme.likeRed),
      );
    } else {
      bannerText = Text(label, style: textStyle);
    }

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
            if (actionLabel != null && onActionPressed != null)
              TextButton(
                onPressed: onActionPressed,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(48, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  actionLabel!,
                  style: textStyle.copyWith(
                    fontWeight: FontWeight.w800,
                    color: error ? VineTheme.likeRed : VineTheme.vineGreen,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
