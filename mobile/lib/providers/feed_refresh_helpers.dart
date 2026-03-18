// ABOUTME: Shared helpers for explore feed providers
// ABOUTME: Extracts common stale-while-revalidate refresh pattern and utility functions

import 'package:models/models.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:riverpod/riverpod.dart';

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

/// Compares two video lists for equality by element identity.
bool videoListsEqual(List<VideoEvent> a, List<VideoEvent> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;

  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Returns the oldest `createdAt` timestamp from a list of videos,
/// useful for cursor-based pagination.
int? getOldestTimestamp(List<VideoEvent> videos) {
  if (videos.isEmpty) return null;
  return videos.map((v) => v.createdAt).reduce((a, b) => a < b ? a : b);
}
