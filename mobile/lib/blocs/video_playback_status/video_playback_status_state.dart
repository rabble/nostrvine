// ABOUTME: State for VideoPlaybackStatusCubit — LRU-bounded map of event
// ABOUTME: IDs to per-video playback status (ready/forbidden/age-restricted).

import 'dart:collection';

import 'package:equatable/equatable.dart';
import 'package:infinite_video_feed/infinite_video_feed.dart'
    show VideoErrorType;

/// Per-video playback status reported by the native feed player.
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

  /// Playback is unavailable after authenticated access was rejected.
  unavailable,

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
    Set<String>? verifyingIds,
    Set<String>? autoRetryAttemptedIds,
    Set<String>? authRetryExhaustedIds,
  }) : _statuses = statuses == null
           ? LinkedHashMap<String, PlaybackStatus>()
           : LinkedHashMap<String, PlaybackStatus>.from(statuses),
       _verifyingIds = verifyingIds == null
           ? <String>{}
           : Set<String>.from(verifyingIds),
       _autoRetryAttemptedIds = autoRetryAttemptedIds == null
           ? <String>{}
           : Set<String>.from(autoRetryAttemptedIds),
       _authRetryExhaustedIds = authRetryExhaustedIds == null
           ? <String>{}
           : Set<String>.from(authRetryExhaustedIds);

  static const int _defaultMaxEntries = 100;

  /// Maximum number of per-video entries to retain.
  final int maxEntries;

  final LinkedHashMap<String, PlaybackStatus> _statuses;

  /// Event IDs with an age-verification retry currently in flight. Transient
  /// and small (usually 0-1 entries); not LRU-bounded.
  final Set<String> _verifyingIds;

  /// Event IDs whose automatic age-verification retry has already been spent
  /// for this feed session. Kept above the overlay so retry teardown/rebuild
  /// cannot reset the attempt budget.
  final Set<String> _autoRetryAttemptedIds;

  /// Event IDs whose authenticated age-gate retry still failed for this feed
  /// session. This downgrades the UI claim from age-gated to unavailable.
  final Set<String> _authRetryExhaustedIds;

  /// Returns the status for [eventId], or [PlaybackStatus.ready] when no
  /// status has been recorded.
  PlaybackStatus statusFor(String eventId) =>
      _statuses[eventId] ?? PlaybackStatus.ready;

  /// Whether an age-verification retry is currently in flight for [eventId].
  /// Drives the "Verify age" button's loading state.
  bool isVerifying(String eventId) => _verifyingIds.contains(eventId);

  /// Whether the automatic age-verification retry has already been attempted
  /// for [eventId].
  bool hasAutoRetryAttempted(String eventId) =>
      _autoRetryAttemptedIds.contains(eventId);

  /// Whether authenticated playback was retried and still failed for [eventId].
  bool hasAuthRetryExhausted(String eventId) =>
      _authRetryExhaustedIds.contains(eventId);

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
      verifyingIds: _verifyingIds,
      autoRetryAttemptedIds: _autoRetryAttemptedIds,
      authRetryExhaustedIds: _authRetryExhaustedIds,
    );
  }

  /// Returns a new state with [eventId]'s verifying flag set to [verifying].
  VideoPlaybackStatusState withVerifying(String eventId, bool verifying) {
    final next = Set<String>.from(_verifyingIds);
    if (verifying) {
      next.add(eventId);
    } else {
      next.remove(eventId);
    }
    return VideoPlaybackStatusState(
      maxEntries: maxEntries,
      statuses: _statuses,
      verifyingIds: next,
      autoRetryAttemptedIds: _autoRetryAttemptedIds,
      authRetryExhaustedIds: _authRetryExhaustedIds,
    );
  }

  /// Returns a new state with [eventId]'s automatic retry attempt marked.
  VideoPlaybackStatusState withAutoRetryAttempted(String eventId) {
    final next = Set<String>.from(_autoRetryAttemptedIds)..add(eventId);
    return VideoPlaybackStatusState(
      maxEntries: maxEntries,
      statuses: _statuses,
      verifyingIds: _verifyingIds,
      autoRetryAttemptedIds: next,
      authRetryExhaustedIds: _authRetryExhaustedIds,
    );
  }

  /// Returns a new state with [eventId]'s authenticated retry marked exhausted.
  VideoPlaybackStatusState withAuthRetryExhausted(String eventId) {
    final next = Set<String>.from(_authRetryExhaustedIds)..add(eventId);
    return VideoPlaybackStatusState(
      maxEntries: maxEntries,
      statuses: _statuses,
      verifyingIds: _verifyingIds,
      autoRetryAttemptedIds: _autoRetryAttemptedIds,
      authRetryExhaustedIds: next,
    );
  }

  /// Returns a cleared state (used when switching feed modes).
  VideoPlaybackStatusState cleared() =>
      VideoPlaybackStatusState(maxEntries: maxEntries);

  @override
  List<Object?> get props {
    // Both entries are required.
    //
    // Equatable's default map comparison is structural (unordered), so
    // `_statuses` alone catches value changes but NOT pure LRU reorders
    // where the key/value set is unchanged.
    // `_statuses.keys.toList()` catches those insertion-order changes.
    // Removing either would silently suppress a whole class of state
    // updates — do not "simplify" this.
    return [
      _statuses,
      _statuses.keys.toList(),
      maxEntries,
      _verifyingIds,
      _autoRetryAttemptedIds,
      _authRetryExhaustedIds,
    ];
  }
}

/// Maps a [VideoErrorType] to the corresponding [PlaybackStatus] the cubit
/// should track.
///
/// Null defaults to [PlaybackStatus.generic] because a missing error type
/// still represents a non-ready state that should replace the normal
/// overlay.
PlaybackStatus playbackStatusFromError(
  VideoErrorType? errorType, {
  bool isModerationSource = true,
}) {
  return switch (errorType) {
    VideoErrorType.ageRestricted => PlaybackStatus.ageRestricted,
    VideoErrorType.forbidden when isModerationSource =>
      PlaybackStatus.forbidden,
    VideoErrorType.forbidden => PlaybackStatus.generic,
    VideoErrorType.notFound => PlaybackStatus.notFound,
    VideoErrorType.generic => PlaybackStatus.generic,
    null => PlaybackStatus.generic,
  };
}
