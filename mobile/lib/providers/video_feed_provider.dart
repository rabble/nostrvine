// ABOUTME: Main orchestrator provider that coordinates video feed state
// ABOUTME: Replaces VideoEventBridge with reactive provider-based architecture

import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/video_event.dart';
import '../state/video_feed_state.dart';
import '../constants/app_constants.dart';
import '../utils/unified_logger.dart';
import 'feed_mode_providers.dart';
import 'video_events_providers.dart';
import 'social_providers.dart' as social;
import 'user_profile_providers.dart';

part 'video_feed_provider.g.dart';

/// Main video feed provider that orchestrates all video-related state
@riverpod
class VideoFeed extends _$VideoFeed {
  Timer? _profileFetchTimer;
  
  @override
  Future<VideoFeedState> build() async {
    // Clean up timer on dispose
    ref.onDispose(() {
      _profileFetchTimer?.cancel();
    });
    
    // Watch dependencies - auto-updates when they change
    final feedMode = ref.watch(feedModeNotifierProvider);
    final feedContext = ref.watch(feedContextProvider);
    final socialData = ref.watch(social.socialProvider);
    
    // Wait for video events to be available
    final videoEvents = await ref.watch(videoEventsProvider.future);
    
    Log.info('VideoFeed: Building with mode=$feedMode, context=$feedContext, videos=${videoEvents.length}', 
      name: 'VideoFeedProvider', category: LogCategory.video);
    
    // Determine primary content source
    final primaryPubkeys = _getPrimaryPubkeys(feedMode, socialData.followingPubkeys, feedContext);
    
    // Filter and sort videos
    final filteredVideos = _filterVideos(videoEvents, feedMode, primaryPubkeys, feedContext);
    final sortedVideos = _sortVideos(filteredVideos, feedMode);
    
    // Auto-fetch profiles for new videos
    _scheduleBatchProfileFetch(sortedVideos);
    
    // Calculate metrics
    final primaryVideoCount = _countPrimaryVideos(sortedVideos, primaryPubkeys);
    final hasMoreContent = _hasMoreContent(sortedVideos);
    
    return VideoFeedState(
      videos: sortedVideos,
      feedMode: feedMode,
      isFollowingFeed: feedMode == FeedMode.following,
      hasMoreContent: hasMoreContent,
      primaryVideoCount: primaryVideoCount,
      isLoadingMore: false,
      feedContext: feedContext,
      error: null, // Error handling will be done by AsyncNotifier
      lastUpdated: DateTime.now(),
    );
  }
  
  Set<String> _getPrimaryPubkeys(FeedMode mode, List<String> followingList, String? context) {
    return switch (mode) {
      FeedMode.following => followingList.isNotEmpty 
          ? followingList.toSet() 
          : {AppConstants.classicVinesPubkey}, // Fallback to Classic Vines
      FeedMode.curated => {AppConstants.classicVinesPubkey},
      FeedMode.profile => context != null ? {context} : {},
      _ => {}, // Discovery and hashtag modes have no primary pubkeys
    };
  }
  
  List<VideoEvent> _filterVideos(
    List<VideoEvent> videos, 
    FeedMode mode, 
    Set<String> primaryPubkeys,
    String? context,
  ) {
    switch (mode) {
      case FeedMode.following:
      case FeedMode.curated:
        // Filter by primary pubkeys
        return videos.where((v) => primaryPubkeys.contains(v.pubkey)).toList();
        
      case FeedMode.profile:
        // Filter by specific author
        return context != null 
          ? videos.where((v) => v.pubkey == context).toList()
          : [];
          
      case FeedMode.hashtag:
        // Filter by hashtag
        return context != null
          ? videos.where((v) => v.hashtags.contains(context)).toList()
          : [];
          
      case FeedMode.discovery:
        // Include all videos
        return videos;
    }
  }
  
  List<VideoEvent> _sortVideos(List<VideoEvent> videos, FeedMode mode) {
    // Always sort by creation time (newest first)
    final sorted = List<VideoEvent>.from(videos);
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    // Additional sorting logic could be added here based on mode
    // For example, trending videos could be sorted by engagement
    
    return sorted;
  }
  
