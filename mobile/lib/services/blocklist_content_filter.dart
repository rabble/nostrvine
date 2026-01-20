// ABOUTME: Creates a VideoContentFilter from ContentBlocklistService.
// ABOUTME: Bridges app-level blocklist service to repository-level filter.

import 'package:openvine/services/content_blocklist_service.dart';
import 'package:videos_repository/videos_repository.dart';

/// Creates a [VideoContentFilter] that delegates to [blocklistService].
///
/// This allows the [VideosRepository] to filter blocked content without
/// depending directly on app-level services.
VideoContentFilter createBlocklistFilter(
  ContentBlocklistService blocklistService,
) {
  return blocklistService.shouldFilterFromFeeds;
}
