// ABOUTME: Abstract interface for video event caching.
// ABOUTME: Decouples consumers from the concrete VideoEventService.

import 'package:models/models.dart';

/// Minimal abstraction over video event caching used by packages
/// that need to read and write discovery videos without depending
/// on the concrete `VideoEventService`.
abstract class VideoEventCache {
  /// All currently cached discovery videos.
  List<VideoEvent> get discoveryVideos;

  /// Add a single video to the discovery cache.
  void addVideoEvent(VideoEvent event);
}
