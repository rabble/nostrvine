import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// Background rendering mode for [DiVineAppBar].
enum DiVineAppBarBackgroundMode {
  /// Solid navGreen background (default).
  solid,

  /// Transparent background for overlay mode.
  transparent,

  /// Gradient background using [DiVineAppBarGradient].
  gradient,
}

/// Title interaction mode for [DiVineAppBar].
enum DiVineAppBarTitleMode {
  /// Static title with no interaction.
  simple,

  /// Tappable title that triggers [DiVineAppBar.onTitleTap].
  tappable,

  /// Dropdown title that shows caret and triggers [DiVineAppBar.onTitleTap].
  dropdown,
}

/// A reusable app bar component for Divine screens.
///
/// Provides consistent styling and behavior across the app with support for:
/// - Multiple background modes (solid, transparent, gradient)
/// - Multiple title modes (simple, tappable, dropdown)
/// - Optional leading icons (back, menu, or custom)
/// - Optional subtitle
/// - Optional title suffix (e.g., EnvironmentBadge)
/// - Configurable action buttons
///
/// Example usage:
/// ```dart
/// Scaffold(
///   appBar: DiVineAppBar(
///     title: 'Settings',
///     showBackButton: true,
///     onBackPressed: () => context.pop(),
///   ),
///   body: ...,
/// )
/// ```
class DiVineAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Creates a DiVineAppBar.
  const DiVineAppBar({
    this.title,
    this.titleWidget,
    this.subtitle,
    this.titleMode = DiVineAppBarTitleMode.simple,
    this.onTitleTap,
    this.titleSuffix,
    this.showBackButton = false,
    this.onBackPressed,
    this.showMenuButton = false,
    this.onMenuPressed,
    this.leadingIcon,
    this.onLeadingPressed,
    this.actions = const [],
    this.backgroundMode = DiVineAppBarBackgroundMode.solid,
    this.gradient,
    this.backgroundColor,
    this.style,
    super.key,
  }) : assert(
         title != null || titleWidget != null,
         'Either title or titleWidget must be provided',
       ),
       assert(
         !(showBackButton && showMenuButton),
         'Cannot show both back button and menu button',
       ),
       assert(
         !(showBackButton && leadingIcon != null),
         'Cannot show back button with custom leading icon',
       ),
       assert(
         !(showMenuButton && leadingIcon != null),
         'Cannot show menu button with custom leading icon',
       ),
       assert(
         titleMode != DiVineAppBarTitleMode.tappable || onTitleTap != null,
         'onTitleTap required when titleMode is tappable',
       ),
       assert(
         titleMode != DiVineAppBarTitleMode.dropdown || onTitleTap != null,
         'onTitleTap required when titleMode is dropdown',
       ),
       assert(
         backgroundMode != DiVineAppBarBackgroundMode.gradient ||
             gradient != null,
         'gradient required when backgroundMode is gradient',
       ),
       assert(
         leadingIcon == null || onLeadingPressed != null,
         'onLeadingPressed required when leadingIcon is provided',
       );

  /// The title text to display.
  ///
  /// Either [title] or [titleWidget] must be provided.
  final String? title;

  /// A custom widget to display as the title.
  ///
  /// Takes precedence over [title] if both are provided.
  final Widget? titleWidget;

  /// Optional subtitle text displayed below the title.
  final String? subtitle;

  /// The title interaction mode.
  ///
  /// Defaults to [DiVineAppBarTitleMode.simple].
  final DiVineAppBarTitleMode titleMode;

  /// Called when the title is tapped.
  ///
  /// Required when [titleMode] is [DiVineAppBarTitleMode.tappable] or
  /// [DiVineAppBarTitleMode.dropdown].
  final VoidCallback? onTitleTap;

  /// Optional widget displayed after the title.
  final Widget? titleSuffix;

  /// Whether to show a back button as the leading widget.
  ///
  /// Cannot be true if [showMenuButton] or [leadingIcon] is set.
  final bool showBackButton;

  /// Called when the back button is tapped.
  ///
  /// If null and [showBackButton] is true, defaults to Navigator.pop.
  final VoidCallback? onBackPressed;

  /// Whether to show a menu button as the leading widget.
  ///
  /// Cannot be true if [showBackButton] or [leadingIcon] is set.
  final bool showMenuButton;

  /// Called when the menu button is tapped.
  final VoidCallback? onMenuPressed;

  /// Custom leading icon.
  ///
  /// Cannot be set if [showBackButton] or [showMenuButton] is true.
  final IconSource? leadingIcon;

  /// Called when the custom leading icon is tapped.
  ///
  /// Required when [leadingIcon] is provided.
  final VoidCallback? onLeadingPressed;

  /// Action buttons displayed on the right side.
  ///
  /// Defaults to an empty list.
  final List<DiVineAppBarAction> actions;

  /// The background rendering mode.
  ///
  /// Defaults to [DiVineAppBarBackgroundMode.solid].
  final DiVineAppBarBackgroundMode backgroundMode;

  /// Gradient configuration when [backgroundMode] is
  /// [DiVineAppBarBackgroundMode.gradient].
  final DiVineAppBarGradient? gradient;

  /// Custom background color for solid mode.
  ///
  /// When null, uses [VineTheme.navGreen].
  final Color? backgroundColor;

  /// Style configuration for child widgets.
  final DiVineAppBarStyle? style;

  @override
  Size get preferredSize => Size.fromHeight(
    style?.height ?? DiVineAppBarStyle.defaultStyle.height,
  );

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ?? DiVineAppBarStyle.defaultStyle;

    final appBarContent = AppBar(
      backgroundColor: _getBackgroundColor(),
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: effectiveStyle.height,
      leadingWidth: effectiveStyle.leadingWidth,
      titleSpacing: 0,
      centerTitle: false,
      automaticallyImplyLeading: false,
      leading: DiVineAppBarLeading(
        showBackButton: showBackButton,
        onBackPressed: onBackPressed,
        showMenuButton: showMenuButton,
        onMenuPressed: onMenuPressed,
        leadingIcon: leadingIcon,
        onLeadingPressed: onLeadingPressed,
        style: effectiveStyle,
      ),
      title: DiVineAppBarTitle(
        title: title,
        titleWidget: titleWidget,
        subtitle: subtitle,
        titleMode: titleMode,
        onTitleTap: onTitleTap,
        titleSuffix: titleSuffix,
        style: effectiveStyle,
      ),
      actions: actions.isEmpty
          ? null
          : [
              DiVineAppBarActions(
                actions: actions,
                style: effectiveStyle,
              ),
            ],
    );

    if (backgroundMode == DiVineAppBarBackgroundMode.gradient) {
      return Container(
        decoration: BoxDecoration(
          gradient: gradient!.toLinearGradient(),
        ),
        child: appBarContent,
      );
    }

    return appBarContent;
  }

  Color? _getBackgroundColor() {
    return switch (backgroundMode) {
      DiVineAppBarBackgroundMode.solid => backgroundColor ?? VineTheme.navGreen,
      DiVineAppBarBackgroundMode.transparent => Colors.transparent,
      DiVineAppBarBackgroundMode.gradient => Colors.transparent,
    };
  }
}
