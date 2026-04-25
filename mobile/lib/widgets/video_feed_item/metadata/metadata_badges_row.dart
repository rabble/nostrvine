// ABOUTME: Non-interactive badge labels row for the metadata expanded sheet.
// ABOUTME: Shows Human-Made (with tier) and Not Divine badges separated by
// ABOUTME: muted dot separators. Placed between title and stats.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/utils/proofmode_helpers.dart';

/// Row of non-interactive badge labels below the title/description.
///
/// Confirmed badges: "Human-Made" (with tier superscript) and "Not Divine".
/// Future: "No AI", "Don't try this at home" (content warnings).
///
/// Returns [SizedBox.shrink] when no badges apply.
///
/// Matches Figma node `12345:71381`.
class MetadataBadgesRow extends StatelessWidget {
  const MetadataBadgesRow({required this.video, super.key});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    final badges = <Widget>[];

    if (video.shouldShowProofModeBadge) {
      badges.add(const _HumanMadeBadge());
    }

    if (video.shouldShowNotDivineBadge) {
      badges.add(const _TextBadge(label: 'Not Divine'));
    }

    if (badges.isEmpty) return const SizedBox.shrink();

    // Interleave dot separators between badges.
    final children = <Widget>[];
    for (var i = 0; i < badges.length; i++) {
      children.add(badges[i]);
      if (i < badges.length - 1) {
        children.add(const _DotSeparator());
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      ),
    );
  }
}

/// "Human-Made" badge with "HM" superscript.
class _HumanMadeBadge extends StatelessWidget {
  const _HumanMadeBadge();

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: 'Human-Made', style: VineTheme.titleSmallFont()),
          WidgetSpan(
            alignment: PlaceholderAlignment.top,
            child: Text(
              'HM',
              style: VineTheme.titleSmallFont().copyWith(
                fontSize: VineTheme.titleSmallFont().fontSize! / 1.555,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Plain text badge (e.g., "Not Divine").
class _TextBadge extends StatelessWidget {
  const _TextBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: VineTheme.titleSmallFont());
  }
}

/// Muted dot separator between badges.
class _DotSeparator extends StatelessWidget {
  const _DotSeparator();

  @override
  Widget build(BuildContext context) {
    return Text(
      '\u2219',
      style: VineTheme.titleSmallFont(color: VineTheme.outlineMuted),
    );
  }
}
