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
    this.backgroundColor,
    this.actionLabel,
    this.onActionPressed,
    this.secondaryActionLabel,
    this.onSecondaryActionPressed,
    super.key,
  });

  /// Returns a fully styled [SnackBar] wrapping a [DivineSnackbarContainer].
  static SnackBar snackBar(
    String message, {
    bool error = false,
    Color? backgroundColor,
    String? actionLabel,
    VoidCallback? onActionPressed,
    String? secondaryActionLabel,
    VoidCallback? onSecondaryActionPressed,
    Duration? duration,
    EdgeInsetsGeometry? margin,
    EdgeInsetsGeometry? padding,
  }) => SnackBar(
    duration: duration ?? const Duration(seconds: 4),
    backgroundColor: VineTheme.transparent,
    elevation: 0,
    padding: padding ?? EdgeInsets.zero,
    behavior: SnackBarBehavior.floating,
    margin: margin,
    content: DivineSnackbarContainer(
      label: message,
      error: error,
      backgroundColor: backgroundColor,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
      secondaryActionLabel: secondaryActionLabel,
      onSecondaryActionPressed: onSecondaryActionPressed,
    ),
  );

  /// The label of the snackbar.
  final String label;

  /// If the snackbar indicates an error.
  final bool error;

  /// Overrides the banner's surface colour.
  ///
  /// For the rare banner whose colour carries the message itself — the
  /// environment indicator in developer options, for instance. Takes
  /// precedence over [error]'s surface, and a light one also flips the label
  /// to dark ink so the banner stays readable.
  final Color? backgroundColor;

  /// The label of the primary action button.
  final String? actionLabel;

  /// Callback when the primary action button is pressed.
  final VoidCallback? onActionPressed;

  /// The label of an optional secondary action button, rendered next to the
  /// primary action in the destructive colour (e.g. a "Delete" alongside a
  /// "Resend"). Shown only when both this and [onSecondaryActionPressed] are
  /// non-null.
  final String? secondaryActionLabel;

  /// Callback when the secondary action button is pressed.
  final VoidCallback? onSecondaryActionPressed;

  /// Label colour that stays legible on the resolved surface.
  ///
  /// A [backgroundColor] comes from the caller, not from the theme, so a light
  /// one (the yellow staging indicator, say) would leave the theme's
  /// white-on-dark label unreadable — those flip to dark ink instead.
  Color _labelColor(VineThemeColors colors) {
    final surface = backgroundColor;
    if (surface != null &&
        ThemeData.estimateBrightnessForColor(surface) == Brightness.light) {
      return VineTheme.primaryDarkGreen;
    }
    return error ? colors.onErrorContainer : colors.primaryText;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    final textStyle = VineTheme.labelLargeFont(color: _labelColor(colors));
    final hasSecondary =
        secondaryActionLabel != null && onSecondaryActionPressed != null;
    final bannerText = Text(label, style: textStyle);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor ?? (error ? colors.errorContainer : colors.card),
        borderRadius: const BorderRadius.all(Radius.circular(16)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: bannerText),
            if (actionLabel != null && onActionPressed != null)
              _ActionButton(
                label: actionLabel!,
                onPressed: onActionPressed!,
                // With a destructive secondary action present, the primary is
                // the affirmative choice (green) even in an error snackbar;
                // a lone action follows the error flag (red on error).
                color: (hasSecondary || !error)
                    ? VineTheme.vineGreen
                    : VineTheme.likeRed,
                textStyle: textStyle,
              ),
            if (hasSecondary)
              _ActionButton(
                label: secondaryActionLabel!,
                onPressed: onSecondaryActionPressed!,
                // Secondary is the destructive choice (e.g. Delete).
                color: VineTheme.likeRed,
                textStyle: textStyle,
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onPressed,
    required this.color,
    required this.textStyle,
  });

  final String label;
  final VoidCallback onPressed;
  final Color color;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        minimumSize: const Size(48, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: textStyle.copyWith(fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}
