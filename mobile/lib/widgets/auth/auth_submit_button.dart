// ABOUTME: Styled submit button widget for auth forms
// ABOUTME: Provides consistent button styling with loading state across auth screens

import 'package:flutter/material.dart';
import 'package:openvine/theme/vine_theme.dart';

/// Styled submit button for authentication forms.
///
/// Displays a loading indicator when [isLoading] is true,
/// otherwise shows the [label] text.
class AuthSubmitButton extends StatelessWidget {
  /// Whether the button is in a loading state.
  final bool isLoading;

  /// The button label text.
  final String label;

  /// Callback when button is pressed.
  final VoidCallback? onPressed;

  const AuthSubmitButton({
    required this.isLoading,
    required this.label,
    this.onPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 50,
    child: ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: VineTheme.vineGreen,
        disabledBackgroundColor: Colors.white60,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: VineTheme.vineGreen,
              ),
            )
          : Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
    ),
  );
}
