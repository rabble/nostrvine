import 'package:divine_ui/src/icon/divine_icon.dart';
import 'package:divine_ui/src/theme/vine_theme.dart';
import 'package:flutter/material.dart';

/// The visual style type of a [DivineIconButton].
enum DivineIconButtonType {
  /// Primary button with green background and dark icon.
  primary,

  /// Secondary button with dark background, green border, and green icon.
  secondary,

  /// Tertiary button with white background and dark green icon.
  tertiary,

  /// Ghost button with semi-transparent dark background (65% black)
  /// and white icon.
  ghost,

  /// Ghost secondary button with lighter scrim (15% black) and white icon.
  ghostSecondary,

  /// Error/destructive button with red background and light icon.
  error,
}

/// The size of a [DivineIconButton].
enum DivineIconButtonSize {
  /// Small button: 8px padding, 16px border radius, 24px icon.
  small,

  /// Base/medium button: 12px padding, 20px border radius, 32px icon.
  base,
}

/// An icon-only button component following the Divine design system.
///
/// The button's appearance is determined by [type] and [size]. The disabled
/// state is automatically applied when [onPressed] is null.
///
/// Example usage:
/// ```dart
/// DivineIconButton(
///   icon: DivineIconName.x,
///   onPressed: () => close(),
/// )
///
/// DivineIconButton(
///   icon: DivineIconName.trash,
///   type: DivineIconButtonType.error,
///   onPressed: canDelete ? () => delete() : null,
/// )
///
/// DivineIconButton(
///   icon: DivineIconName.gear,
///   type: DivineIconButtonType.ghost,
///   size: DivineIconButtonSize.small,
///   onPressed: () => openSettings(),
/// )
/// ```
class DivineIconButton extends StatelessWidget {
  /// Creates a Divine design system icon button.
  const DivineIconButton({
    required this.icon,
    required this.onPressed,
    this.type = DivineIconButtonType.primary,
    this.size = DivineIconButtonSize.base,
    this.semanticLabel,
    super.key,
  });

  /// The icon to display from the Divine design system icon set.
  final DivineIconName icon;

  /// Called when the button is tapped.
  /// If null, the button is displayed in its disabled state.
  final VoidCallback? onPressed;

  /// The visual style type of the button.
  final DivineIconButtonType type;

  /// The size of the button.
  final DivineIconButtonSize size;

  /// Semantic label for accessibility.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return _DivineIconButtonContent(
      icon: icon,
      onPressed: onPressed,
      type: type,
      size: size,
      semanticLabel: semanticLabel,
    );
  }
}

class _DivineIconButtonContent extends StatelessWidget {
  const _DivineIconButtonContent({
    required this.icon,
    required this.onPressed,
    required this.type,
    required this.size,
    this.semanticLabel,
  });

  final DivineIconName icon;
  final VoidCallback? onPressed;
  final DivineIconButtonType type;
  final DivineIconButtonSize size;
  final String? semanticLabel;

  bool get _isEnabled => onPressed != null;

  double get _padding => switch (size) {
    DivineIconButtonSize.small => 8,
    DivineIconButtonSize.base => 12,
  };

  double get _borderRadius => switch (size) {
    DivineIconButtonSize.small => 16,
    DivineIconButtonSize.base => 20,
  };

  double get _iconSize => switch (size) {
    DivineIconButtonSize.small => 24,
    DivineIconButtonSize.base => 32,
  };

  double get _disabledOpacity => switch (type) {
    DivineIconButtonType.error => 0.5,
    _ => 0.32,
  };

  Color get _backgroundColor => switch (type) {
    DivineIconButtonType.primary => VineTheme.primary,
    DivineIconButtonType.secondary => VineTheme.surfaceContainer,
    DivineIconButtonType.tertiary => VineTheme.inverseSurface,
    DivineIconButtonType.ghost => VineTheme.scrim65,
    DivineIconButtonType.ghostSecondary => VineTheme.scrim15,
    DivineIconButtonType.error => VineTheme.error,
  };

  Color get _iconColor => switch (type) {
    DivineIconButtonType.primary => VineTheme.onPrimary,
    DivineIconButtonType.secondary => VineTheme.primary,
    DivineIconButtonType.tertiary => VineTheme.inverseOnSurface,
    DivineIconButtonType.ghost ||
    DivineIconButtonType.ghostSecondary => VineTheme.onSurface,
    DivineIconButtonType.error => VineTheme.onErrorContainer,
  };

  Color? get _borderColor => switch (type) {
    DivineIconButtonType.secondary => VineTheme.outlineMuted,
    _ => null,
  };

  List<BoxShadow>? get _boxShadow {
    // Disabled buttons have no shadow (except for some types)
    if (!_isEnabled && type == DivineIconButtonType.primary) return null;

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
    final iconWidget = DivineIcon(
      icon: icon,
      size: _iconSize,
      color: _iconColor,
    );

    final decoration = BoxDecoration(
      color: _backgroundColor,
      borderRadius: BorderRadius.circular(_borderRadius),
      border: _borderColor != null
          ? Border.all(color: _borderColor!, width: 2)
          : null,
      boxShadow: _isEnabled ? _boxShadow : null,
    );

    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: _isEnabled,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: _isEnabled ? 1.0 : _disabledOpacity,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(_borderRadius),
            splashColor: _iconColor.withValues(alpha: 0.1),
            highlightColor: _iconColor.withValues(alpha: 0.05),
            child: Ink(
              decoration: decoration,
              child: Padding(
                padding: EdgeInsets.all(_padding),
                child: iconWidget,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
