// ABOUTME: Service for managing and tracking hashtags from Kind 22 video events
// ABOUTME: Provides hashtag statistics, trending data, and filtered video queries

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/video_event.dart';
import 'video_event_service.dart';

/// Model for hashtag statistics
class HashtagStats {
  final String hashtag;
  final int videoCount;
  final int recentVideoCount; // Videos in last 24 hours
  final DateTime firstSeen;
  final DateTime lastSeen;
  final Set<String> uniqueAuthors;

  HashtagStats({
    required this.hashtag,
    required this.videoCount,
    required this.recentVideoCount,
    required this.firstSeen,
    required this.lastSeen,
    required this.uniqueAuthors,
  });

  int get authorCount => uniqueAuthors.length;
  
  // Calculate trending score based on recency and engagement
  double get trendingScore {
    final recencyWeight = recentVideoCount / videoCount;
    final engagementWeight = authorCount / 100; // Normalize by 100 authors
    final hoursSinceLastSeen = DateTime.now().difference(lastSeen).inHours;
    final freshnessWeight = hoursSinceLastSeen < 24 ? 1.0 : 1.0 / (hoursSinceLastSeen / 24);
    
    return (recencyWeight * 0.5 + engagementWeight * 0.3 + freshnessWeight * 0.2) * 100;
  }
}

/// Service for managing hashtag data and statistics
class HashtagService extends ChangeNotifier {
  final VideoEventService _videoService;
  final Map<String, HashtagStats> _hashtagStats = {};
  Timer? _updateTimer;

  HashtagService(this._videoService) {
    _videoService.addListener(_updateHashtagStats);
    _updateHashtagStats();
    
    // Update stats every minute
    _updateTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _updateHashtagStats();
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _videoService.removeListener(_updateHashtagStats);
    super.dispose();
  }

  /// Update hashtag statistics from video events
  void _updateHashtagStats() {
    final now = DateTime.now();
    final twentyFourHoursAgo = now.subtract(const Duration(hours: 24));
    final newStats = <String, HashtagStats>{};

    for (final video in _videoService.videoEvents) {
      for (final hashtag in video.hashtags) {
        if (hashtag.isEmpty) continue;

        final existing = newStats[hashtag];
        final videoTime = DateTime.fromMillisecondsSinceEpoch(video.createdAt * 1000);
        final isRecent = videoTime.isAfter(twentyFourHoursAgo);

        if (existing == null) {
          newStats[hashtag] = HashtagStats(
            hashtag: hashtag,
            videoCount: 1,
            recentVideoCount: isRecent ? 1 : 0,
            firstSeen: videoTime,
            lastSeen: videoTime,
            uniqueAuthors: {video.pubkey},
          );
        } else {
          newStats[hashtag] = HashtagStats(
            hashtag: hashtag,
            videoCount: existing.videoCount + 1,
            recentVideoCount: existing.recentVideoCount + (isRecent ? 1 : 0),
            firstSeen: videoTime.isBefore(existing.firstSeen) ? videoTime : existing.firstSeen,
            lastSeen: videoTime.isAfter(existing.lastSeen) ? videoTime : existing.lastSeen,
            uniqueAuthors: {...existing.uniqueAuthors, video.pubkey},
          );
        }
      }
    }

    _hashtagStats.clear();
    _hashtagStats.addAll(newStats);
    notifyListeners();
  }

  /// Get all hashtags sorted by video count
  List<String> get allHashtags {
    final sorted = _hashtagStats.entries.toList()
      ..sort((a, b) => b.value.videoCount.compareTo(a.value.videoCount));
    return sorted.map((e) => e.key).toList();
  }

  /// Get trending hashtags based on trending score
  List<String> getTrendingHashtags({int limit = 20}) {
    final sorted = _hashtagStats.entries.toList()
      ..sort((a, b) => b.value.trendingScore.compareTo(a.value.trendingScore));
    return sorted.take(limit).map((e) => e.key).toList();
  }

  /// Get popular hashtags based on total video count
  List<String> getPopularHashtags({int limit = 20}) {
    final sorted = _hashtagStats.entries.toList()
      ..sort((a, b) => b.value.videoCount.compareTo(a.value.videoCount));
    return sorted.take(limit).map((e) => e.key).toList();
  }

  /// Get editor's picks - curated selection of interesting hashtags
  List<String> getEditorsPicks({int limit = 10}) {
    // For now, return hashtags with good engagement (multiple authors)
    final sorted = _hashtagStats.entries
        .where((e) => e.value.authorCount >= 3) // At least 3 different authors
        .toList()
      ..sort((a, b) => b.value.authorCount.compareTo(a.value.authorCount));
    return sorted.take(limit).map((e) => e.key).toList();
  }

  /// Get statistics for a specific hashtag
  HashtagStats? getHashtagStats(String hashtag) {
    return _hashtagStats[hashtag];
  }

  /// Get videos for specific hashtags
  List<VideoEvent> getVideosByHashtags(List<String> hashtags) {
    return _videoService.getVideoEventsByHashtags(hashtags);
  }

  /// Subscribe to videos with specific hashtags
  Future<void> subscribeToHashtagVideos(List<String> hashtags, {int limit = 100}) {
    return _videoService.subscribeToHashtagVideos(hashtags, limit: limit);
  }

  /// Search hashtags by prefix
  List<String> searchHashtags(String query) {
    if (query.isEmpty) return [];
    
    final lowercase = query.toLowerCase();
    return _hashtagStats.keys
        .where((tag) => tag.toLowerCase().contains(lowercase))
        .toList()
      ..sort((a, b) {
        // Prioritize exact matches and prefix matches
        final aLower = a.toLowerCase();
        final bLower = b.toLowerCase();
        
        if (aLower == lowercase) return -1;
        if (bLower == lowercase) return 1;
        if (aLower.startsWith(lowercase) && !bLower.startsWith(lowercase)) return -1;
        if (!aLower.startsWith(lowercase) && bLower.startsWith(lowercase)) return 1;
        
        // Then sort by popularity
        return _hashtagStats[b]!.videoCount.compareTo(_hashtagStats[a]!.videoCount);
      });
  }
}