  void _scheduleBatchProfileFetch(List<VideoEvent> videos) {
    // Cancel any existing timer
    _profileFetchTimer?.cancel();
    
    // Schedule profile fetch after a short delay to batch requests
    _profileFetchTimer = Timer(const Duration(milliseconds: 100), () {
      final profilesProvider = ref.read(userProfilesProvider.notifier);
      
      final newPubkeys = videos
          .map((v) => v.pubkey)
          .where((pubkey) => !profilesProvider.hasProfile(pubkey))
          .toSet()
          .toList();
      
      if (newPubkeys.isNotEmpty) {
        Log.debug('VideoFeed: Fetching ${newPubkeys.length} new profiles', 
          name: 'VideoFeedProvider', category: LogCategory.video);
        
        // Profile provider handles deduplication internally
        profilesProvider.fetchMultipleProfiles(newPubkeys);
      }
    });
  }
  
  int _countPrimaryVideos(List<VideoEvent> videos, Set<String> primaryPubkeys) {
    if (primaryPubkeys.isEmpty) return 0;
    return videos.where((v) => primaryPubkeys.contains(v.pubkey)).length;
  }
  
  bool _hasMoreContent(List<VideoEvent> videos) {
    // For now, assume more content if we have any videos
    // This could be enhanced with pagination info from the provider
    return videos.isNotEmpty;
  }
  
  /// Load more historical events
  Future<void> loadMore() async {
    final currentState = await future;
    if (currentState.isLoadingMore || currentState.isRefreshing) return;
    
    // Update state to show loading
    state = AsyncData(currentState.copyWith(isLoadingMore: true));
    
    try {
      await ref.read(videoEventsProvider.notifier).loadMoreEvents();
      
      // State will auto-update via dependencies
      Log.info('VideoFeed: Loaded more events', 
        name: 'VideoFeedProvider', category: LogCategory.video);
    } catch (e) {
      Log.error('VideoFeed: Error loading more: $e', 
        name: 'VideoFeedProvider', category: LogCategory.video);
      
      // Update state with error
      final currentState = await future;
      state = AsyncData(currentState.copyWith(
        isLoadingMore: false,
        error: e.toString(),
      ));
    }
  }
  
  /// Refresh the feed
  Future<void> refresh() async {
    Log.info('VideoFeed: Refreshing feed', 
      name: 'VideoFeedProvider', category: LogCategory.video);
    
    // Invalidate video events to force refresh
    ref.invalidate(videoEventsProvider);
    
    // Invalidate self to rebuild
    ref.invalidateSelf();
  }
  
  /// Update feed mode (convenience method)
  void setFeedMode(FeedMode mode) {
    ref.read(feedModeNotifierProvider.notifier).setMode(mode);
  }
  
  /// Set hashtag mode with context
  void setHashtagMode(String hashtag) {
    ref.read(feedModeNotifierProvider.notifier).setHashtagMode(hashtag);
  }
  
  /// Set profile mode with context
  void setProfileMode(String pubkey) {
    ref.read(feedModeNotifierProvider.notifier).setProfileMode(pubkey);
  }
}

/// Provider to check if video feed is loading
@riverpod
bool videoFeedLoading(VideoFeedLoadingRef ref) {
  final asyncState = ref.watch(videoFeedProvider);
  if (asyncState.isLoading) return true;
  
  final state = asyncState.valueOrNull;
  if (state == null) return false;
  
  return state.isLoadingMore || state.isRefreshing;
}

/// Provider to get current video count
@riverpod
int videoFeedCount(VideoFeedCountRef ref) {
  return ref.watch(videoFeedProvider).valueOrNull?.videos.length ?? 0;
}

/// Provider to get current feed mode
@riverpod
FeedMode currentFeedMode(CurrentFeedModeRef ref) {
  return ref.watch(feedModeNotifierProvider);
}

/// Provider to check if we have videos
@riverpod
bool hasVideos(HasVideosRef ref) {
  final count = ref.watch(videoFeedCountProvider);
  return count > 0;
}