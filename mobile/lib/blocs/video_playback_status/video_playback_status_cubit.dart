// ABOUTME: Tracks per-video playback status reported by the native feed player.
// ABOUTME: Feed UIs read this to swap in moderated-content overlays.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_state.dart';

/// A lightweight cubit that tracks per-video playback status.
///
/// Widgets in the feed listen for the active video's entry and swap in
/// specialized overlays (moderated content, not found, retry) when the
/// native feed player reports an error.
class VideoPlaybackStatusCubit extends Cubit<VideoPlaybackStatusState> {
  /// Creates a cubit. [maxEntries] caps the internal LRU map; defaults
  /// to the [VideoPlaybackStatusState] default when null.
  VideoPlaybackStatusCubit({
    int? maxEntries,
    bool Function()? canAutoAuthorizeAgeRestrictedMedia,
  }) : _canAutoAuthorizeAgeRestrictedMedia = canAutoAuthorizeAgeRestrictedMedia,
       super(
         maxEntries == null
             ? VideoPlaybackStatusState()
             : VideoPlaybackStatusState(maxEntries: maxEntries),
       );

  final bool Function()? _canAutoAuthorizeAgeRestrictedMedia;

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

  /// Marks an age-verification retry as in flight for [eventId], driving the
  /// "Verify age" button's loading state. Short-circuits when already set.
  void markVerifying(String eventId) {
    if (state.isVerifying(eventId)) return;
    emit(state.withVerifying(eventId, true));
  }

  /// Clears the in-flight age-verification flag for [eventId]. Short-circuits
  /// when not set.
  void clearVerifying(String eventId) {
    if (!state.isVerifying(eventId)) return;
    emit(state.withVerifying(eventId, false));
  }

  /// Marks the automatic age-verification retry as spent for [eventId].
  ///
  /// Returns `true` when this call consumed the attempt budget, or `false`
  /// when an automatic retry was already attempted for the video.
  bool consumeAutoRetryAttempt(String eventId) {
    if (state.hasAutoRetryAttempted(eventId)) return false;
    emit(state.withAutoRetryAttempted(eventId));
    return true;
  }

  /// Consumes one automatic age-verification retry when the current playback
  /// state and viewer policy allow it.
  ///
  /// This keeps the retry/fallback decision in the cubit rather than in the
  /// error overlay. The caller still owns invoking the UI callback after this
  /// method grants the attempt.
  bool consumeAgeRestrictedAutoRetryIfEligible(
    String eventId, {
    required bool isAgeRestricted,
    required bool hasVerifyAction,
  }) {
    if (!isAgeRestricted || !hasVerifyAction) return false;
    if (state.isVerifying(eventId)) return false;
    if (!(_canAutoAuthorizeAgeRestrictedMedia?.call() ?? false)) return false;
    return consumeAutoRetryAttempt(eventId);
  }

  /// Clears all tracked statuses (call on feed-mode change).
  void clear() {
    emit(state.cleared());
  }
}
