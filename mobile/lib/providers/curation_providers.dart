// ABOUTME: Riverpod provider for content curation with reactive updates
// ABOUTME: Manages editor picks, trending, and featured video collections

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../state/curation_state.dart';
import '../services/curation_service.dart';
import '../models/curation_set.dart';
import '../models/video_event.dart';
import '../utils/unified_logger.dart';
import 'video_events_providers.dart';

part 'curation_providers.g.dart';

/// Provider for CurationService instance
@riverpod
CurationService curationService(CurationServiceRef ref) {
  throw UnimplementedError('CurationService must be overridden in ProviderScope');
}

/// Main curation provider that manages curated content sets
@riverpod
class Curation extends _$Curation {
  @override
  CurationState build() {
    // Auto-refresh when video events change
    ref.listen(videoEventsProvider, (previous, next) {
      // Only refresh if we have new video events
      if (next.hasValue && previous?.valueOrNull?.length != next.valueOrNull?.length) {
        _refreshCurationSets();
      }
    });
    
    // Initialize with empty state
    _initializeCuration();
    
    return const CurationState(
      editorsPicks: [],
      trending: [],
      featured: [],
      isLoading: true,
    );
  }
  
  Future<void> _initializeCuration() async {
    try {
      final service = ref.read(curationServiceProvider);
      
      Log.debug('Curation: Initializing curation sets', 
        name: 'CurationProvider', category: LogCategory.system);
      
      // CurationService initializes itself in constructor
      // Just get the current data
      state = CurationState(
        editorsPicks: service.getVideosForSetType(CurationSetType.editorsPicks),
        trending: service.getVideosForSetType(CurationSetType.trending),
        featured: service.getVideosForSetType(CurationSetType.featured),
        isLoading: false,
      );
      
      Log.info('Curation: Loaded ${state.editorsPicks.length} editor picks, '
               '${state.trending.length} trending, ${state.featured.length} featured', 
        name: 'CurationProvider', category: LogCategory.system);
      
    } catch (e) {
      Log.error('Curation: Initialization error: $e', 
        name: 'CurationProvider', category: LogCategory.system);
      
      state = CurationState(
        editorsPicks: [],
        trending: [],
        featured: [],
        isLoading: false,
        error: e.toString(),
      );
    }
  }
  
  Future<void> _refreshCurationSets() async {
    final service = ref.read(curationServiceProvider);
    
    try {
      service.refreshIfNeeded();
      
      // Update state with refreshed data
      state = state.copyWith(
        editorsPicks: service.getVideosForSetType(CurationSetType.editorsPicks),
        trending: service.getVideosForSetType(CurationSetType.trending),
        featured: service.getVideosForSetType(CurationSetType.featured),
        error: null,
      );
      
      Log.debug('Curation: Refreshed curation sets', 
        name: 'CurationProvider', category: LogCategory.system);
      
    } catch (e) {
      Log.error('Curation: Refresh error: $e', 
        name: 'CurationProvider', category: LogCategory.system);
      
      state = state.copyWith(error: e.toString());
    }
  }
  
  /// Manually refresh trending videos from analytics
  Future<void> refreshTrending() async {
    if (state.isLoading) return;
    
    state = state.copyWith(isLoading: true);
    
    try {
      final service = ref.read(curationServiceProvider);
      await service.refreshTrendingFromAnalytics();
      
      // Update state with new trending videos
      state = state.copyWith(
        trending: service.getVideosForSetType(CurationSetType.trending),
        isLoading: false,
        error: null,
      );
      
      Log.info('Curation: Refreshed trending videos', 
        name: 'CurationProvider', category: LogCategory.system);
      
    } catch (e) {
      Log.error('Curation: Error refreshing trending: $e', 
        name: 'CurationProvider', category: LogCategory.system);
      
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
  
  /// Force refresh all curation sets
  Future<void> forceRefresh() async {
    if (state.isLoading) return;
    
    state = state.copyWith(isLoading: true);
    
    try {
      final service = ref.read(curationServiceProvider);
      
      // Force refresh from remote
      await service.refreshCurationSets();
      
      // Update state
      state = CurationState(
        editorsPicks: service.getVideosForSetType(CurationSetType.editorsPicks),
        trending: service.getVideosForSetType(CurationSetType.trending),
        featured: service.getVideosForSetType(CurationSetType.featured),
        isLoading: false,
      );
      
      Log.info('Curation: Force refreshed all sets', 
        name: 'CurationProvider', category: LogCategory.system);
      
    } catch (e) {
      Log.error('Curation: Force refresh error: $e', 
        name: 'CurationProvider', category: LogCategory.system);
      
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}

/// Provider to check if curation is loading
@riverpod
bool curationLoading(CurationLoadingRef ref) {
  return ref.watch(curationProvider).isLoading;
}

/// Provider to get editor's picks
@riverpod
List<VideoEvent> editorsPicks(EditorsPicksRef ref) {
  return ref.watch(curationProvider.select((state) => state.editorsPicks));
}

/// Provider to get trending videos
@riverpod
List<VideoEvent> trendingVideos(TrendingVideosRef ref) {
  return ref.watch(curationProvider.select((state) => state.trending));
}

/// Provider to get featured videos
@riverpod
List<VideoEvent> featuredVideos(FeaturedVideosRef ref) {
  return ref.watch(curationProvider.select((state) => state.featured));
}