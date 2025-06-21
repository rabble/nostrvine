// ABOUTME: Provider for managing profile statistics with async loading and caching
// ABOUTME: Aggregates user video count, likes, and other metrics from Nostr events

import 'package:flutter/foundation.dart';
import '../services/social_service.dart';

/// Statistics for a user's profile
class ProfileStats {
  final int videoCount;
  final int totalLikes;
  final int followers;
  final int following;
  final int totalViews; // Placeholder for future implementation
  final DateTime lastUpdated;

  const ProfileStats({
    required this.videoCount,
    required this.totalLikes,
    required this.followers,
    required this.following,
    required this.totalViews,
    required this.lastUpdated,
  });

  ProfileStats copyWith({
    int? videoCount,
    int? totalLikes,
    int? followers,
    int? following,
    int? totalViews,
    DateTime? lastUpdated,
  }) {
    return ProfileStats(
      videoCount: videoCount ?? this.videoCount,
      totalLikes: totalLikes ?? this.totalLikes,
      followers: followers ?? this.followers,
      following: following ?? this.following,
      totalViews: totalViews ?? this.totalViews,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  String toString() {
    return 'ProfileStats(videos: $videoCount, likes: $totalLikes, followers: $followers, following: $following, views: $totalViews)';
  }
}

/// Loading state for profile statistics
enum ProfileStatsLoadingState {
  idle,
  loading,
  loaded,
  error,
}

/// Provider for managing profile statistics with async loading and caching
class ProfileStatsProvider extends ChangeNotifier {
  final SocialService _socialService;

  // State management
  ProfileStatsLoadingState _loadingState = ProfileStatsLoadingState.idle;
  ProfileStats? _stats;
  String? _error;
  String? _currentPubkey;

  // Cache for expensive operations
  final Map<String, ProfileStats> _statsCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);

  ProfileStatsProvider(this._socialService);

  // Getters
  ProfileStatsLoadingState get loadingState => _loadingState;
  ProfileStats? get stats => _stats;
  String? get error => _error;
  bool get isLoading => _loadingState == ProfileStatsLoadingState.loading;
  bool get hasError => _loadingState == ProfileStatsLoadingState.error;
  bool get hasData => _stats != null;

  /// Load complete statistics for a user profile
  Future<void> loadProfileStats(String pubkey) async {
    if (_currentPubkey == pubkey && _stats != null) {
      // Already loaded for this user
      return;
    }

    // Check cache first
    final cached = _getCachedStats(pubkey);
    if (cached != null) {
      _stats = cached;
      _currentPubkey = pubkey;
      _loadingState = ProfileStatsLoadingState.loaded;
      _error = null;
      notifyListeners();
      return;
    }

    _setLoadingState(ProfileStatsLoadingState.loading);
    _currentPubkey = pubkey;
    _error = null;

    try {
      debugPrint('📊 Loading profile stats for: ${pubkey.substring(0, 8)}...');

      // Load all stats in parallel for better performance
      final results = await Future.wait([
        _socialService.getFollowerStats(pubkey),
        _socialService.getUserVideoCount(pubkey),
        _socialService.getUserTotalLikes(pubkey),
      ]);

      final followerStats = results[0] as Map<String, int>;
      final videoCount = results[1] as int;
      final totalLikes = results[2] as int;

      _stats = ProfileStats(
        videoCount: videoCount,
        totalLikes: totalLikes,
        followers: followerStats['followers'] ?? 0,
        following: followerStats['following'] ?? 0,
        totalViews: 0, // Placeholder for future implementation
        lastUpdated: DateTime.now(),
      );

      // Cache the results
      _cacheStats(pubkey, _stats!);

      _setLoadingState(ProfileStatsLoadingState.loaded);
      debugPrint('✅ Profile stats loaded: $_stats');

    } catch (e) {
      _error = e.toString();
      _setLoadingState(ProfileStatsLoadingState.error);
      debugPrint('❌ Error loading profile stats: $e');
    }
  }

  /// Refresh stats by clearing cache and reloading
  Future<void> refreshStats() async {
    if (_currentPubkey != null) {
      _clearCache(_currentPubkey!);
      _stats = null; // Clear current stats to force reload
      await loadProfileStats(_currentPubkey!);
    }
  }

  /// Get cached stats if available and not expired
  ProfileStats? _getCachedStats(String pubkey) {
    final stats = _statsCache[pubkey];
    final timestamp = _cacheTimestamps[pubkey];

    if (stats != null && timestamp != null) {
      final age = DateTime.now().difference(timestamp);
      if (age < _cacheExpiry) {
        debugPrint('💾 Using cached stats for ${pubkey.substring(0, 8)} (age: ${age.inMinutes}min)');
        return stats;
      } else {
        debugPrint('⏰ Cache expired for ${pubkey.substring(0, 8)} (age: ${age.inMinutes}min)');
        _clearCache(pubkey);
      }
    }

    return null;
  }

  /// Cache stats for a user
  void _cacheStats(String pubkey, ProfileStats stats) {
    _statsCache[pubkey] = stats;
    _cacheTimestamps[pubkey] = DateTime.now();
    debugPrint('💾 Cached stats for ${pubkey.substring(0, 8)}');
  }

  /// Clear cache for a specific user
  void _clearCache(String pubkey) {
    _statsCache.remove(pubkey);
    _cacheTimestamps.remove(pubkey);
  }

  /// Clear all cached stats
  void clearAllCache() {
    _statsCache.clear();
    _cacheTimestamps.clear();
    debugPrint('🗑️ Cleared all stats cache');
  }

  /// Set loading state and notify listeners
  void _setLoadingState(ProfileStatsLoadingState state) {
    _loadingState = state;
    notifyListeners();
  }

  /// Get a formatted string for large numbers (e.g., 1234 -> "1.2K")
  static String formatCount(int count) {
    if (count >= 1000000000) {
      return '${(count / 1000000000).toStringAsFixed(1)}B';
    } else if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return count.toString();
    }
  }

  @override
  void dispose() {
    debugPrint('🗑️ Disposing ProfileStatsProvider');
    super.dispose();
  }
}