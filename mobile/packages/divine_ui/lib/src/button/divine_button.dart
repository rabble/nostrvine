import 'package:divine_ui/src/icon/divine_icon.dart';
import 'package:divine_ui/src/theme/vine_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// The visual style type of a [DivineButton].
enum DivineButtonType {
  /// Primary button with green background and dark text.
  /// Use for primary actions like "Submit", "Continue", "Save".
  primary,

  /// Secondary button with dark background, green border, and green text.
  /// Use for secondary actions that need visibility but aren't primary.
  secondary,

  /// Tertiary button with white background and dark green text.
  /// Use for high-contrast actions on dark backgrounds.
  tertiary,

  /// Ghost button with semi-transparent dark background (65% black)
  /// and white text. Use for actions overlaying content like video controls.
  ghost,

  /// Ghost secondary button with lighter scrim (15% black) and white text.
  /// Use for subtle actions on various backgrounds.
  ghostSecondary,

  /// Link button with no background, underlined text.
  /// Use for inline text links and low-emphasis actions.
  link,

  /// Error/destructive button with red background and light text.
  /// Use for destructive actions like "Delete", "Remove".
  error,
}

/// The size of a [DivineButton].
enum DivineButtonSize {
  /// Small button: 16px horizontal padding, 8px vertical, 16px border radius.
  small,

  /// Base/medium button: 24px horizontal padding, 12px vertical, 20px border radius.
  base,
}

/// A customizable button component following the Divine design system.
///
/// The button's appearance is determined by [type] and [size]. The disabled
/// state is automatically applied when [onPressed] is null.
///
/// Example usage:
/// ```dart
/// DivineButton(
///   label: 'Continue',
///   onPressed: () => doSomething(),
/// )
///
/// DivineButton(
///   label: 'Delete',
///   type: DivineButtonType.error,
///   onPressed: canDelete ? () => delete() : null, // null = disabled
/// )
///
/// DivineButton(
///   label: 'Continue with email',
///   leadingIcon: DivineIconName.envelope,
///   onPressed: () => continueWithEmail(),
/// )
/// ```
class DivineButton extends StatelessWidget {
  /// Creates a Divine design system button.
  const DivineButton({
    required this.label,
    required this.onPressed,
    this.type = DivineButtonType.primary,
    this.size = DivineButtonSize.base,
    this.leadingIcon,
    this.trailingIcon,
    this.expanded = false,
    super.key,
  });

  /// The text label displayed on the button.
  final String label;

  /// Called when the button is tapped.
  /// If null, the button is displayed in its disabled state.
  final VoidCallback? onPressed;

  /// The visual style type of the button.
  final DivineButtonType type;

  /// The size of the button.
  final DivineButtonSize size;

  /// Optional icon displayed before the label.
  ///
  /// The icon color and size are determined automatically based on [type]
  /// and [size].
  final DivineIconName? leadingIcon;

  /// Optional icon displayed after the label.
  ///
  /// The icon color and size are determined automatically based on [type]
  /// and [size].
  final DivineIconName? trailingIcon;

  /// Whether the button should expand to fill available width.
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return _DivineButtonContent(
      label: label,
      onPressed: onPressed,
      type: type,
      size: size,
      leadingIcon: leadingIcon,
      trailingIcon: trailingIcon,
      expanded: expanded,
    );
  }
}

class _DivineButtonContent extends StatelessWidget {
  const _DivineButtonContent({
    required this.label,
    required this.onPressed,
    required this.type,
    required this.size,
    required this.expanded,
    this.leadingIcon,
    this.trailingIcon,
  });

  final String label;
  final VoidCallback? onPressed;
  final DivineButtonType type;
  final DivineButtonSize size;
  final DivineIconName? leadingIcon;
  final DivineIconName? trailingIcon;
  final bool expanded;

  bool get _isEnabled => onPressed != null;

  double get _iconSize => switch (size) {
    DivineButtonSize.small => 20,
    DivineButtonSize.base => 24,
  };

