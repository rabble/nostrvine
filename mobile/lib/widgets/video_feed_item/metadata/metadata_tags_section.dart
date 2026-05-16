// ABOUTME: Tags row for the metadata expanded sheet.
// ABOUTME: Displays category chips (accent-colored with emoji) and hashtag
// ABOUTME: chips (green "#" prefix) in a wrapping layout. Rendered inline
// ABOUTME: inside the header section right below the description, so the
// ABOUTME: surrounding container owns padding.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_categories_section.dart'
    show CategoryChip;

/// Tags section showing category chips and hashtag chips.
///
/// Category chips have accent-colored backgrounds with emoji. Hashtag chips
/// have a green "#" prefix. Classic Vine videos prepend a "classic" hashtag.
///
/// Rendered inline inside the metadata header section right below the
/// description, between the description and the stats row.
///
/// Returns [SizedBox.shrink] when the video has no tags and no categories.
///
/// Matches Figma node `15728:88010`.
class MetadataTagsSection extends StatelessWidget {
  const MetadataTagsSection({required this.video, super.key});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    final allHashtags = video.allHashtags;
    final hasCategories = video.categories.isNotEmpty;
    final hasHashtags = allHashtags.isNotEmpty;

    if (!hasCategories && !hasHashtags) return const SizedBox.shrink();

    // runSpacing defaults to 0 because each `_HashtagChip` contributes
    // 4 px of transparent tap-target padding above and below its visible
    // bounds, producing an 8 px visible gap between rows without
    // introducing additional spacing here. `_OverviewSection` drops its
    // bottom padding by 4 px to compensate for the last row's invisible
    // bottom padding.
    return Wrap(
      spacing: 8,
      children: [
        for (var i = 0; i < video.categories.length; i++)
          CategoryChip(categoryName: video.categories[i], index: i),
        for (final tag in allHashtags) _HashtagChip(tag: tag),
      ],
    );
  }
}

/// A single tappable hashtag chip with green "#" prefix and bold tag name.
///
/// Tapping dismisses the metadata sheet and pushes the hashtag feed for
/// [tag], matching the behaviour of hashtag chips elsewhere in the app
/// (trending row, search results, linkified text).
class _HashtagChip extends StatelessWidget {
  const _HashtagChip({required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
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

    return Semantics(
      button: true,
      label: context.l10n.metadataHashtagChipTapHint(tag),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _navigateToHashtag(context),
        // 4 px transparent padding above and below the visible 40 px
        // chip extends the tap target to the 48 dp WCAG minimum
        // without altering the rendered layout — the visible chip
        // stays 40 px tall, and the surrounding `MetadataTagsSection`
        // / `_OverviewSection` compensate by dropping `Wrap.runSpacing`
        // to 0 and shrinking the section's bottom padding by 4 px.
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: chip,
        ),
      ),
    );
  }

  void _navigateToHashtag(BuildContext context) {
    // Dismiss the metadata sheet first, then navigate from the root
    // navigator. GoRouter extensions throw when called from inside a modal
    // bottom sheet (the router is not in the modal's widget tree).
    // Mirrors the pattern used by user-chip taps in metadata_user_chips.dart.
    final hostContext = Navigator.of(context, rootNavigator: true).context;
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!hostContext.mounted) return;
      hostContext.pushWithVideoPause(HashtagScreenRouter.pathForTag(tag));
    });
  }
}
