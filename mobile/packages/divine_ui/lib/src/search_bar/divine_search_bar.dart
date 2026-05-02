import 'package:divine_ui/src/icon/divine_icon.dart';
import 'package:divine_ui/src/theme/vine_theme.dart';
import 'package:flutter/material.dart';

/// A reusable search bar styled to match the Divine design system.
///
/// Supports both interactive (text input) and read-only (tap to navigate)
/// modes via the [readOnly] and [onTap] parameters.
class DivineSearchBar extends StatelessWidget {
  /// Creates a [DivineSearchBar].
  const DivineSearchBar({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText = 'Find something cool...',
    this.isLoading = false,
    this.readOnly = false,
    this.onTap,
    this.suffixIcon,
    this.onChanged,
    this.onSubmitted,
  });

  /// Controls the text being edited.
  final TextEditingController? controller;

  /// Defines the keyboard focus for this widget.
  final FocusNode? focusNode;

  /// Placeholder text shown when the field is empty.
  final String hintText;

  /// When true, shows a spinner instead of the search icon.
  final bool isLoading;

  /// When true, disables text input (use with [onTap] for navigation).
  final bool readOnly;

  /// Called when the search bar is tapped.
  final VoidCallback? onTap;

  /// Optional trailing widget (e.g. a clear button or filter icon).
  final Widget? suffixIcon;

  /// Called when the text changes.
  final ValueChanged<String>? onChanged;

  /// Called when the user submits the text.
  final ValueChanged<String>? onSubmitted;

  void _handleSubmitted(BuildContext context, String value) {
    // Search should behave like a committed action: forward the query first,
    // then dismiss the keyboard so results remain visible.
    onSubmitted?.call(value);
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Material(
        color: Colors.transparent,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          readOnly: readOnly,
          onTap: onTap,
          onChanged: onChanged,
          onSubmitted: (value) => _handleSubmitted(context, value),
          // Match mobile search-field behavior by dismissing focus when the
          // user taps away instead of leaving the keyboard covering results.
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          // Surface the search action directly on the soft keyboard instead of
          // the generic return key.
          textInputAction: TextInputAction.search,
          style: VineTheme.bodyLargeFont(),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: VineTheme.bodyLargeFont(
              color: VineTheme.onSurfaceMuted55,
            ),
            filled: true,
            fillColor: VineTheme.iconButtonBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            prefixIconConstraints: const BoxConstraints(),
            prefixIcon: _PrefixIcon(isLoading: isLoading),
            suffixIconConstraints: const BoxConstraints(),
            suffixIcon: suffixIcon,
          ),
        ),
      ),
    );
  }
}

class _PrefixIcon extends StatelessWidget {
  const _PrefixIcon({required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
      child: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: Padding(
                padding: EdgeInsets.all(2),
                child: CircularProgressIndicator(
                  color: VineTheme.vineGreen,
                  strokeWidth: 2,
                ),
              ),
            )
          : const DivineIcon(icon: .search, color: VineTheme.onSurfaceMuted55),
    );
  }
}
