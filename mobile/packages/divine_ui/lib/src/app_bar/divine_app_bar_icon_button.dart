import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A styled icon button for use in [DiVineAppBar].
///
/// Renders icons in a rounded container with consistent styling
/// matching the AppShell design system.
///
/// Example usage:
/// ```dart
/// DiVineAppBarIconButton(
///   icon: const SvgIconSource('assets/icon/CaretLeft.svg'),
///   onPressed: () => context.pop(),
///   semanticLabel: 'Go back',
/// )
/// ```
class DiVineAppBarIconButton extends StatelessWidget {
  /// Creates a DiVineAppBar icon button.
  const DiVineAppBarIconButton({
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.semanticLabel,
    this.backgroundColor,
    this.iconColor,
    this.size = 48,
    this.iconSize = 32,
    this.borderRadius = 20,
    super.key,
  });

  /// The icon to display.
  final IconSource icon;

  /// Called when the button is tapped.
  final VoidCallback? onPressed;

  /// Tooltip text shown on long press.
  final String? tooltip;

  /// Semantic label for accessibility.
  final String? semanticLabel;

  /// Background color of the button container.
  ///
  /// Defaults to [VineTheme.iconButtonBackground].
  final Color? backgroundColor;

  /// Color of the icon.
  ///
  /// Defaults to [VineTheme.whiteText].
  final Color? iconColor;

  /// Size of the button container.
  ///
  /// Defaults to 48.
  final double size;

  /// Size of the icon within the container.
  ///
  /// Defaults to 32.
  final double iconSize;

  /// Border radius of the button container.
  ///
  /// Defaults to 20 for a pill-shaped appearance.
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final effectiveBackgroundColor =
        backgroundColor ?? VineTheme.iconButtonBackground;
    final effectiveIconColor = iconColor ?? VineTheme.whiteText;

    Widget buttonContent = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: effectiveBackgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: switch (icon) {
          SvgIconSource(:final assetPath) => SizedBox(
            width: iconSize,
            height: iconSize,
            child: SvgPicture.asset(
              assetPath,
              colorFilter: ColorFilter.mode(
                effectiveIconColor,
                BlendMode.srcIn,
              ),
            ),
          ),
          MaterialIconSource(:final iconData) => Icon(
            iconData,
            color: effectiveIconColor,
            size: iconSize,
          ),
        },
      ),
    );

    if (tooltip != null) {
      buttonContent = Tooltip(
        message: tooltip,
        child: buttonContent,
      );
    }

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onPressed,
        child: buttonContent,
      ),
    );
  }
}
