// ABOUTME: Adapter bridging VideoEventService to the package-level
// ABOUTME: VideoEventCache interface used by curation_service.

import 'package:curation_service/curation_service.dart';
import 'package:models/models.dart';
import 'package:openvine/services/video_event_service.dart';

/// Wraps the app-level [VideoEventService] to satisfy the
/// [VideoEventCache] interface required by the extracted
/// `curation_service` package.
class VideoEventServiceAdapter implements VideoEventCache {
  /// Creates a [VideoEventServiceAdapter].
  const VideoEventServiceAdapter(this._delegate);

  final VideoEventService _delegate;

  @override
  List<VideoEvent> get discoveryVideos => _delegate.discoveryVideos;

  @override
  void addVideoEvent(VideoEvent event) => _delegate.addVideoEvent(event);
}
