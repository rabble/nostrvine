// ABOUTME: Shared base widget for video overlay action buttons.
// ABOUTME: 48x48 tap target containing a 24 icon over a label/count.

import 'dart:ui';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/utils/string_utils.dart';

/// Base widget for video overlay action buttons (like, comment, repost, share).
///
/// Matches Figma node `15314:53971`: a 48x48 fully tappable container with a
/// 24 icon centered over an 8 px gap and a label/small caption beneath it.
/// The entire 48x48 region captures the tap — not just the icon.
///
/// Example usage:
/// ```dart
/// VideoActionButton(
///   icon: DivineIconName.heart,
///   semanticIdentifier: 'like_button',
///   semanticLabel: 'Like video',
///   onPressed: () => handleLike(),
///   iconColor: isLiked ? Colors.red : VineTheme.whiteText,
///   count: totalLikes,
///   labelWhenZero: 'Like',
/// )
/// ```
class VideoActionButton extends StatelessWidget {
  const VideoActionButton({
    required this.icon,
    required this.semanticIdentifier,
    required this.semanticLabel,
    this.onPressed,
    this.iconColor = VineTheme.whiteText,
    this.count = 0,
    this.isLoading = false,
    this.caption,
    this.labelWhenZero,
    super.key,
  });

  /// The icon to display from the Divine design system.
  final DivineIconName icon;

  /// Semantics identifier for testing (e.g. 'like_button').
  final String semanticIdentifier;

  /// Accessibility label (e.g. 'Like video').
  final String semanticLabel;

  /// Called when the button is tapped. Null disables the button.
  final VoidCallback? onPressed;

  /// Color applied to the SVG icon. Defaults to white.
  final Color iconColor;

  /// Count to display beneath the icon. Shows empty space when 0 unless
  /// [labelWhenZero] is provided.
  final int count;

  /// When true, shows a loading spinner instead of the icon.
  final bool isLoading;

  /// Optional fixed caption shown beneath the icon instead of a count or
  /// zero-label. When set, always wins over [count] and [labelWhenZero].
  final String? caption;

  /// Short placeholder label shown beneath the icon when [count] is 0 and
  /// no [caption] is set (e.g. "Like", "Reply"). When null, the caption
  /// slot stays empty at zero count.
  final String? labelWhenZero;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: semanticIdentifier,
      container: true,
      explicitChildNodes: true,
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isLoading ? null : onPressed,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: VineTheme.whiteText,
                    ),
                  )
                else
                  _ShadowedIcon(icon: icon, color: iconColor),
                if (!isLoading)
                  _VideoActionCaption(
                    caption: caption,
                    count: count,
                    labelWhenZero: labelWhenZero,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Caption slot beneath a [VideoActionButton] icon.
///
/// Resolves the displayed text in priority order:
/// 1. [caption] — fixed override from the caller.
/// 2. The formatted [count] — once there's at least one interaction.
/// 3. [labelWhenZero] — placeholder word like "Like" / "Reply" when no
///    interactions have landed yet.
///
/// Returns [SizedBox.shrink] when none of the three apply, so the Column
/// above collapses the slot without the 8 px leading gap.
class _VideoActionCaption extends StatelessWidget {
  const _VideoActionCaption({
    required this.caption,
    required this.count,
    required this.labelWhenZero,
  });

  final String? caption;
  final int count;
  final String? labelWhenZero;

  @override
  Widget build(BuildContext context) {
    final text = switch ((caption, count, labelWhenZero)) {
      (final String c, _, _) => c,
      (_, final int n, _) when n > 0 => StringUtils.formatCompactNumber(n),
      (_, _, final String zero) => zero,
      _ => null,
    };

    if (text == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: VineTheme.labelSmallFont().copyWith(
          shadows: VineTheme.buttonShadows,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// 24x24 icon with two layered glyph drop shadows matching the Figma
/// button spec. The shadow layers are [DivineIcon]s tinted in
/// [VineTheme.innerShadow] and wrapped in [ExcludeSemantics] so they
/// don't pollute the accessibility tree with duplicate icon nodes —
/// only the foreground glyph is read by screen readers.
class _ShadowedIcon extends StatelessWidget {
  const _ShadowedIcon({required this.icon, required this.color});

  final DivineIconName icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        _IconShadow(icon: icon, offset: const Offset(1, 1), blurSigma: 1),
        _IconShadow(icon: icon, offset: const Offset(0.4, 0.4), blurSigma: 0.6),
        DivineIcon(icon: icon, color: color),
      ],
    );
  }
}

/// One of the two stacked drop shadows behind [_ShadowedIcon]'s glyph.
/// Renders a [DivineIcon] tinted in [VineTheme.innerShadow], offset, and
/// blurred via [ImageFiltered] so the shadow follows the glyph silhouette
/// rather than the bounding rect.
class _IconShadow extends StatelessWidget {
  const _IconShadow({
    required this.icon,
    required this.offset,
    required this.blurSigma,
  });

  final DivineIconName icon;
  final Offset offset;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: offset,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        // Defensive ExcludeSemantics — DivineIcon is currently just a
        // thin SvgPicture wrapper with no Semantics of its own, but if
        // it ever gains one, the two shadow copies should stay out of
        // the accessibility tree.
        child: ExcludeSemantics(
          child: DivineIcon(icon: icon, color: VineTheme.innerShadow),
        ),
      ),
    );
  }
}
