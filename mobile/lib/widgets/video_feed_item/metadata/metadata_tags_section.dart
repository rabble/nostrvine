// ABOUTME: Tags section for the metadata expanded sheet.
// ABOUTME: Displays category chips (accent-colored with emoji) and hashtag
// ABOUTME: chips (green "#" prefix) in a wrapping layout without a section
// ABOUTME: label, matching Figma node 12345:71463.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_categories_section.dart'
    show CategoryChip;

/// Tags section showing category chips and hashtag chips.
///
/// Category chips have accent-colored backgrounds with emoji. Hashtag chips
/// have a green "#" prefix. Classic Vine videos prepend a "classic" hashtag.
///
/// Unlike other metadata sections, this section has **no label** and **no
/// bottom border** per Figma spec — chips sit directly between the stats row
/// and the Creator section.
///
/// Returns [SizedBox.shrink] when the video has no tags and no categories.
///
/// Matches Figma node `12345:71463`.
class MetadataTagsSection extends StatelessWidget {
  const MetadataTagsSection({required this.video, super.key});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    final allHashtags = video.allHashtags;
    final hasCategories = video.categories.isNotEmpty;
    final hasHashtags = allHashtags.isNotEmpty;

    if (!hasCategories && !hasHashtags) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          // Category chips first (accent-colored with emoji)
          for (var i = 0; i < video.categories.length; i++)
            CategoryChip(categoryName: video.categories[i], index: i),
          // Then hashtag chips
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
          Text('#', style: VineTheme.bodyLargeFont(color: VineTheme.vineGreen)),
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
