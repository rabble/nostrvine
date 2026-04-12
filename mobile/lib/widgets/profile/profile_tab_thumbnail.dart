// ABOUTME: Shared cached thumbnail widget for profile tab grids
// ABOUTME: Wraps VineCachedImage with placeholder and error fallbacks

import 'package:flutter/material.dart';
import 'package:openvine/widgets/profile/profile_tab_thumbnail_placeholder.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

/// Cached thumbnail for profile grid tiles.
///
/// Shows a [VineCachedImage] when [thumbnailUrl] is non-empty, falling back
/// to [ProfileTabThumbnailPlaceholder] for loading, error, and null states.
///
/// Set [isPrecached] to `true` to skip fade animations (used when the image
/// was already resolved before the widget mounted).
class ProfileTabThumbnail extends StatelessWidget {
  const ProfileTabThumbnail({
    required this.thumbnailUrl,
    this.isPrecached = false,
    super.key,
  });

  final String? thumbnailUrl;
  final bool isPrecached;

  @override
  Widget build(BuildContext context) {
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) {
      return VineCachedImage(
        imageUrl: thumbnailUrl!,
        fadeInDuration: isPrecached
            ? Duration.zero
            : const Duration(milliseconds: 500),
        fadeOutDuration: isPrecached
            ? Duration.zero
            : const Duration(milliseconds: 1000),
        placeholder: (context, url) => const ProfileTabThumbnailPlaceholder(),
        errorWidget: (context, url, error) =>
            const ProfileTabThumbnailPlaceholder(),
      );
    }
    return const ProfileTabThumbnailPlaceholder();
  }
}
