// ABOUTME: Reusable rounded icon button for video editor controls
// ABOUTME: Customizable size, colors, and shadow styling

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// Rounded icon button for video editor controls.
///
/// Note: For design system buttons, use [DivineIconButton] from divine_ui.
class VideoEditorIconButton extends StatelessWidget {
  /// Creates a video editor icon button.
  const VideoEditorIconButton({
    required this.icon,
    super.key,
    this.backgroundColor = const Color(0xFF000000),
    this.iconColor = Colors.white,
    this.iconSize = 32,
    this.size = 48,
    this.onTap,
    this.semanticLabel,
  });

  /// The name of the icon.
  final DivineIconName icon;

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
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: DivineIcon(size: iconSize, icon: icon, color: iconColor),
          ),
        ),
      ),
    );
  }
}
