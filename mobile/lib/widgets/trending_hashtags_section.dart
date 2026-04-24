// ABOUTME: Displays horizontal scrollable list of trending hashtags
// ABOUTME: Extracted from ExploreScreen for reusability and testability

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/utils/hashtag_chip_accent.dart';

/// A section displaying trending hashtags in a horizontal scrollable list.
///
/// Shows a title "Trending Hashtags" followed by tappable hashtag chips.
/// Tapping a hashtag navigates to the hashtag feed.
class TrendingHashtagsSection extends StatelessWidget {
  const TrendingHashtagsSection({
    required this.hashtags,
    super.key,
    this.isLoading = false,
    this.onHashtagTap,
  });

  /// List of hashtag strings (without the # prefix)
  final List<String> hashtags;

  /// Whether hashtags are still loading
  final bool isLoading;

  /// Optional callback when a hashtag is tapped.
  /// If not provided, defaults to navigating via goHashtag.
  final void Function(String hashtag)? onHashtagTap;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: VineTheme.backgroundColor,
      child: SizedBox(
        height: 52,
        child: hashtags.isEmpty
            ? const _HashtagLoadingPlaceholder()
            : _HashtagChipList(hashtags: hashtags, onHashtagTap: onHashtagTap),
      ),
    );
  }
}

/// Loading placeholder shown when hashtags are not yet available.
class _HashtagLoadingPlaceholder extends StatelessWidget {
  const _HashtagLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        'Loading hashtags...',
        style: TextStyle(color: VineTheme.secondaryText, fontSize: 14),
      ),
    );
  }
}

/// Horizontal scrollable list of tappable hashtag chips.
class _HashtagChipList extends StatelessWidget {
  const _HashtagChipList({required this.hashtags, this.onHashtagTap});

  final List<String> hashtags;
  final void Function(String hashtag)? onHashtagTap;

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: 1.5);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: 12,
        ),
        itemCount: hashtags.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsetsDirectional.only(end: 10),
              child: Center(
                child: Text(
                  context.l10n.trendingTitle,
                  style: VineTheme.titleSmallFont(),
                ),
              ),
            );
          }
          final hashtag = hashtags[index - 1];
          return _HashtagChip(
            hashtag: hashtag,
            onTap: () {
              if (onHashtagTap != null) {
                onHashtagTap!(hashtag);
              } else {
                context.push(HashtagScreenRouter.pathForTag(hashtag));
              }
            },
          );
        },
      ),
    );
  }
}

/// Individual hashtag chip with tap behavior.
class _HashtagChip extends StatelessWidget {
  const _HashtagChip({
    required this.hashtag,
    required this.onTap,
  });

  final String hashtag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = hashtagTileBackgroundForLabel(hashtag);

    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Semantics(
        label: 'View videos tagged $hashtag',
        button: true,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                '#$hashtag',
                style: VineTheme.titleSmallFont(
                  color: VineTheme.primaryDarkGreen,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
