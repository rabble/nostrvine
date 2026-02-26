// ABOUTME: Shared base widget for video overlay action buttons.
// ABOUTME: Renders an SVG icon in a styled container with optional count.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:openvine/utils/string_utils.dart';

/// Base widget for video overlay action buttons (like, comment, repost, share).
///
/// Provides consistent styling: a 48x48 icon button with a drop shadow,
/// an SVG icon, and an optional compact count label beneath it.
///
/// Example usage:
/// ```dart
/// VideoActionButton(
///   iconAsset: 'assets/icon/content-controls/like.svg',
///   semanticIdentifier: 'like_button',
///   semanticLabel: 'Like video',
///   onPressed: () => handleLike(),
///   iconColor: isLiked ? Colors.red : VineTheme.whiteText,
///   count: totalLikes,
/// )
/// ```
class VideoActionButton extends StatelessWidget {
  const VideoActionButton({
    required this.iconAsset,
    required this.semanticIdentifier,
    required this.semanticLabel,
    this.onPressed,
    this.iconColor = VineTheme.whiteText,
    this.count = 0,
    this.isLoading = false,
    super.key,
  });

  /// Path to the SVG icon asset.
  final String iconAsset;

  /// Semantics identifier for testing (e.g. 'like_button').
  final String semanticIdentifier;

  /// Accessibility label (e.g. 'Like video').
  final String semanticLabel;

  /// Called when the button is tapped. Null disables the button.
  final VoidCallback? onPressed;

  /// Color applied to the SVG icon. Defaults to white.
  final Color iconColor;

  /// Count to display beneath the icon. Hidden when 0.
  final int count;

  /// When true, shows a loading spinner instead of the icon.
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          identifier: semanticIdentifier,
          container: true,
          explicitChildNodes: true,
          button: true,
          label: semanticLabel,
          child: IconButton(
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            style: IconButton.styleFrom(
              highlightColor: Colors.transparent,
              splashFactory: NoSplash.splashFactory,
            ),
            onPressed: isLoading ? null : onPressed,
            icon: isLoading
                ? const SizedBox.square(
                    dimension: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: VineTheme.whiteText,
                    ),
                  )
                : DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 15,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: SvgPicture.asset(
                      iconAsset,
                      width: 32,
                      height: 32,
                      colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                    ),
                  ),
          ),
        ),
        if (count > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              width: 48,
              child: Text(
                StringUtils.formatCompactNumber(count),
                style: VineTheme.labelSmallFont(color: VineTheme.onSurface),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
