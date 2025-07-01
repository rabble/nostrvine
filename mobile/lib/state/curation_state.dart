// ABOUTME: Freezed state model for curation provider containing curated video sets
// ABOUTME: Manages editor picks, trending, and featured video collections

import 'package:freezed_annotation/freezed_annotation.dart';
import '../models/video_event.dart';
import '../models/curation_set.dart';

part 'curation_state.freezed.dart';

/// State model for curation provider
@freezed
class CurationState with _$CurationState {
  const factory CurationState({
    /// Editor's picks videos (classic vines)
    required List<VideoEvent> editorsPicks,
    
    /// Trending videos (from analytics API)
    required List<VideoEvent> trending,
    
    /// Featured high-quality videos
    required List<VideoEvent> featured,
    
    /// All available curation sets
    @Default([]) List<CurationSet> curationSets,
    
    /// Whether curation data is loading
    required bool isLoading,
    
    /// Whether trending was fetched from API
    @Default(false) bool trendingFromApi,
    
    /// Last refresh timestamp
    DateTime? lastRefreshed,
    
    /// Error message if any
    String? error,
  }) = _CurationState;
  
  const CurationState._();
  
  /// Get total number of curated videos
  int get totalCuratedVideos => 
    editorsPicks.length + trending.length + featured.length;
  
  /// Check if we have any curated content
  bool get hasCuratedContent => totalCuratedVideos > 0;
  
  /// Check if trending data is stale (older than 1 hour)
  bool get isTrendingStale {
    if (lastRefreshed == null) return true;
    return DateTime.now().difference(lastRefreshed!).inHours >= 1;
  }
  
  /// Get videos for a specific curation type
  List<VideoEvent> getVideosForType(CurationSetType type) {
    return switch (type) {
      CurationSetType.editorsPicks => editorsPicks,
      CurationSetType.trending => trending,
      CurationSetType.featured => featured,
      _ => [],
    };
  }
}