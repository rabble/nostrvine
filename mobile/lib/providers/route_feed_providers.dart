// ABOUTME: Route-aware feed providers that select correct video source per route
// ABOUTME: Enables router-driven screens to reactively get route-appropriate data

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/state/video_feed_state.dart';

/// Provider to hold the explore tab's current video list.
/// Set by ExploreScreen when entering feed mode and consumed by
/// activeVideoIdProvider for deep-link-aware active video resolution.
final exploreTabVideosProvider = StateProvider<List<VideoEvent>?>(
  (ref) => null,
);

/// Provider that registers a callback to auto-update exploreTabVideosProvider
/// when a video is updated. Must be watched by a widget to activate.
final exploreTabVideoUpdateListenerProvider = Provider<void>((ref) {
  final videoEventService = ref.watch(videoEventServiceProvider);

  final unregister = videoEventService.addVideoUpdateListener((updated) {
    final currentVideos = ref.read(exploreTabVideosProvider);
    if (currentVideos != null) {
      final updatedList = currentVideos.map((v) {
        if (v.stableId == updated.stableId && v.pubkey == updated.pubkey) {
          return updated;
        }
        return v;
      }).toList();
      ref.read(exploreTabVideosProvider.notifier).state = updatedList;
    }
  });

  ref.onDispose(unregister);
});

/// Provider to persist the current tab index across widget recreation.
/// Default to 1. Note: navigate to `ExploreScreen.pathForTab(name)` for
/// semantic tab selection that survives tab count changes.
final exploreTabIndexProvider = StateProvider<int>((ref) => 1);

/// Index of the currently-active bottom-nav branch
/// (0 = Home, 1 = Explore, 2 = Inbox, 3 = Profile).
///
/// Kept in sync by [AppShell] from the StatefulShellRoute's
/// `navigationShell.currentIndex` — the authoritative active-tab signal set by
/// go_router. Backgrounded tab screens (e.g. the home feed) pause off this
/// rather than the URL-derived pageContext, which can lag on web for
/// StatefulShellRoute branch switches.
final activeBranchIndexProvider = StateProvider<int>((ref) => 0);

/// Explore feed state (discovery/all videos)
/// Returns AsyncValue<VideoFeedState> for route-aware explore screen
/// Uses tab-specific list when in feed mode, otherwise sorted by loop count
/// Filters out broken videos to match grid UI behavior
final videosForExploreRouteProvider = Provider<AsyncValue<VideoFeedState>>((
  ref,
) {
  final contextAsync = ref.watch(pageContextProvider);

  return contextAsync.when(
    data: (ctx) {
      if (ctx.type != RouteType.explore) {
        // Not on explore route - return loading
        return const AsyncValue.loading();
      }

      final brokenTrackerAsync = ref.watch(brokenVideoTrackerProvider);

      // Check if we have a tab-specific list (set when user enters feed mode)
      final tabVideos = ref.watch(exploreTabVideosProvider);
      if (tabVideos != null && tabVideos.isNotEmpty) {
        ref.watch(divineHostFilterVersionProvider);
        ref.watch(contentFilterVersionProvider);
        final videoEventService = ref.read(videoEventServiceProvider);
        final visibleTabVideos = videoEventService.filterVideoList(tabVideos);

        // Filter broken videos to match the pooled feed's video list.
        // Both must use the same filtered list so URL indices align with
        // the videos actually shown on screen.
        final filteredTabVideos = brokenTrackerAsync.maybeWhen(
          data: (tracker) => visibleTabVideos
              .where((video) => !tracker.isVideoBroken(video.id))
              .toList(),
          orElse: () => visibleTabVideos,
        );
        return AsyncValue.data(
          VideoFeedState(
            videos: filteredTabVideos,
            hasMoreContent: true,
            lastUpdated: DateTime.now(),
          ),
        );
      }

      // No tab list - use default behavior (loop-count sorted)
      final eventsAsync = ref.watch(videoEventsProvider);

      return eventsAsync.when(
        data: (videos) {
          // Filter out broken videos to match ComposableVideoGrid behavior
          final filteredVideos = brokenTrackerAsync.maybeWhen(
            data: (tracker) => videos
                .where((video) => !tracker.isVideoBroken(video.id))
                .toList(),
            orElse: () => videos, // No filtering if tracker not ready
          );

          // Sort by loop count (descending) as default
          final sortedVideos = List<VideoEvent>.from(filteredVideos);
          sortedVideos.sort((a, b) {
            final aLoops = a.originalLoops ?? 0;
            final bLoops = b.originalLoops ?? 0;
            return bLoops.compareTo(aLoops); // Descending order
          });
          return AsyncValue.data(
            VideoFeedState(
              videos: sortedVideos,
              hasMoreContent: true,
              lastUpdated: DateTime.now(),
            ),
          );
        },
        loading: () => const AsyncValue.loading(),
        error: AsyncValue.error,
      );
    },
    loading: () => const AsyncValue.loading(),
    error: AsyncValue.error,
  );
});
