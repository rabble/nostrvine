// ABOUTME: Shared helpers for explore feed providers
// ABOUTME: Extracts common stale-while-revalidate refresh pattern and utility functions

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/state/video_feed_state.dart';

/// Implements the stale-while-revalidate pattern for feed refresh.
///
/// Shows existing data with a refreshing indicator while fetching fresh data.
/// On error, preserves the existing state with an error message.
Future<void> staleWhileRevalidate({
  required AsyncValue<VideoFeedState> Function() getCurrentState,
  required bool Function() isMounted,
  required void Function(AsyncValue<VideoFeedState>) setState,
  required Future<VideoFeedState> Function() fetchFresh,
}) async {
  final currentState = getCurrentState().asData?.value;
  if (currentState != null && isMounted()) {
    setState(
      AsyncData(
        currentState.copyWith(
          isRefreshing: true,
          isInitialLoad: false,
          error: null,
        ),
      ),
    );
  }
  try {
    final refreshed = await fetchFresh();
    if (!isMounted()) return;
    setState(
      AsyncData(
        refreshed.copyWith(
          isRefreshing: false,
          isInitialLoad: false,
          error: null,
        ),
      ),
    );
  } catch (e) {
    if (!isMounted()) return;
    if (currentState != null) {
      setState(
        AsyncData(
          currentState.copyWith(isRefreshing: false, error: e.toString()),
        ),
      );
      return;
    }
    setState(
      AsyncData(
        VideoFeedState(
          videos: const [],
          hasMoreContent: false,
          error: e.toString(),
        ),
      ),
    );
  }
}

/// Merges enriched video data into an existing list by matching on ID.
///
/// Replaces each video in [existing] with its enriched counterpart from
/// [enriched] if one exists (case-insensitive ID match).
List<VideoEvent> mergeEnrichedVideos({
  required List<VideoEvent> existing,
  required List<VideoEvent> enriched,
}) {
  final enrichedById = {
    for (final video in enriched) video.id.toLowerCase(): video,
  };

  return existing.map((video) {
    return enrichedById[video.id.toLowerCase()] ?? video;
  }).toList();
}

/// Removes videos whose [VideoEvent.feedDedupKey] has already been seen,
/// preserving first-occurrence order.
///
/// Deduplicates by the addressable coordinate (`kind:pubkey:d-tag`) when
/// present, else the event id — so a video republished with a fresh event id
/// (which the Funnelcake emitted-id cursor dedupes only by event id) never
/// appears twice. Seed [alreadySeen] with the keys already displayed to also
/// drop cross-page duplicates when appending a paginated page.
List<VideoEvent> dedupeByFeedKey(
  List<VideoEvent> videos, {
  Iterable<String> alreadySeen = const [],
}) {
  final seen = alreadySeen.toSet();
  final result = <VideoEvent>[];
  for (final video in videos) {
    if (seen.add(video.feedDedupKey)) {
      result.add(video);
    }
  }
  return result;
}

/// Compares two video lists for equality by element identity.
bool videoListsEqual(List<VideoEvent> a, List<VideoEvent> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;

  for (var i = 0; i < a.length; i++) {
    if (!identical(a[i], b[i])) return false;
  }
  return true;
}

/// Returns the oldest `createdAt` timestamp from a list of videos,
/// useful for cursor-based pagination.
int? getOldestTimestamp(List<VideoEvent> videos) {
  if (videos.isEmpty) return null;
  return videos.map((v) => v.createdAt).reduce((a, b) => a < b ? a : b);
}
