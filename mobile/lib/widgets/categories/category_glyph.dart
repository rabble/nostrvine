// ABOUTME: Renders a category's SVG mascot, degrading to its emoji on a missing asset.
// ABOUTME: Prevents the asset-not-found crash (#4398) when backend category names lack a bundled SVG.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders the SVG at [assetPath], falling back to [emoji] when the asset is
/// not in the bundle.
///
/// Backend category names are an open-ended, uncurated stream (see #2547), so a
/// name can arrive with no matching `assets/categories/<name>.svg`. flutter_svg
/// would otherwise throw "Unable to load asset"; here the missing asset routes
/// to [SvgPicture]'s `errorBuilder` and degrades to the category emoji instead.
class CategoryGlyph extends StatelessWidget {
  const CategoryGlyph({
    required this.assetPath,
    required this.emoji,
    this.height,
    this.width,
    super.key,
  });

  /// The bundled SVG asset path, e.g. `assets/categories/music.svg`.
  final String assetPath;

  /// The fallback glyph shown when [assetPath] is missing from the bundle.
  final String emoji;

  /// Height for both the SVG and the emoji fallback.
  final double? height;

  /// Width for both the SVG and the emoji fallback.
  final double? width;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      assetPath,
      height: height,
      width: width,
      errorBuilder: (context, error, stackTrace) =>
          _EmojiGlyph(emoji: emoji, height: height, width: width),
    );
  }
}

class _EmojiGlyph extends StatelessWidget {
  const _EmojiGlyph({required this.emoji, this.height, this.width});

  final String emoji;
  final double? height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final size = height ?? width ?? 48;
    // Decorative glyph in a fixed-size slot, replacing a scale-invariant SVG;
    // keep it fixed so large system text scales don't overflow the slot.
    return ExcludeSemantics(
      child: MediaQuery.withNoTextScaling(
        child: SizedBox(
          height: height,
          width: width,
          child: Center(
            child: Text(
              emoji,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: size * 0.6),
            ),
          ),
        ),
      ),
    );
  }
}
