import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DivineTextField extends StatefulWidget {
  const DivineTextField({
    required this.controller,
    super.key,
    this.label,
    this.focusNode,
    this.keyboardType = .text,
    this.textInputAction,
    this.textCapitalization = .sentences,
    this.minLines,
    this.maxLines,
    this.contentPadding = const .all(16),
    this.inputFormatters,
    this.onSubmitted,
    this.onChanged,
  });

  final String? label;
  final FocusNode? focusNode;
  final TextEditingController controller;

  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;

  final int? minLines;
  final int? maxLines;

  final EdgeInsets contentPadding;
  final List<TextInputFormatter>? inputFormatters;

  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  State<DivineTextField> createState() => _DivineTextFieldState();
}

class _DivineTextFieldState extends State<DivineTextField> {
  FocusNode? _internalFocusNode;
  bool _isFocused = false;

  FocusNode get _focusNode => widget.focusNode ?? _internalFocusNode!;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) {
      _internalFocusNode = FocusNode();
    }
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _internalFocusNode?.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    _isFocused = _focusNode.hasFocus;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return TextSelectionTheme(
      data: Theme.of(context).textSelectionTheme.copyWith(
        cursorColor: const Color(0xFF27C58B),
        selectionColor: const Color(0xFF27C58B).withAlpha(80),
        selectionHandleColor: const Color(0xFF27C58B),
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        textCapitalization: widget.textCapitalization,
        minLines: widget.minLines,
        maxLines: widget.maxLines,
        onSubmitted: widget.onSubmitted,
        onChanged: widget.onChanged,
        inputFormatters: widget.inputFormatters,
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: VineTheme.bodyFont(
            color: Color(0xB6FFFFFF),
            fontSize: 16,
            fontWeight: .w400,
            height: 1.50,
            letterSpacing: 0.15,
          ),
          border: .none,
          enabledBorder: .none,
          focusedBorder: .none,
          filled: false,
          contentPadding: widget.contentPadding,
          floatingLabelStyle: VineTheme.bodyFont(
            color: _isFocused ? const Color(0xFF27C58B) : Color(0xB6FFFFFF),
            // The TextField scale the floating-label by a factor of 0.75.
            fontSize: 11 / 0.75,
            fontWeight: .w600,
            height: 1.45,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