  EdgeInsets get _padding => switch (size) {
    DivineButtonSize.small => const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 8,
    ),
    DivineButtonSize.base => const EdgeInsets.symmetric(
      horizontal: 24,
      vertical: 12,
    ),
  };

  double get _borderRadius => switch (size) {
    DivineButtonSize.small => 16,
    DivineButtonSize.base => 20,
  };

  double get _disabledOpacity => switch (type) {
    DivineButtonType.error => 0.5,
    _ => 0.32,
  };

  Color get _backgroundColor => switch (type) {
    DivineButtonType.primary => VineTheme.primary,
    DivineButtonType.secondary => VineTheme.surfaceContainer,
    DivineButtonType.tertiary => VineTheme.inverseSurface,
    DivineButtonType.ghost => VineTheme.scrim65,
    DivineButtonType.ghostSecondary => VineTheme.scrim15,
    DivineButtonType.link => Colors.transparent,
    DivineButtonType.error => VineTheme.error,
  };

  Color get _foregroundColor => switch (type) {
    DivineButtonType.primary => VineTheme.onPrimary,
    DivineButtonType.secondary => VineTheme.primary,
    DivineButtonType.tertiary => VineTheme.inverseOnSurface,
    DivineButtonType.ghost ||
    DivineButtonType.ghostSecondary => VineTheme.onSurface,
    DivineButtonType.link => VineTheme.onSurfaceVariant,
    DivineButtonType.error => VineTheme.onErrorContainer,
  };

  Color? get _borderColor => switch (type) {
    DivineButtonType.secondary => VineTheme.outlineMuted,
    _ => null,
  };

  TextStyle get _textStyle {
    final baseStyle = type == DivineButtonType.link
        ? VineTheme.bodyLargeFont(color: _foregroundColor).copyWith(
            decoration: TextDecoration.underline,
            decorationColor: VineTheme.primary,
            decorationThickness: 2,
          )
        : VineTheme.titleMediumFont(color: _foregroundColor);

    return baseStyle;
  }

  List<BoxShadow>? get _boxShadow {
    // Link buttons have no shadow
    if (type == DivineButtonType.link) return null;
    // Disabled primary buttons have no shadow
    if (!_isEnabled && type == DivineButtonType.primary) return null;

    return const [
      BoxShadow(
        color: Color(0x1A000000),
        offset: Offset(0.4, 0.4),
        blurRadius: 0.6,
      ),
      BoxShadow(
        color: Color(0x1A000000),
        offset: Offset(1, 1),
        blurRadius: 1,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leadingIcon != null) ...[
          DivineIcon(
            icon: leadingIcon!,
            size: _iconSize,
            color: _foregroundColor,
          ),
          const SizedBox(width: 8),
        ],
        Text(label, style: _textStyle),
        if (trailingIcon != null) ...[
          const SizedBox(width: 8),
          DivineIcon(
            icon: trailingIcon!,
            size: _iconSize,
            color: _foregroundColor,
          ),
        ],
      ],
    );

    final decoration = BoxDecoration(
      color: _backgroundColor,
      borderRadius: BorderRadius.circular(_borderRadius),
      border: _borderColor != null
          ? Border.all(color: _borderColor!, width: 2)
          : null,
      boxShadow: _isEnabled ? _boxShadow : null,
    );

    final button = AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: _isEnabled ? 1.0 : _disabledOpacity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(_borderRadius),
          splashColor: _foregroundColor.withValues(alpha: 0.1),
          highlightColor: _foregroundColor.withValues(alpha: 0.05),
          child: Ink(
            decoration: decoration,
            child: Padding(
              padding: _padding,
              child: content,
            ),
          ),
        ),
      ),
    );

    if (expanded) {
      return SizedBox(
        width: double.infinity,
        child: button,
      );
    }

    return button;
  }
}

/// An inline text link for use within text flows.
///
/// Unlike [DivineButton] with [DivineButtonType.link], this component has no
/// padding or containers, making it suitable for inline use with other text.
///
/// Example usage:
/// ```dart
/// Text.rich(
///   TextSpan(
///     children: [
///       TextSpan(text: 'Have an account? '),
///       DivineTextLink.span(
///         text: 'Sign in',
///         onTap: () => navigateToLogin(),
///       ),
///     ],
///   ),
/// )
/// ```
///
/// Or as a standalone widget:
/// ```dart
/// Row(
///   children: [
///     Text('Have an account? '),
///     DivineTextLink(
///       text: 'Sign in',
///       onTap: () => navigateToLogin(),
///     ),
///   ],
/// )
/// ```
class DivineTextLink extends StatelessWidget {
  /// Creates an inline text link.
  const DivineTextLink({
    required this.text,
    required this.onTap,
    this.style,
    super.key,
  });

  /// The link text.
  final String text;

  /// Called when the link is tapped. If null, the link appears disabled.
  final VoidCallback? onTap;

  /// Optional custom text style. If not provided, uses the default link style.
  final TextStyle? style;

  /// Returns a [TextSpan] for use in [Text.rich] or [RichText].
  ///
  /// This is useful when you need to embed the link within a larger text flow.
  static TextSpan span({
    required String text,
    required VoidCallback? onTap,
    TextStyle? style,
  }) {
    final isEnabled = onTap != null;
    final baseStyle =
        VineTheme.bodyLargeFont(
          color: isEnabled
              ? VineTheme.onSurfaceVariant
              : VineTheme.onSurfaceDisabled,
        ).copyWith(
          decoration: TextDecoration.underline,
          decorationColor: isEnabled
              ? VineTheme.primary
              : VineTheme.onSurfaceDisabled,
          decorationThickness: 2,
        );

    return TextSpan(
      text: text,
      style: style ?? baseStyle,
      recognizer: onTap != null
          ? (TapGestureRecognizer()..onTap = onTap)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;
    final baseStyle =
        VineTheme.bodyLargeFont(
          color: isEnabled
              ? VineTheme.onSurfaceVariant
              : VineTheme.onSurfaceDisabled,
        ).copyWith(
          decoration: TextDecoration.underline,
          decorationColor: isEnabled
              ? VineTheme.primary
              : VineTheme.onSurfaceDisabled,
          decorationThickness: 2,
        );

    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: style ?? baseStyle,
      ),
    );
  }
}
