// ABOUTME: Styled text field widget for auth forms
// ABOUTME: Provides consistent input decoration across login/register screens

import 'package:flutter/material.dart';

/// Styled text field for authentication forms.
///
/// Provides consistent styling with prefix icon, optional visibility toggle
/// for password fields, and form validation support.
class AuthTextField extends StatelessWidget {
  /// Controller for the text field.
  final TextEditingController controller;

  /// Label text displayed above the input.
  final String label;

  /// Icon displayed at the start of the input.
  final IconData icon;

  /// Whether to obscure the text (for passwords).
  final bool obscureText;

  /// Callback to toggle password visibility.
  final VoidCallback? onToggleObscure;

  /// Form field validator.
  final String? Function(String?)? validator;

  /// Keyboard type for the input.
  final TextInputType? keyboardType;

  /// Whether to disable autocorrect.
  final bool autocorrect;

  const AuthTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.onToggleObscure,
    this.validator,
    this.keyboardType,
    this.autocorrect = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    obscureText: obscureText,
    keyboardType: keyboardType,
    autocorrect: autocorrect,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: onToggleObscure != null
          ? IconButton(
              icon: Icon(
                obscureText ? Icons.visibility_off : Icons.visibility,
                color: Colors.white60,
              ),
              onPressed: onToggleObscure,
            )
          : null,
    ),
    validator: validator,
  );
}
