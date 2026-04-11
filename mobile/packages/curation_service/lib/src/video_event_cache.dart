// ABOUTME: Abstract interface for video event caching
// ABOUTME: Decouples CurationService from the concrete VideoEventService

import 'package:models/models.dart';

/// Minimal abstraction over [VideoEventService] used by
/// [CurationService] for reading and writing discovery videos.
///
/// App-side code provides a concrete adapter that delegates to
/// the real [VideoEventService].
abstract class VideoEventCache {
  /// All currently cached discovery videos.
  List<VideoEvent> get discoveryVideos;

  /// Add a single video to the discovery cache.
  void addVideoEvent(VideoEvent event);
}
