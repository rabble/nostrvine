import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A styled text field following the Divine design system.
///
/// **Deprecated**: Use [DivineAuthTextField] for authentication screens.
/// Other screens should use a context-appropriate text field component.
@Deprecated('Use DivineAuthTextField for auth screens')
class DivineTextField extends StatelessWidget {
  /// Creates a Divine styled text field.
  @Deprecated('Use DivineAuthTextField for auth screens')
  const DivineTextField({
    super.key,
    this.label,
    @Deprecated('Use label instead') this.labelText,
    this.controller,
    this.focusNode,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.autocorrect = true,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.validator,
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.minLines,
    this.maxLines,
    this.maxLength,
    this.contentPadding,
    this.errorText,
  });

  /// Label text shown inside the field, floats above when focused/filled.
  final String? label;

  /// Deprecated: Use [label] instead.
  @Deprecated('Use label instead')
  final String? labelText;

  /// Controller for the text field.
  final TextEditingController? controller;

  /// Focus node for managing focus state.
  final FocusNode? focusNode;

  /// Whether to obscure text (for passwords).
  final bool obscureText;

  /// Whether the text field is enabled.
  final bool enabled;

  /// Whether the text field is read-only.
  final bool readOnly;

  /// Whether to enable autocorrect.
  final bool autocorrect;

  /// Type of keyboard to display.
  final TextInputType? keyboardType;

  /// Action button on the keyboard.
  final TextInputAction? textInputAction;

  /// Text capitalization behavior.
  final TextCapitalization textCapitalization;

  /// Input formatters for text validation.
  final List<TextInputFormatter>? inputFormatters;

  /// Validator function for form validation.
  final FormFieldValidator<String>? validator;

  /// Called when the field is tapped.
  final VoidCallback? onTap;

  /// Called when the text changes.
  final ValueChanged<String>? onChanged;

  /// Called when the user submits the field.
  final ValueChanged<String>? onSubmitted;

  /// Called when editing is complete.
  final VoidCallback? onEditingComplete;

  /// Minimum number of lines to display.
  final int? minLines;

  /// Maximum number of lines to display.
  final int? maxLines;

  /// Maximum character length allowed.
  final int? maxLength;

  /// Custom content padding for the text field.
  final EdgeInsetsGeometry? contentPadding;

  /// Error message to display below the field.
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final effectiveLabel = label ?? labelText;
    return DivineAuthTextField(
      label: effectiveLabel,
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      enabled: enabled,
      readOnly: readOnly,
      autocorrect: autocorrect,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      validator: validator,
      onTap: onTap,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onEditingComplete: onEditingComplete,
      maxLength: maxLength,
      contentPadding: contentPadding,
      errorText: errorText,
    );
  }
}
