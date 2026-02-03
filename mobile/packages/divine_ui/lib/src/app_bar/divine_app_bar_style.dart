import 'package:divine_ui/divine_ui.dart' show DiVineAppBar, VineTheme;
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Style configuration for [DiVineAppBar] components.
///
/// Allows parent widgets to customize child widget styling while
/// maintaining consistency across the app bar.
///
/// Example usage:
/// ```dart
/// DiVineAppBar(
///   title: 'Settings',
///   style: DiVineAppBarStyle(
///     iconButtonBackgroundColor: Colors.transparent,
///   ),
/// )
/// ```
@immutable
class DiVineAppBarStyle extends Equatable {
  /// Creates a DiVineAppBar style configuration.
  const DiVineAppBarStyle({
    this.height = 72,
    this.leadingWidth = 80,
    this.iconButtonSize = 48,
    this.iconSize = 32,
    this.iconButtonBorderRadius = 20,
    this.iconButtonBackgroundColor,
    this.iconColor,
    this.titleStyle,
    this.subtitleStyle,
    this.actionButtonSpacing = 8,
    this.horizontalPadding = 16,
    this.dropdownCaretSize = 16,
  });

  /// Height of the app bar.
  ///
  /// Defaults to 72.
  final double height;

  /// Width reserved for the leading section.
  ///
  /// Defaults to 80.
  final double leadingWidth;

  /// Size of icon button containers.
  ///
  /// Defaults to 48.
  final double iconButtonSize;

  /// Size of icons within buttons.
  ///
  /// Defaults to 32.
  final double iconSize;

  /// Border radius of icon button containers.
  ///
  /// Defaults to 20 for pill-shaped appearance.
  final double iconButtonBorderRadius;

  /// Background color for icon buttons.
  ///
  /// When null, uses [VineTheme.iconButtonBackground].
  final Color? iconButtonBackgroundColor;

  /// Color for icons.
  ///
  /// When null, uses [VineTheme.whiteText].
  final Color? iconColor;

  /// Text style for the title.
  ///
  /// When null, uses [VineTheme.titleLargeFont].
  final TextStyle? titleStyle;

  /// Text style for the subtitle.
  ///
  /// When null, uses [VineTheme.bodySmallFont] with reduced opacity.
  final TextStyle? subtitleStyle;

  /// Spacing between action buttons.
  ///
  /// Defaults to 8.
  final double actionButtonSpacing;

  /// Horizontal padding for leading and trailing sections.
  ///
  /// Applied as left padding for leading icons and right padding for actions.
  /// Defaults to 16.
  final double horizontalPadding;

  /// Size of the dropdown caret icon in title dropdown mode.
  ///
  /// Defaults to 16.
  final double dropdownCaretSize;

  /// Default style matching AppShell implementation.
  static const DiVineAppBarStyle defaultStyle = DiVineAppBarStyle();

  /// Creates a copy of this style with the given fields replaced.
  DiVineAppBarStyle copyWith({
    double? height,
    double? leadingWidth,
    double? iconButtonSize,
    double? iconSize,
    double? iconButtonBorderRadius,
    Color? iconButtonBackgroundColor,
    Color? iconColor,
    TextStyle? titleStyle,
    TextStyle? subtitleStyle,
    double? actionButtonSpacing,
    double? horizontalPadding,
    double? dropdownCaretSize,
  }) {
    return DiVineAppBarStyle(
      height: height ?? this.height,
      leadingWidth: leadingWidth ?? this.leadingWidth,
      iconButtonSize: iconButtonSize ?? this.iconButtonSize,
      iconSize: iconSize ?? this.iconSize,
      iconButtonBorderRadius:
          iconButtonBorderRadius ?? this.iconButtonBorderRadius,
      iconButtonBackgroundColor:
          iconButtonBackgroundColor ?? this.iconButtonBackgroundColor,
      iconColor: iconColor ?? this.iconColor,
      titleStyle: titleStyle ?? this.titleStyle,
      subtitleStyle: subtitleStyle ?? this.subtitleStyle,
      actionButtonSpacing: actionButtonSpacing ?? this.actionButtonSpacing,
      horizontalPadding: horizontalPadding ?? this.horizontalPadding,
      dropdownCaretSize: dropdownCaretSize ?? this.dropdownCaretSize,
    );
  }

  /// Merges this style with another, with the other style taking precedence.
  DiVineAppBarStyle merge(DiVineAppBarStyle? other) {
    if (other == null) return this;
    return DiVineAppBarStyle(
      height: other.height,
      leadingWidth: other.leadingWidth,
      iconButtonSize: other.iconButtonSize,
      iconSize: other.iconSize,
      iconButtonBorderRadius: other.iconButtonBorderRadius,
      iconButtonBackgroundColor:
          other.iconButtonBackgroundColor ?? iconButtonBackgroundColor,
      iconColor: other.iconColor ?? iconColor,
      titleStyle: other.titleStyle ?? titleStyle,
      subtitleStyle: other.subtitleStyle ?? subtitleStyle,
      actionButtonSpacing: other.actionButtonSpacing,
      horizontalPadding: other.horizontalPadding,
      dropdownCaretSize: other.dropdownCaretSize,
    );
  }

  @override
  List<Object?> get props => [
    height,
    leadingWidth,
    iconButtonSize,
    iconSize,
    iconButtonBorderRadius,
    iconButtonBackgroundColor,
    iconColor,
    titleStyle,
    subtitleStyle,
    actionButtonSpacing,
    horizontalPadding,
    dropdownCaretSize,
  ];
}
