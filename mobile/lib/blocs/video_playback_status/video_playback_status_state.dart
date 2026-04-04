// ABOUTME: State for VideoPlaybackStatusCubit — LRU-bounded map of event
// ABOUTME: IDs to per-video playback status (ready/forbidden/age-restricted).

import 'dart:collection';

import 'package:equatable/equatable.dart';

/// Per-video playback status reported by the pooled video player.
enum PlaybackStatus {
  /// Loading or ready for playback. The default when no status has been
  /// recorded for an event.
  ready,

  /// Age-restricted — the media server returned 401 Unauthorized.
  ageRestricted,

  /// Moderation-restricted — the media server returned 403 Forbidden.
  forbidden,

  /// Content not found — 404 or unresolved blob hash.
  notFound,

  /// Any other playback failure.
  generic,
}

/// State for [VideoPlaybackStatusCubit].
///
/// Stores the playback status of recent videos keyed by event ID. The
/// internal map is LRU-bounded to [maxEntries] to keep memory use stable
/// during long feed sessions.
class VideoPlaybackStatusState extends Equatable {
  /// Creates a state with the given [maxEntries] cap and optional
  /// pre-populated [statuses]. Most callers should use the named
  /// constructor without arguments and then [withStatus] / [cleared]
  /// to produce updated states.
  VideoPlaybackStatusState({
    this.maxEntries = _defaultMaxEntries,
    LinkedHashMap<String, PlaybackStatus>? statuses,
  }) : _statuses =
           statuses ??
           // ignore: prefer_collection_literals
           LinkedHashMap<String, PlaybackStatus>();

  static const int _defaultMaxEntries = 100;

  /// Maximum number of per-video entries to retain.
  final int maxEntries;

  final LinkedHashMap<String, PlaybackStatus> _statuses;

  /// Returns the status for [eventId], or [PlaybackStatus.ready] when no
  /// status has been recorded.
  PlaybackStatus statusFor(String eventId) =>
      _statuses[eventId] ?? PlaybackStatus.ready;

  /// Returns a new state with [status] recorded for [eventId].
  ///
  /// If [eventId] already has an entry it is moved to most-recent. If the
  /// map exceeds [maxEntries] after insertion, the oldest entry is
  /// evicted.
  VideoPlaybackStatusState withStatus(String eventId, PlaybackStatus status) {
    final next = LinkedHashMap<String, PlaybackStatus>.from(_statuses)
      ..remove(eventId)
      ..[eventId] = status;
    while (next.length > maxEntries) {
      next.remove(next.keys.first);
    }
    return VideoPlaybackStatusState(
      maxEntries: maxEntries,
      statuses: next,
    );
  }

  /// Returns a cleared state (used when switching feed modes).
  VideoPlaybackStatusState cleared() =>
      VideoPlaybackStatusState(maxEntries: maxEntries);

  @override
  List<Object?> get props => [_statuses, maxEntries];
}
