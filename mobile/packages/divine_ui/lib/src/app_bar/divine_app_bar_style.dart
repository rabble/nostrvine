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
    this.iconButtonBackgroundColor,
    this.iconButtonBorderSide,
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

  /// Background color for icon buttons.
  ///
  /// When null, uses [VineTheme.iconButtonBackground].
  final Color? iconButtonBackgroundColor;

  /// Optional border for icon button containers.
  ///
  /// When null, no border is shown
  final BorderSide? iconButtonBorderSide;

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

  /// Style for solid background mode.
  static const DiVineAppBarStyle solidStyle = DiVineAppBarStyle(
    iconButtonBackgroundColor: VineTheme.surfaceContainer,
    iconButtonBorderSide: BorderSide(
      color: VineTheme.outlineMuted,
      width: 2,
    ),
    iconColor: VineTheme.primary,
  );

  /// Style for transparent and gradient background modes.
  static const DiVineAppBarStyle transparentStyle = DiVineAppBarStyle(
    iconButtonBackgroundColor: Color(0x26000000),
    iconColor: VineTheme.whiteText,
  );

  /// Creates a copy of this style with the given fields replaced.
  DiVineAppBarStyle copyWith({
    double? height,
    double? leadingWidth,
    Color? iconButtonBackgroundColor,
    BorderSide? iconButtonBorderSide,
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
      iconButtonBackgroundColor:
          iconButtonBackgroundColor ?? this.iconButtonBackgroundColor,
      iconButtonBorderSide: iconButtonBorderSide ?? this.iconButtonBorderSide,
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
      iconButtonBackgroundColor:
          other.iconButtonBackgroundColor ?? iconButtonBackgroundColor,
      iconButtonBorderSide: other.iconButtonBorderSide ?? iconButtonBorderSide,
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
    iconButtonBackgroundColor,
    iconButtonBorderSide,
    iconColor,
    titleStyle,
    subtitleStyle,
    actionButtonSpacing,
    horizontalPadding,
    dropdownCaretSize,
  ];
}
