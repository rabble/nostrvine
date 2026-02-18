import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A styled text field for the authentication flow.
///
/// Designed specifically for sign-in and sign-up screens with a fixed-height
/// container (76px per Figma spec), rounded corners, and an animated floating
/// label.
///
/// For password fields, set [obscureText] to true to enable the visibility
/// toggle icon.
///
/// Example usage:
/// ```dart
/// DivineAuthTextField(
///   label: 'Email',
///   controller: _emailController,
///   keyboardType: TextInputType.emailAddress,
/// )
///
/// DivineAuthTextField(
///   label: 'Password',
///   controller: _passwordController,
///   obscureText: true,
/// )
/// ```
class DivineAuthTextField extends StatefulWidget {
  /// Creates a Divine styled text field for authentication screens.
  const DivineAuthTextField({
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
    this.maxLength,
    this.contentPadding,
    this.errorText,
  });

  /// Label text shown inside the field, floats above when focused/filled.
  final String? label;

  /// Deprecated: Use [label] instead.
  @Deprecated('Use label instead')
  final String? labelText;

  /// The effective label to display (prefers [label] over deprecated
  /// labelText).
  // ignore: deprecated_member_use_from_same_package
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

  /// Maximum character length allowed.
  final int? maxLength;

  /// Custom content padding for the text field.
  final EdgeInsetsGeometry? contentPadding;

  /// Error message to display below the field.
  ///
  /// When non-null, the field shows an error state: red border, error overlay
  /// background, error-colored floating label, and the error message with a
  /// warning icon below the container.
  final String? errorText;

  @override
  State<DivineAuthTextField> createState() => _DivineAuthTextFieldState();
}

class _DivineAuthTextFieldState extends State<DivineAuthTextField> {
  late FocusNode _focusNode;
  late TextEditingController _controller;
  bool _isObscured = true;
  bool _hasFocus = false;
  String? _validatorError;

  bool get _hasText => _controller.text.isNotEmpty;
  bool get _isFloating => _hasFocus || _hasText;
  String? get _effectiveError => widget.errorText ?? _validatorError;
  bool get _hasError => _effectiveError != null;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _controller = widget.controller ?? TextEditingController();
    _focusNode.addListener(_handleFocusChange);
    _controller.addListener(_handleTextChange);
  }

  @override
  void didUpdateWidget(DivineAuthTextField oldWidget) {
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
    // Clear validator error when user edits the field.
    if (_validatorError != null) {
      setState(() => _validatorError = null);
    } else {
      setState(() {});
    }
  }

  /// Wraps the validator to capture its error message for display
  /// via the error supporting text instead of the built-in error.
  String? _wrappedValidator(String? value) {
    final error = widget.validator?.call(value);
    // Schedule a post-frame callback to update error state after validation,
    // since setState cannot be called during build/validation.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _validatorError != error) {
        setState(() => _validatorError = error);
      }
    });
    return error;
  }

  void _handleContainerTap() {
    if (!widget.enabled) return;

    if (!widget.readOnly) {
      _focusNode.requestFocus();
    }
    widget.onTap?.call();
  }

  void _toggleObscured() {
    setState(() => _isObscured = !_isObscured);
  }

  /// Figma specs for field height breakdown:
  /// 16px padding + 16px label + 4px gap + 24px input + 16px padding = 76px
  static const double _totalHeight = 76;
  static const double _horizontalPadding = 24;

  @override
  Widget build(BuildContext context) {
    final label = widget.effectiveLabel;
    final hasLabel = label != null && label.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: _totalHeight,
          decoration: BoxDecoration(
            color: _hasError
                ? VineTheme.errorOverlay
                : VineTheme.surfaceContainer,
            borderRadius: BorderRadius.circular(24),
            border: _hasError
                ? Border.all(color: VineTheme.error, width: 2)
                : null,
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
                    child: _AuthTextFieldContent(
                      label: label,
                      hasLabel: hasLabel,
                      isFloating: _isFloating,
                      hasError: _hasError,
                      child: _AuthTextFieldInput(
                        controller: _controller,
                        focusNode: _focusNode,
                        obscureText: widget.obscureText && _isObscured,
                        enabled: widget.enabled,
                        readOnly: widget.readOnly,
                        autocorrect: widget.autocorrect,
                        keyboardType: widget.keyboardType,
                        textInputAction: widget.textInputAction,
                        textCapitalization: widget.textCapitalization,
                        inputFormatters: widget.inputFormatters,
                        validator: _wrappedValidator,
                        onTap: widget.onTap,
                        onChanged: widget.onChanged,
                        onSubmitted: widget.onSubmitted,
                        onEditingComplete: widget.onEditingComplete,
                        maxLength: widget.maxLength,
                        contentPadding: widget.contentPadding,
                        hasError: _hasError,
                      ),
                    ),
                  ),
                ),
                if (widget.obscureText)
                  _VisibilityToggle(
                    isObscured: _isObscured,
                    hasText: _hasText,
                    onToggle: _toggleObscured,
                  ),
              ],
            ),
          ),
        ),
        if (_hasError) _ErrorSupportingText(errorText: _effectiveError!),
      ],
    );
  }
}

