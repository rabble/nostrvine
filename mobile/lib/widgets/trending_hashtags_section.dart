// ABOUTME: Displays horizontal scrollable list of trending hashtags
// ABOUTME: Extracted from ExploreScreen for reusability and testability

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:divine_ui/divine_ui.dart';

/// A section displaying trending hashtags in a horizontal scrollable list.
///
/// Shows a title "Trending Hashtags" followed by tappable hashtag chips.
/// Tapping a hashtag navigates to the hashtag feed.
class TrendingHashtagsSection extends StatelessWidget {
  const TrendingHashtagsSection({
    super.key,
    required this.hashtags,
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
    return Container(
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 12),
      itemCount: hashtags.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Center(
              child: Text(
                'Trending',
                style: VineTheme.titleSmallFont(color: VineTheme.primaryText),
              ),
            ),
          );
        }
        final hashtag = hashtags[index - 1];
        return _HashtagChip(
          hashtag: hashtag,
          colorIndex: index - 1,
          onTap: () {
            if (onHashtagTap != null) {
              onHashtagTap!(hashtag);
            } else {
              context.go(HashtagScreenRouter.pathForTag(hashtag));
            }
          },
        );
      },
    );
  }
}

/// Accent colors used for hashtag chip backgrounds.
const _accentColors = [
  VineTheme.accentYellow,
  VineTheme.accentLime,
  VineTheme.accentPink,
  VineTheme.accentOrange,
  VineTheme.accentViolet,
  VineTheme.accentPurple,
  VineTheme.accentBlue,
];

/// Individual hashtag chip with tap behavior.
class _HashtagChip extends StatelessWidget {
  const _HashtagChip({
    required this.hashtag,
    required this.onTap,
    required this.colorIndex,
  });

  final String hashtag;
  final VoidCallback onTap;
  final int colorIndex;

  @override
  Widget build(BuildContext context) {
    final color = _accentColors[colorIndex % _accentColors.length];

    return Padding(
      padding: const EdgeInsets.only(right: 8),
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
