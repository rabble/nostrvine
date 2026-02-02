// ABOUTME: Creates a VideoContentFilter from MuteService.
// ABOUTME: Bridges app-level mute service to repository-level filter.

import 'package:openvine/services/mute_service.dart';
import 'package:videos_repository/videos_repository.dart';

/// Creates a [BlockedVideoFilter] that delegates to [muteService].
///
/// This allows the [VideosRepository] to filter muted/blocked content without
/// depending directly on app-level services.
BlockedVideoFilter createBlocklistFilter(MuteService muteService) {
  return muteService.shouldFilterFromFeeds;
}