/// The animated content area with floating label and text input.
class _AuthTextFieldContent extends StatelessWidget {
  const _AuthTextFieldContent({
    required this.label,
    required this.hasLabel,
    required this.isFloating,
    required this.hasError,
    required this.child,
  });

  final String? label;
  final bool hasLabel;
  final bool isFloating;
  final bool hasError;
  final Widget child;

  static const double _verticalPadding = 16;
  static const double _labelLineHeight = 16;
  static const double _labelGap = 4;
  static const double _inputLineHeight = 24;
  static const double _totalHeight = 76;

  /// Duration for the floating label transition animation.
  static const Duration _animationDuration = Duration(milliseconds: 200);

  /// Label top offset when floating above the input (16px).
  static const double _labelTopFloating = _verticalPadding;

  /// Label top offset when centered with the input (26px).
  static const double _labelTopCentered = (_totalHeight - _inputLineHeight) / 2;

  /// Input top offset when the label is floating (36px).
  static const double _inputTopFloating =
      _verticalPadding + _labelLineHeight + _labelGap;

  /// Input top offset when centered, no floating label (26px).
  static const double _inputTopCentered = (_totalHeight - _inputLineHeight) / 2;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (hasLabel)
          AnimatedPositioned(
            duration: _animationDuration,
            curve: Curves.easeOut,
            top: isFloating ? _labelTopFloating : _labelTopCentered,
            left: 0,
            right: 0,
            child: AnimatedDefaultTextStyle(
              duration: _animationDuration,
              curve: Curves.easeOut,
              style: isFloating
                  ? VineTheme.labelSmallFont(
                      color: hasError ? VineTheme.error : VineTheme.primary,
                    )
                  : VineTheme.bodyLargeFont(
                      color: VineTheme.onSurfaceMuted,
                    ),
              child: Text(label!),
            ),
          ),
        AnimatedPositioned(
          duration: _animationDuration,
          curve: Curves.easeOut,
          top: isFloating ? _inputTopFloating : _inputTopCentered,
          left: 0,
          right: 0,
          height: _inputLineHeight,
          child: child,
        ),
      ],
    );
  }
}

/// The inner text form field with all input configuration.
class _AuthTextFieldInput extends StatelessWidget {
  const _AuthTextFieldInput({
    required this.controller,
    required this.focusNode,
    required this.obscureText,
    required this.enabled,
    required this.readOnly,
    required this.autocorrect,
    required this.textCapitalization,
    required this.hasError,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.validator,
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.maxLength,
    this.contentPadding,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final bool autocorrect;
  final bool hasError;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final FormFieldValidator<String>? validator;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;
  final int? maxLength;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      obscuringCharacter: '✱',
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
      onFieldSubmitted: onSubmitted,
      onEditingComplete: onEditingComplete,
      maxLength: maxLength,
      style: VineTheme.bodyLargeFont(color: VineTheme.onSurface),
      cursorColor: hasError ? VineTheme.error : VineTheme.primary,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: contentPadding ?? EdgeInsets.zero,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        filled: false,
        // Hide the built-in error text from TextFormField.
        // Error display is handled by _ErrorSupportingText via errorText.
        errorStyle: const TextStyle(fontSize: 0, height: 0),
      ),
    );
  }
}

/// The error message row shown below the field container.
///
/// Displays a [DivineIconName.warningCircle] icon and the error text,
/// both in [VineTheme.error] color per the Figma spec.
class _ErrorSupportingText extends StatelessWidget {
  const _ErrorSupportingText({required this.errorText});

  final String errorText;

  static const double _horizontalPadding = 24;
  static const double _iconSize = 16;
  static const double _iconTextGap = 4;
  static const double _verticalPadding = 2;
  static const double _topGap = 4;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: _horizontalPadding,
        right: _horizontalPadding,
        top: _topGap,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: _verticalPadding),
            child: DivineIcon(
              icon: DivineIconName.warningCircle,
              size: _iconSize,
              color: VineTheme.error,
            ),
          ),
          const SizedBox(width: _iconTextGap),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: _verticalPadding,
              ),
              child: Text(
                errorText,
                style: VineTheme.bodySmallFont(
                  color: VineTheme.error,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The password visibility toggle button with semantic label.
class _VisibilityToggle extends StatelessWidget {
  const _VisibilityToggle({
    required this.isObscured,
    required this.hasText,
    required this.onToggle,
  });

  final bool isObscured;
  final bool hasText;
  final VoidCallback onToggle;

  /// Right padding for the visibility toggle icon.
  ///
  /// Ensures equal spacing from the icon to all container edges
  /// (26px): vertical = (76 - 24) / 2 = 26px,
  /// right = 18 + parent padding 8 = 26px.
  static const double _iconRightPadding = 18;

  /// Left, top, and bottom padding for the visibility toggle.
  static const double _iconOtherPadding = 8;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: isObscured ? 'Show password' : 'Hide password',
      button: true,
      child: GestureDetector(
        onTap: onToggle,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.only(
            left: _iconOtherPadding,
            top: _iconOtherPadding,
            bottom: _iconOtherPadding,
            right: _iconRightPadding,
          ),
          child: DivineIcon(
            icon: isObscured ? DivineIconName.eye : DivineIconName.eyeSlash,
            color: hasText ? VineTheme.onSurface : VineTheme.onSurfaceMuted,
          ),
        ),
      ),
    );
  }
}
