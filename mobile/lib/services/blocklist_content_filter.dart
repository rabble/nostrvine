// ABOUTME: Creates a VideoContentFilter from ContentBlocklistRepository.
// ABOUTME: Bridges app-level blocklist service to repository-level filter.

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:videos_repository/videos_repository.dart';

/// Creates a [BlockedVideoFilter] that delegates to [blocklistService].
///
/// This allows the [VideosRepository] to filter blocked content without
/// depending directly on app-level services.
BlockedVideoFilter createBlocklistFilter(
  ContentBlocklistRepository blocklistService,
) {
  return blocklistService.shouldFilterFromFeeds;
}
