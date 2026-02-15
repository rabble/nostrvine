import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A styled text field following the Divine design system.
///
/// Features a container with rounded corners and a floating label that
/// animates when the field is focused or has content.
///
/// For password fields, set [obscureText] to true to enable the visibility
/// toggle icon.
///
/// Example usage:
/// ```dart
/// DivineTextField(
///   label: 'Email',
///   controller: _emailController,
///   keyboardType: TextInputType.emailAddress,
/// )
///
/// DivineTextField(
///   label: 'Password',
///   controller: _passwordController,
///   obscureText: true,
/// )
/// ```
class DivineTextField extends StatefulWidget {
  /// Creates a Divine styled text field.
  const DivineTextField({
    this.label,
    this.labelText,
    super.key,
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
  });

  /// Label text shown inside the field, floats above when focused/filled.
  final String? label;

  /// Alternative label text parameter for backward compatibility.
  final String? labelText;

  /// Controller for the text field.
  final TextEditingController? controller;

  /// Focus node for managing focus state.
  final FocusNode? focusNode;

  /// Whether to obscure text (for passwords).
  ///
  /// When true, shows a visibility toggle icon.
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

  /// Custom content padding for the input decoration.
  final EdgeInsetsGeometry? contentPadding;

  /// Resolved label text, preferring [label] over [labelText].
  String? get _resolvedLabel => label ?? labelText;

  @override
  State<DivineTextField> createState() => _DivineTextFieldState();
}

class _DivineTextFieldState extends State<DivineTextField> {
  late FocusNode _focusNode;
  late TextEditingController _controller;
  bool _isObscured = true;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _controller = widget.controller ?? TextEditingController();
    _focusNode.addListener(_handleFocusChange);
    _controller.addListener(_handleTextChange);
  }

  @override
  void didUpdateWidget(DivineTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      _focusNode.removeListener(_handleFocusChange);
      _focusNode = widget.focusNode ?? FocusNode();
      _focusNode.addListener(_handleFocusChange);
    }
    if (widget.controller != oldWidget.controller) {
      _controller.removeListener(_handleTextChange);
      _controller = widget.controller ?? TextEditingController();
      _controller.addListener(_handleTextChange);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _handleFocusChange() {
    setState(() {});
  }

  void _handleTextChange() {
    setState(() {});
  }

  void _toggleObscured() {
    setState(() => _isObscured = !_isObscured);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: VineTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: widget.obscureText ? 8 : 24,
          top: 16,
          bottom: 16,
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildTextField(),
            ),
            if (widget.obscureText) _buildVisibilityToggle(),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField() {
    final showObscured = widget.obscureText && _isObscured;

    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      obscureText: showObscured,
      obscuringCharacter: '✱',
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      autocorrect: widget.autocorrect,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      inputFormatters: widget.inputFormatters,
      minLines: widget.minLines,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      maxLength: widget.maxLength,
      onTap: widget.onTap,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      onEditingComplete: widget.onEditingComplete,
      style: VineTheme.bodyLargeFont(color: VineTheme.onSurface),
      cursorColor: VineTheme.primary,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: widget.contentPadding ?? EdgeInsets.zero,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        filled: false,
        labelText: widget._resolvedLabel,
        labelStyle: VineTheme.bodyLargeFont(color: VineTheme.onSurfaceMuted),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        floatingLabelStyle: VineTheme.labelSmallFont(color: VineTheme.primary),
      ),
    );
  }

  Widget _buildVisibilityToggle() {
    return GestureDetector(
      onTap: _toggleObscured,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: DivineIcon(
          icon: _isObscured ? DivineIconName.eye : DivineIconName.eyeSlash,
          color: VineTheme.onSurfaceMuted,
        ),
      ),
    );
  }
}
