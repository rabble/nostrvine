// ABOUTME: Tags section for the metadata expanded sheet.
// ABOUTME: Displays hashtag chips (green "#" prefix) in a wrapping layout
// ABOUTME: without a section label, matching Figma node 12345:71463.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart';

/// Tags section showing hashtag chips.
///
/// Hashtag chips have a green "#" prefix. Classic Vine videos prepend a
/// "classic" hashtag chip.
///
/// Unlike other metadata sections, this section has **no label** and **no
/// bottom border** per Figma spec — chips sit directly between the stats row
/// and the Creator section.
///
/// Returns [SizedBox.shrink] when the video has no tags.
///
/// Matches Figma node `12345:71463`.
class MetadataTagsSection extends StatelessWidget {
  const MetadataTagsSection({required this.video, super.key});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    // "Classic" is treated as a tag per design spec.
    final allHashtags = [
      if (video.isOriginalVine) 'classic',
      ...video.hashtags,
    ];

    if (allHashtags.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final tag in allHashtags) _HashtagChip(tag: tag),
        ],
      ),
    );
  }
}

/// A single hashtag chip with green "#" prefix and bold tag name.
class _HashtagChip extends StatelessWidget {
  const _HashtagChip({required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: VineTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          Text(
            '#',
            style: VineTheme.bodyLargeFont(color: VineTheme.vineGreen),
          ),
          Flexible(
            child: Text(
              tag,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: VineTheme.titleSmallFont(),
            ),
          ),
        ],
      ),
    );
  }
}
