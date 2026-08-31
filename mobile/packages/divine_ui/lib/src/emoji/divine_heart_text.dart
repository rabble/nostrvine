// ABOUTME: Drop-in Text replacement that paints U+1F49A in the Divine brand
// ABOUTME: green, for surfaces that do not route through the linkifier.

import 'package:divine_ui/src/emoji/divine_heart_spans.dart';
import 'package:flutter/widgets.dart';

/// Renders [text], painting any [divineGreenHeart] in the Divine brand green.
///
/// Behaves like [Text] for every other character. Use this on surfaces that
/// carry user-authored content but do not go through the linkifier — display
/// names, reaction glyphs, titles, list previews.
class DivineHeartText extends StatelessWidget {
  /// Creates a heart-aware [Text].
  const DivineHeartText(
    this.text, {
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    super.key,
  });

  /// The text to render.
  final String text;

  /// Style for the text, merged over the inherited [DefaultTextStyle].
  ///
  /// The merged font size also drives the heart's size, so the glyph tracks
  /// whatever the surrounding run resolves to.
  final TextStyle? style;

  /// Maximum lines before [overflow] applies.
  final int? maxLines;

  /// How visual overflow is handled.
  final TextOverflow? overflow;

  /// Horizontal alignment of the text.
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);

    return Text.rich(
      TextSpan(children: divineHeartSpans(text, style: effectiveStyle)),
      // Carried on the Text as well as the spans so this stays a drop-in
      // replacement: callers and tests still read [Text.style].
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}
