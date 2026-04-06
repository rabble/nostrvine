// ABOUTME: Tracks per-video playback status reported by the pooled video
// ABOUTME: player. Feed UIs read this to swap in moderated-content overlays.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_state.dart';

/// A lightweight cubit that tracks per-video playback status.
///
/// Widgets in the feed listen for the active video's entry and swap in
/// specialized overlays (moderated content, not found, retry) when the
/// pooled video player reports an error.
class VideoPlaybackStatusCubit extends Cubit<VideoPlaybackStatusState> {
  /// Creates a cubit. [maxEntries] caps the internal LRU map; defaults
  /// to the [VideoPlaybackStatusState] default when null.
  VideoPlaybackStatusCubit({int? maxEntries})
    : super(
        maxEntries == null
            ? VideoPlaybackStatusState()
            : VideoPlaybackStatusState(maxEntries: maxEntries),
      );

  /// Reports [status] for the video with [eventId].
  ///
  /// Short-circuits when the reported status matches the current status for
  /// [eventId]. Without this guard, repeated reports (e.g. the feed
  /// `errorBuilder` firing every frame during a video retry loop) would
  /// allocate a new LinkedHashMap and emit on every frame.
  void report(String eventId, PlaybackStatus status) {
    if (state.statusFor(eventId) == status) return;
    emit(state.withStatus(eventId, status));
  }

  /// Clears all tracked statuses (call on feed-mode change).
  void clear() {
    emit(state.cleared());
  }
}
