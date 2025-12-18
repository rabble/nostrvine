// ABOUTME: A reusable circular icon button with semi-transparent background.
// ABOUTME: Used for video overlay action buttons (like, comment, share, etc.)
// ABOUTME: and camera control buttons.

import 'package:flutter/material.dart';

/// A circular icon button with a semi-transparent background.
///
/// This widget provides a consistent style for action buttons overlaid on
/// video content, such as like, comment, share, and repost buttons.
///
/// Example usage:
/// ```dart
/// CircularIconButton(
///   onPressed: () => handleLike(),
///   icon: Icon(Icons.favorite, color: Colors.red),
/// )
/// ```
class CircularIconButton extends StatelessWidget {
  /// Creates a circular icon button.
  ///
  /// The [onPressed] and [icon] parameters are required.
  const CircularIconButton({
    required this.onPressed,
    required this.icon,
    super.key,
    this.backgroundOpacity = 0.3,
    this.backgroundColor = Colors.black,
  });

  /// Called when the button is tapped.
  final VoidCallback onPressed;

  /// The icon to display inside the button.
  ///
  /// Typically an [Icon] widget with the desired icon data, color, and size.
  final Widget icon;

  /// The opacity of the background color.
  ///
  /// Defaults to 0.3 for video overlay buttons.
  /// Camera controls typically use 0.5.
  final double backgroundOpacity;

  /// The background color of the button.
  ///
  /// Defaults to [Colors.black].
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor.withValues(alpha: backgroundOpacity),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: icon,
        padding: EdgeInsets.zero,
      ),
    );
  }
}
