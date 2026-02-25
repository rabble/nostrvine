// ABOUTME: Reusable back button for authentication flow screens
// ABOUTME: Green rounded-square button with chevron icon

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/widgets/rounded_icon_button.dart';

/// A green rounded-square back button used in authentication flow screens.
///
/// Displays a chevron-left icon inside a rounded-square container.
/// Automatically calls `context.pop()` when pressed, or uses a custom
/// [onPressed] callback if provided.
class AuthBackButton extends StatelessWidget {
  /// Creates an authentication flow back button.
  ///
  /// If [onPressed] is null, the button will call `context.pop()`.
  const AuthBackButton({super.key, this.onPressed});

  /// Optional custom callback when the button is pressed.
  ///
  /// If null, defaults to `context.pop()`.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return RoundedIconButton(
      onPressed: onPressed ?? () => context.pop(),
      icon: const Icon(
        Icons.chevron_left,
        color: VineTheme.vineGreenLight,
        size: 24,
      ),
    );
  }
}
