// ABOUTME: Riverpod providers for controlling video feed mode and context
// ABOUTME: Manages what type of content to show (following, curated, hashtag, etc)

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../state/video_feed_state.dart';

part 'feed_mode_providers.g.dart';

/// Provider for managing the current feed mode
@riverpod
class FeedModeNotifier extends _$FeedModeNotifier {
  @override
  FeedMode build() => FeedMode.following;
  
  /// Set the feed mode directly
  void setMode(FeedMode mode) {
    state = mode;
    
    // Clear context if switching to non-contextual mode
    if (mode == FeedMode.following || 
        mode == FeedMode.curated || 
        mode == FeedMode.discovery) {
      ref.read(feedContextProvider.notifier).clearContext();
    }
  }
  
  /// Switch to hashtag mode with specific hashtag
  void setHashtagMode(String hashtag) {
    state = FeedMode.hashtag;
    ref.read(feedContextProvider.notifier).setContext(hashtag);
  }
  
  /// Switch to profile mode with specific pubkey
  void setProfileMode(String pubkey) {
    state = FeedMode.profile;
    ref.read(feedContextProvider.notifier).setContext(pubkey);
  }
  
  /// Switch to following feed
  void showFollowing() => setMode(FeedMode.following);
  
  /// Switch to curated feed (editor's picks)
  void showCurated() => setMode(FeedMode.curated);
  
  /// Switch to discovery feed
  void showDiscovery() => setMode(FeedMode.discovery);
  
  /// Check if current mode requires context
  bool get requiresContext => 
    state == FeedMode.hashtag || state == FeedMode.profile;
}

/// Provider for managing feed context (hashtag or pubkey)
@riverpod
class FeedContext extends _$FeedContext {
  @override
  String? build() => null;
  
  /// Set the context value
  void setContext(String? context) {
    state = context;
  }
  
  /// Clear the context
  void clearContext() {
    state = null;
  }
  
  /// Get context as hashtag (without #)
  String? get hashtag {
    final mode = ref.read(feedModeNotifierProvider);
    if (mode == FeedMode.hashtag && state != null) {
      return state!.startsWith('#') ? state!.substring(1) : state;
    }
    return null;
  }
  
  /// Get context as pubkey
  String? get pubkey {
    final mode = ref.read(feedModeNotifierProvider);
    return mode == FeedMode.profile ? state : null;
  }
}