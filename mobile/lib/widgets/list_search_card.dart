// ABOUTME: Card widget for displaying curated video list search results.
// ABOUTME: Separate from list_card.dart which is used by the Explore screen.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart' hide AspectRatio;
import 'package:openvine/widgets/vine_cached_image.dart';

/// Search card for a curated video list (kind 30005).
///
/// Shows a cover image thumbnail with video count badge,
/// plus title and description below. Designed for 2-column grid layout.
class CuratedListSearchCard extends StatelessWidget {
  const CuratedListSearchCard({
    required this.curatedList,
    required this.onTap,
    super.key,
  });

  final CuratedList curatedList;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: curatedList.name,
      container: true,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _VideoListThumbnail(
              imageUrl: curatedList.imageUrl,
              videoCount: curatedList.videoEventIds.length,
            ),
            const SizedBox(height: 8),
            _ListTitle(title: curatedList.name),
            if (curatedList.description != null &&
                curatedList.description!.isNotEmpty) ...[
              const SizedBox(height: 2),
              _ListDescription(description: curatedList.description!),
            ],
          ],
        ),
      ),
    );
  }
}

class _ListTitle extends StatelessWidget {
  const _ListTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: VineTheme.titleSmallFont(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _ListDescription extends StatelessWidget {
  const _ListDescription({required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    return Text(
      description,
      style: VineTheme.bodySmallFont(color: VineTheme.secondaryText),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// TODO(#2854): Replace single cover image with stacked video thumbnails.
class _VideoListThumbnail extends StatelessWidget {
  const _VideoListThumbnail({required this.videoCount, this.imageUrl});

  final String? imageUrl;
  final int videoCount;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3 / 2,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null && imageUrl!.isNotEmpty)
              VineCachedImage(imageUrl: imageUrl!)
            else
              const ColoredBox(
                color: VineTheme.cardBackground,
                child: Center(
                  child: DivineIcon(
                    icon: DivineIconName.play,
                    color: VineTheme.secondaryText,
                    size: 32,
                  ),
                ),
              ),
            Positioned(
              left: 8,
              bottom: 8,
              child: _CountBadge(count: videoCount),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withNoTextScaling(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: VineTheme.backgroundColor.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 4,
            children: [
              const DivineIcon(
                icon: DivineIconName.play,
                color: VineTheme.whiteText,
                size: 12,
              ),
              Text(
                '$count',
                style: VineTheme.labelSmallFont(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
