// ABOUTME: Reusable rounded icon button for video editor controls
// ABOUTME: Customizable size, colors, and shadow styling

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

/// Rounded icon button.
class DivineIconButton extends StatelessWidget {
  /// Creates a video editor icon button.
  const DivineIconButton({
    this.icon,
    this.iconPath,
    super.key,
    this.backgroundColor = const Color(0xFF101111),
    this.iconColor = Colors.white,
    this.iconSize = 32,
    this.size = 48,
    this.onTap,
    this.semanticLabel,
  }) : assert(icon != null || iconPath != null, 'icon or iconPath is required');

  /// The icon to display.
  final IconData? icon;

  /// The path to the assets svg-icon.
  final String? iconPath;

  /// Background color of the button.
  final Color backgroundColor;

  /// Color of the icon.
  final Color iconColor;

  /// Size of the icon.
  final double iconSize;

  /// Size of the button container.
  final double size;

  /// Callback when the button is tapped.
  final VoidCallback? onTap;

  /// Semantic label for accessibility.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: .circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 1,
                offset: const Offset(1, 1),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 0.6,
                offset: const Offset(0.4, 0.4),
              ),
            ],
          ),
          child: icon != null
              ? Icon(icon, color: iconColor, size: iconSize)
              : Center(
                  child: SizedBox(
                    height: iconSize,
                    width: iconSize,
                    child: SvgPicture.asset(
                      iconPath!,
                      colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
