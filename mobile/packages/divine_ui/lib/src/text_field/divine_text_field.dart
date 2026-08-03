import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A styled text field following the Divine design system.
class DivineTextField extends StatelessWidget {
  /// Creates a Divine styled text field.
  const DivineTextField({
    super.key,
    this.labelText,
    this.hintText,
    this.helperText,
    this.minLines,
    this.maxLines,
    this.maxLength,
    this.enabled,
    this.autocorrect,
    this.readOnly = false,
    this.obscureText = false,
    this.canRequestFocus = true,
    this.expands = false,
    this.contentPadding = defaultContentPadding,
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
    this.primaryWhenFilled = false,
    this.autofocus = false,
    this.spellCheckConfiguration,
    this.filled = false,
    this.fillColor,
    this.suffixIcon,
  });

  /// Default content padding around the input. Exposed so overlays
  /// (e.g. character counters) can stay aligned with the field's edges.
  static const EdgeInsets defaultContentPadding = EdgeInsets.all(16);

  /// Corner radius of the surface painted when [filled] is set.
  static const double fillBorderRadius = 16;

  /// Shapes the [filled] surface without painting a stroke.
  ///
  /// Underline rather than outline: Material notches a floating label onto an
  /// outline's top edge, which strands the label above a fill that has no
  /// stroke to sit on. The underline variant floats it inside the surface, and
  /// an explicit radius still rounds all four corners.
  ///
  /// Typed as [InputBorder] rather than inferred: hot reload keeps the value a
  /// `static final` was first initialised with, so a narrower inferred type
  /// would throw on the stale instance after this line is edited.
  static final InputBorder _fillBorder = UnderlineInputBorder(
    borderRadius: BorderRadius.circular(fillBorderRadius),
    borderSide: BorderSide.none,
  );

  /// Label text shown inside the field when empty, floats above when focused.
  final String? labelText;

  /// Example input shown once the label has floated out of the way.
  ///
  /// Material only reveals the hint after the label floats (on focus or
  /// content), so use it for an example rather than for the field's name —
  /// that belongs in [labelText].
  final String? hintText;

  /// Persistent note rendered below the field, e.g. "Required".
  final String? helperText;

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

  /// Whether the floating label uses [VineTheme.primary] when the field
  /// has content (in addition to when it is focused).
  final bool primaryWhenFilled;

  /// Configures the spell check / "Replace" suggestion flow.
  ///
  /// Defaults to [defaultSpellCheckConfiguration], which enables the native
  /// spell checker so natural-language fields get misspelling underlines and
  /// replacement suggestions for free. On platforms without a native spell
  /// check service (desktop, tests) it is a harmless no-op. Pass an explicit
  /// config to override, e.g. `SpellCheckConfiguration.disabled()` for
  /// technical inputs (search, keys, URLs) where spell check adds noise.
  final SpellCheckConfiguration? spellCheckConfiguration;

  /// The spell check configuration used when [spellCheckConfiguration] is not
  /// provided.
  ///
  /// Uses [RegionAwareSpellCheckService] so the platform checker receives a
  /// region-qualified locale (iOS' `UITextChecker` returns nothing for a bare
  /// language code). Supplying a service explicitly also means this never trips
  /// the framework assertion that fires when spell check is enabled on a
  /// platform with no native service (desktop, widget tests); there it simply
  /// yields no suggestions instead of throwing.
  static final SpellCheckConfiguration defaultSpellCheckConfiguration =
      SpellCheckConfiguration(
        spellCheckService: RegionAwareSpellCheckService(),
      );

  /// {@macro flutter.widgets.editableText.autofocus}
  final bool autofocus;

  /// Whether the field paints a surface behind the input.
  ///
  /// Off by default, so the field is transparent and takes the colour of
  /// whatever it sits on. Set this when the field sits directly on a sheet or
  /// page background and would otherwise have no visible edge.
  final bool filled;

  /// Surface colour used when [filled] is set.
  ///
  /// Defaults to `containerLow`, which lifts off both the page background and
  /// the bottom-sheet surface.
  final Color? fillColor;

  /// Widget rendered inside the field, after the input.
  ///
  /// For an action that belongs to the value being entered — paste, clear,
  /// scan. Material centres it vertically, so it stays put as a multi-line
  /// field grows. Prefer a [DivineIconButton] over a raw icon so the slot
  /// keeps a 48px tap target.
  final Widget? suffixIcon;

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
      autofocus: autofocus,
      spellCheckConfiguration:
          spellCheckConfiguration ?? defaultSpellCheckConfiguration,
      onTap: onTap,
      onEditingComplete: onEditingComplete,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        helperText: helperText,
        suffixIcon: suffixIcon,
        labelStyle: VineTheme.bodyLargeFont(
          color: context.vineColors.onSurfaceVariant,
        ),
        hintStyle: VineTheme.bodyLargeFont(
          color: context.vineColors.onSurfaceMuted,
        ),
        helperStyle: VineTheme.labelSmallFont(
          color: context.vineColors.onSurfaceMuted,
        ),
        // The fill takes its shape from the border's outer path, and every
        // state needs it — InputBorder.none paints a plain rectangle, so a
        // missing state would square the corners off on focus.
        border: filled ? _fillBorder : InputBorder.none,
        enabledBorder: filled ? _fillBorder : InputBorder.none,
        focusedBorder: filled ? _fillBorder : InputBorder.none,
        filled: filled,
        fillColor: filled
            ? (fillColor ?? context.vineColors.containerLow)
            : null,
        contentPadding: contentPadding,
        floatingLabelStyle: WidgetStateTextStyle.resolveWith((states) {
          // Why: the resolver reads `controller?.text` synchronously on each
          // Material rebuild without subscribing to the controller. Safe
          // because Flutter's [TextField] re-resolves this style whenever
          // its text changes, so the read happens at the right moment.
          final isFilled =
              primaryWhenFilled && (controller?.text.isNotEmpty ?? false);
          return VineTheme.labelSmallFont(
            color: states.contains(WidgetState.focused) || isFilled
                ? VineTheme.primary
                : context.vineColors.onSurfaceVariant,
          ).copyWith(
            // The TextField scale the floating-label by a factor of 0.75.
            fontSize: 11 / 0.75,
          );
        }),
      ),
    );
  }
}
