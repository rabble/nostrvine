// ABOUTME: A reusable rounded-square icon button with border and shadow.
// ABOUTME: Used for auth screen navigation buttons (back, info, switch account).

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// A rounded-square icon button matching the design system's "icon button"
/// component.
///
/// Used for navigation and action buttons in auth screens (back, info,
/// switch account). For circular video overlay buttons, use
/// [CircularIconButton] instead.
///
/// Example usage:
/// ```dart
/// RoundedIconButton(
///   onPressed: () => context.pop(),
///   icon: Icon(Icons.chevron_left, color: VineTheme.vineGreenLight, size: 28),
/// )
/// ```
class RoundedIconButton extends StatelessWidget {
  /// Creates a rounded-square icon button.
  const RoundedIconButton({
    required this.onPressed,
    required this.icon,
    super.key,
  });

  /// Called when the button is tapped. When null, the button is visually
  /// unchanged but the tap is ignored.
  final VoidCallback? onPressed;

  /// The icon to display inside the button.
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 48,
        width: 48,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: VineTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: VineTheme.outlineMuted, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 0.6,
              offset: Offset(0.4, 0.4),
            ),
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 1,
              offset: Offset(1, 1),
            ),
          ],
        ),
        child: icon,
      ),
    );
  }
}
