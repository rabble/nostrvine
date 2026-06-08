// ABOUTME: Compact emoji reaction chip rendered overlapping the bottom
// ABOUTME: edge of a message bubble. Bordered pill with the emoji
// ABOUTME: centred; circular when single emoji, capsule when a count
// ABOUTME: or retry icon joins.

import 'package:divine_ui/src/theme/vine_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Visual variant of a [ReactionChip]. Drives the background tint, the
/// border colour, the dim-on-pending opacity, and the failed retry
/// overlay.
enum ReactionChipVariant {
  /// Reaction created by the current account; settled.
  own,

  /// Reaction created by another participant; settled.
  theirs,

  /// Current account's reaction; publish in flight.
  pending,

  /// Current account's reaction; publish failed and may be retried.
  failed,
}

/// Compact emoji reaction chip, sized to its content.
///
/// Renders the emoji centred inside a bordered pill. The pill is
/// circular for the single-emoji case and a rounded capsule when a
/// count or retry icon joins. Background matches the conversation
/// surface so the chip reads as "stuck to" the bubble's bottom edge
/// when overlapped via [Transform.translate] in the parent row.
///
/// Stateless and self-contained. Variants are passed in by the caller —
/// the chip does no source-selection logic itself.
class ReactionChip extends StatelessWidget {
  /// Construct a chip.
  const ReactionChip({
    required this.emoji,
    required this.count,
    required this.variant,
    this.semanticLabel,
    this.onTap,
    this.onLongPress,
    super.key,
  });

  /// Emoji codepoint or NIP-30 `:shortcode:` (rendered as plain text).
  final String emoji;

  /// Number of reactors. Hidden when `1`.
  final int count;

  /// Visual variant.
  final ReactionChipVariant variant;

  /// Optional semantic label override. Defaults to a generic emoji+count
  /// description if omitted.
  final String? semanticLabel;

  /// Tap handler. For [ReactionChipVariant.failed] this should retry.
  final VoidCallback? onTap;

  /// Long-press handler. For pending/failed this should remove locally.
  final VoidCallback? onLongPress;

  /// Outer diameter for the single-emoji circular case. Width grows
  /// when a count or retry icon joins, but height stays at this value
  /// so the chip remains visually grounded on the bubble edge.
  static const double _chipDiameter = 28;

  /// Emoji glyph size. Tuned to sit comfortably inside [_chipDiameter]
  /// with the 1 dp border and the small inset.
  static const double _emojiFontSize = 15;

  /// Retry icon size for the failed variant.
  static const double _retryIconSize = 12;

  @override
  Widget build(BuildContext context) {
    final opacity = variant == ReactionChipVariant.pending ? 0.65 : 1.0;

    // Background and border colour are driven by the variant. The
    // background tracks the conversation-surface family so the chip
    // reads as a small "sticker" sitting on top of the bubble rather
    // than as a continuation of the bubble body.
    final background = switch (variant) {
      ReactionChipVariant.own ||
      ReactionChipVariant.pending => VineTheme.primaryDarkGreen,
      ReactionChipVariant.failed => VineTheme.errorContainer,
      ReactionChipVariant.theirs => VineTheme.containerLow,
    };
    final borderColor = switch (variant) {
      ReactionChipVariant.own ||
      ReactionChipVariant.pending => VineTheme.vineGreen,
      ReactionChipVariant.failed => VineTheme.error,
      ReactionChipVariant.theirs => VineTheme.outlineVariant,
    };

    final showCount = count > 1;
    final showRetry = variant == ReactionChipVariant.failed;
    final isCircle = !showCount && !showRetry;

    // Apple's emoji font is ascent-heavy: Flutter's default Text widget
    // reserves the full ascent + descent above and below the glyph, so
    // an emoji centered in the chip visually drops to the bottom.
    // `forceStrutHeight` pins the line box to `fontSize * height`,
    // `textHeightBehavior` strips the extra ascent/descent leading, and
    // `leadingDistribution: even` splits any residual leading equally
    // above and below — the glyph now sits on the chip's centerline.
    //
    // The horizontal nudge re-centres Apple Color Emoji, whose advance
    // box carries a small left-side bearing that otherwise reads as the
    // glyph sitting left of the chip centre. Noto Color Emoji (Android
    // and the other platforms) has symmetric bearings, so advance-box
    // centering already lands it centred there — applying the nudge
    // unconditionally pushed the glyph off-centre to the right on
    // Android (#4954). Gate it to Apple platforms only.
    const appleEmojiLeftBearingNudge = 2.0;
    final isAppleEmojiFont =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    final emojiText = Transform.translate(
      offset: Offset(isAppleEmojiFont ? appleEmojiLeftBearingNudge : 0, 0),
      child: Text(
        emoji,
        style: const TextStyle(
          fontSize: _emojiFontSize,
          height: 1,
          leadingDistribution: TextLeadingDistribution.even,
        ),
        strutStyle: const StrutStyle(
          fontSize: _emojiFontSize,
          height: 1,
          forceStrutHeight: true,
          leadingDistribution: TextLeadingDistribution.even,
        ),
        textHeightBehavior: const TextHeightBehavior(
          applyHeightToFirstAscent: false,
          applyHeightToLastDescent: false,
        ),
        textAlign: TextAlign.center,
      ),
    );

    final rowChildren = <Widget>[
      emojiText,
      if (showCount) ...[
        const SizedBox(width: 3),
        Text(
          '$count',
          style: VineTheme.labelSmallFont(
            color: VineTheme.onSurface,
          ).copyWith(fontSize: 11, height: 1),
        ),
      ],
      if (showRetry) ...[
        const SizedBox(width: 3),
        const Icon(
          Icons.refresh,
          size: _retryIconSize,
          color: VineTheme.error,
        ),
      ],
    ];

    // Circular chip uses zero horizontal padding so the diameter is the
    // only constraint, keeping the glyph dead-centre. Capsule chip uses
    // a small symmetric inset so the count / retry icon has breathing
    // room without stretching the height.
    final horizontalPadding = isCircle ? 0.0 : 7.0;
    final borderRadius = isCircle
        ? BorderRadius.circular(_chipDiameter / 2)
        : BorderRadius.circular(_chipDiameter / 2);

    final pill = Container(
      height: _chipDiameter,
      constraints: const BoxConstraints(
        minWidth: _chipDiameter,
        minHeight: _chipDiameter,
      ),
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      decoration: BoxDecoration(
        color: background,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: rowChildren,
      ),
    );

    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      child: Opacity(
        opacity: opacity,
        child: Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: pill,
          ),
        ),
      ),
    );
  }
}
