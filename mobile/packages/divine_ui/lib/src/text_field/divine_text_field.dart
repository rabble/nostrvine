import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A styled text field following the Divine design system.
///
/// Features a container with rounded corners and a floating label that
/// appears when the field is focused or has content.
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
    this.contentPadding,
  });

  /// Label text shown inside the field, floats above when focused/filled.
  final String? label;

  /// Deprecated: Use [label] instead.
  @Deprecated('Use label instead')
  final String? labelText;

  /// The effective label to display (prefers [label] over [labelText]).
  String? get effectiveLabel => label ?? labelText;

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

  /// Custom content padding for the text field.
  final EdgeInsetsGeometry? contentPadding;

  @override
  State<DivineTextField> createState() => _DivineTextFieldState();
}

class _DivineTextFieldState extends State<DivineTextField> {
  late FocusNode _focusNode;
  late TextEditingController _controller;
  bool _isObscured = true;
  bool _hasFocus = false;

  bool get _hasText => _controller.text.isNotEmpty;
  bool get _isFloating => _hasFocus || _hasText;

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
    setState(() => _hasFocus = _focusNode.hasFocus);
  }

  void _handleTextChange() {
    setState(() {});
  }

  void _handleContainerTap() {
    if (widget.enabled && !widget.readOnly) {
      _focusNode.requestFocus();
    }
    widget.onTap?.call();
  }

  void _toggleObscured() {
    setState(() => _isObscured = !_isObscured);
  }

  // Figma specs: 76px total = 16px padding + 16px label + 4px gap + 24px input + 16px padding
  static const double _totalHeight = 76.0;
  static const double _horizontalPadding = 24.0;
  static const double _verticalPadding = 16.0;
  static const double _labelLineHeight = 16.0;
  static const double _labelGap = 4.0;
  static const double _inputLineHeight = 24.0;

  // Animation duration for label transition
  static const Duration _animationDuration = Duration(milliseconds: 200);

  // Label positions
  static const double _labelTopFloating = _verticalPadding; // 16px
  static const double _labelTopCentered =
      (_totalHeight - _inputLineHeight) / 2; // 26px (centered with input)
  static const double _inputTopFloating =
      _verticalPadding + _labelLineHeight + _labelGap; // 36px
  static const double _inputTopCentered =
      (_totalHeight - _inputLineHeight) / 2; // 26px

  @override
  Widget build(BuildContext context) {
    final label = widget.effectiveLabel;
    final hasLabel = label != null && label.isNotEmpty;

    return Container(
      height: _totalHeight,
      decoration: BoxDecoration(
        color: VineTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: _horizontalPadding,
          right: widget.obscureText ? 8 : _horizontalPadding,
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _handleContainerTap,
                behavior: HitTestBehavior.opaque,
                child: _buildContent(label, hasLabel),
              ),
            ),
            if (widget.obscureText) _buildVisibilityToggle(),
          ],
        ),
      ),
    );
  }

  /// Builds the content area with animated label and text field.
  Widget _buildContent(String? label, bool hasLabel) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Animated label - moves from center to top when floating
        if (hasLabel)
          AnimatedPositioned(
            duration: _animationDuration,
            curve: Curves.easeOut,
            top: _isFloating ? _labelTopFloating : _labelTopCentered,
            left: 0,
            right: 0,
            child: AnimatedDefaultTextStyle(
              duration: _animationDuration,
              curve: Curves.easeOut,
              style: _isFloating
                  ? VineTheme.labelSmallFont(color: VineTheme.primary)
                  : VineTheme.bodyLargeFont(color: VineTheme.onSurfaceMuted),
              child: Text(label!),
            ),
          ),
        // TextField - animates position when label floats
        AnimatedPositioned(
          duration: _animationDuration,
          curve: Curves.easeOut,
          top: _isFloating ? _inputTopFloating : _inputTopCentered,
          left: 0,
          right: 0,
          height: _inputLineHeight,
          child: _buildTextField(),
        ),
      ],
    );
  }

  Widget _buildTextField() {
    final showObscured = widget.obscureText && _isObscured;

    return TextFormField(
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
      validator: widget.validator,
      onTap: widget.onTap,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      onEditingComplete: widget.onEditingComplete,
      minLines: widget.minLines,
      maxLines: widget.obscureText ? 1 : (widget.maxLines ?? 1),
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
        // No hintText - animated label serves as both hint and floating label
        errorStyle: VineTheme.bodySmallFont(color: VineTheme.error),
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
          size: 24,
          color: VineTheme.onSurfaceMuted,
        ),
      ),
    );
  }
}
