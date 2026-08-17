// ABOUTME: Paints the green-heart codepoint in Divine's brand green instead
// ABOUTME: of the platform emoji font's own green, for user-authored text.

import 'package:divine_ui/src/icon/divine_icon.dart';
import 'package:divine_ui/src/theme/vine_theme.dart';
import 'package:flutter/widgets.dart';

/// The green heart Divine paints in [VineTheme.vineGreen].
///
/// Divine keeps publishing this standard codepoint, so other clients still
/// render a green heart of their own; only the local painting changes.
const String divineGreenHeart = '\u{1F49A}';

/// Heart size as a multiple of the surrounding run's font size.
///
/// Emoji glyphs sit slightly larger than their nominal point size, so a 1:1
/// heart reads as undersized beside the text it replaces.
const double kDivineHeartFontScale = 1.2;

/// Size assumed for a run whose style carries no explicit font size.
const double kDivineHeartFallbackFontSize = 14;

/// Splits [text] on [divineGreenHeart], painting each occurrence as a
/// brand-green heart and leaving every other character to the platform.
///
/// Returns a single [TextSpan] when [text] holds no green heart, so callers
/// pay nothing on the common path.
List<InlineSpan> divineHeartSpans(String text, {required TextStyle style}) {
  if (!text.contains(divineGreenHeart)) {
    return [TextSpan(text: text, style: style)];
  }

  final size =
      (style.fontSize ?? kDivineHeartFallbackFontSize) * kDivineHeartFontScale;
  final spans = <InlineSpan>[];

  for (final (index, segment) in text.split(divineGreenHeart).indexed) {
    if (index > 0) spans.add(_heartSpan(size));
    if (segment.isNotEmpty) spans.add(TextSpan(text: segment, style: style));
  }

  return spans;
}

InlineSpan _heartSpan(double size) => WidgetSpan(
  alignment: PlaceholderAlignment.middle,
  child: Semantics(
    label: divineGreenHeart,
    child: DivineIcon(
      icon: DivineIconName.heartFill,
      size: size,
      color: VineTheme.vineGreen,
    ),
  ),
);
