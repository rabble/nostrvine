import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A styled text field following the Divine design system.
class DivineTextField extends StatelessWidget {
  /// Creates a Divine styled text field.
  const DivineTextField({
    super.key,
    this.labelText,
    this.minLines,
    this.maxLines,
    this.maxLength,
    this.enabled,
    this.autocorrect,
    this.readOnly = false,
    this.obscureText = false,
    this.canRequestFocus = true,
    this.expands = false,
    this.contentPadding = const .all(16),
    this.focusNode,
    this.controller,
    this.keyboardType = .text,
    this.textInputAction,
    this.textCapitalization = .sentences,
    this.inputFormatters,
    this.onTap,
    this.onEditingComplete,
    this.onSubmitted,
    this.onChanged,
  });

  /// Label text shown inside the field when empty, floats above when focused.
  final String? labelText;

  /// Minimum number of lines to display.
  final int? minLines;

  /// Maximum number of lines to display.
  final int? maxLines;

  /// Maximum character length allowed.
  final int? maxLength;

  /// Whether the text field is enabled.
  final bool? enabled;

  /// Whether to enable autocorrect.
  final bool? autocorrect;

  /// Whether the text field is read-only.
  final bool readOnly;

  /// Whether to obscure text (for passwords).
  final bool obscureText;

  /// Whether the field can request focus.
  final bool canRequestFocus;

  /// Whether the field expands to fill available space.
  final bool expands;

  /// Padding around the input content.
  final EdgeInsets contentPadding;

  /// Focus node for managing focus state.
  final FocusNode? focusNode;

  /// Controller for the text field.
  final TextEditingController? controller;

  /// Type of keyboard to display.
  final TextInputType? keyboardType;

  /// Action button on the keyboard.
  final TextInputAction? textInputAction;

  /// Text capitalization behavior.
  final TextCapitalization textCapitalization;

  /// Input formatters for text validation.
  final List<TextInputFormatter>? inputFormatters;

  /// Called when the field is tapped.
  final VoidCallback? onTap;

  /// Called when editing is complete.
  final VoidCallback? onEditingComplete;

  /// Called when the user submits the field.
  final ValueChanged<String>? onSubmitted;

  /// Called when the text changes.
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      minLines: minLines,
      maxLines: maxLines,
      maxLength: maxLength,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      inputFormatters: inputFormatters,
      enabled: enabled,
      readOnly: readOnly,
      autocorrect: autocorrect,
      obscureText: obscureText,
      canRequestFocus: canRequestFocus,
      expands: expands,
      onTap: onTap,
      onEditingComplete: onEditingComplete,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: VineTheme.bodyFont(
          color: VineTheme.onSurfaceVariant,
          height: 1.50,
          letterSpacing: 0.15,
        ),
        border: .none,
        enabledBorder: .none,
        focusedBorder: .none,
        filled: false,
        contentPadding: contentPadding,
        floatingLabelStyle: WidgetStateTextStyle.resolveWith((states) {
          return VineTheme.bodyFont(
            color: states.contains(WidgetState.focused)
                ? VineTheme.primary
                : VineTheme.onSurfaceVariant,
            // The TextField scale the floating-label by a factor of 0.75.
            fontSize: 11 / 0.75,
            height: 1.45,
            letterSpacing: 0.5,
            fontWeight: .w600,
          );
        }),
      ),
    );
  }
}
