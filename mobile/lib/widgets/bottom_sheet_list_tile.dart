// ABOUTME: Reusable styled list tile component for bottom sheets
// ABOUTME: Displays SVG icon, title text, and handles tap actions with navigation

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';

/// A styled list tile designed for use in bottom sheets.
///
/// Displays an SVG icon and title text with consistent styling.
/// Automatically pops the navigation when tapped before calling [onTap].
class BottomSheetListTile extends StatelessWidget {
  /// Creates a bottom sheet list tile.
  ///
  /// The [iconPath] must point to a valid SVG asset file.
  /// The [title] is displayed in BricolageGrotesque font.
  const BottomSheetListTile({
    super.key,
    required this.iconPath,
    required this.title,
    this.onTap,
    this.color = Colors.white,
  });

  /// The path to the SVG icon asset to display.
  final String iconPath;

  /// The title text to display.
  final String title;

  /// Optional callback invoked when the tile is tapped.
  final VoidCallback? onTap;

  /// The color applied to both the icon and title text.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = onTap != null ? color : Colors.white.withAlpha(64);

    return ListTile(
      iconColor: effectiveColor,
      textColor: effectiveColor,
      enabled: onTap != null,
      minTileHeight: 64,
      leading: SizedBox(
        height: 32,
        width: 32,
        child: SvgPicture.asset(
          iconPath,
          colorFilter: ColorFilter.mode(effectiveColor, BlendMode.srcIn),
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: 'BricolageGrotesque',
          fontSize: 24,
          fontWeight: .w700,
          height: 1.33,
          letterSpacing: 0,
        ),
        maxLines: 1,
        overflow: .ellipsis,
      ),
      onTap: onTap != null
          ? () {
              context.pop();
              onTap!.call();
            }
          : null,
    );
  }
}
