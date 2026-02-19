// ABOUTME: Reusable rounded icon button for video editor controls
// ABOUTME: Customizable size, colors, and shadow styling

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

/// Rounded icon button for video editor controls.
///
/// Note: For design system buttons, use [DivineIconButton] from divine_ui.
class VideoEditorIconButton extends StatelessWidget {
  /// Creates a video editor icon button.
  const VideoEditorIconButton({
    required this.iconPath,
    super.key,
    this.backgroundColor = const Color(0xFF000000),
    this.iconColor = Colors.white,
    this.iconSize = 32,
    this.size = 48,
    this.onTap,
    this.semanticLabel,
    this.radius = 20,
  });

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

  final double radius;

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
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Center(
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
