// ABOUTME: Consistent gradient background widget for auth screens
// ABOUTME: Provides the green gradient styling used across login/register screens

import 'package:flutter/material.dart';
import 'package:openvine/theme/vine_theme.dart';

/// Gradient background container for authentication screens.
///
/// Provides consistent styling across all auth-related screens with
/// the VineTheme green gradient.
class AuthGradientBackground extends StatelessWidget {
  /// The child widget to display on top of the gradient.
  final Widget child;

  const AuthGradientBackground({required this.child, super.key});

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [VineTheme.vineGreen, Color(0xFF2D8B6F)],
      ),
    ),
    child: child,
  );
}
