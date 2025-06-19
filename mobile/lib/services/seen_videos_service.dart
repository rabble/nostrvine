// ABOUTME: Service for tracking which videos have been viewed by the user
// ABOUTME: Prevents duplicate videos from appearing in the feed by filtering seen content

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for tracking seen videos to prevent duplicates in feed
class SeenVideosService extends ChangeNotifier {
  static const String _seenVideosKey = 'seen_video_ids';
  static const int _maxSeenVideos = 1000; // Limit storage to prevent unbounded growth
  
  final Set<String> _seenVideoIds = {};
  SharedPreferences? _prefs;
  bool _isInitialized = false;
  
  /// Whether the service has been initialized
  bool get isInitialized => _isInitialized;
  
  /// Get count of seen videos
  int get seenVideoCount => _seenVideoIds.length;
  
  /// Initialize the service and load seen videos from storage
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadSeenVideos();
      _isInitialized = true;
      notifyListeners();
      debugPrint('👁️ SeenVideosService initialized with ${_seenVideoIds.length} seen videos');
    } catch (e) {
      debugPrint('❌ Failed to initialize SeenVideosService: $e');
    }
  }
  
  /// Load seen videos from persistent storage
  Future<void> _loadSeenVideos() async {
    if (_prefs == null) return;
    
    try {
      final seenList = _prefs!.getStringList(_seenVideosKey) ?? [];
      _seenVideoIds.clear();
      _seenVideoIds.addAll(seenList);
      debugPrint('📂 Loaded ${_seenVideoIds.length} seen videos from storage');
    } catch (e) {
      debugPrint('❌ Error loading seen videos: $e');
    }
  }
  
  /// Save seen videos to persistent storage
  Future<void> _saveSeenVideos() async {
    if (_prefs == null) return;
    
    try {
      // Convert to list and limit size if needed
      List<String> videoList = _seenVideoIds.toList();
      
      // If we exceed max, keep only the most recent
      if (videoList.length > _maxSeenVideos) {
        videoList = videoList.sublist(videoList.length - _maxSeenVideos);
        _seenVideoIds.clear();
        _seenVideoIds.addAll(videoList);
      }
      
      await _prefs!.setStringList(_seenVideosKey, videoList);
      debugPrint('💾 Saved ${videoList.length} seen videos to storage');
    } catch (e) {
      debugPrint('❌ Error saving seen videos: $e');
    }
  }
  
  /// Check if a video has been seen
  bool hasSeenVideo(String videoId) {
    return _seenVideoIds.contains(videoId);
  }
  
  /// Mark a video as seen
  Future<void> markVideoAsSeen(String videoId) async {
    if (_seenVideoIds.contains(videoId)) {
      return; // Already seen
    }
    
    debugPrint('👁️ Marking video as seen: ${videoId.substring(0, 8)}...');
    _seenVideoIds.add(videoId);
    
    // Save to storage asynchronously
    await _saveSeenVideos();
    
    // Notify listeners that seen videos have changed
    notifyListeners();
  }
  
  /// Mark multiple videos as seen (batch operation)
  Future<void> markVideosAsSeen(List<String> videoIds) async {
    bool hasChanges = false;
    
    for (final videoId in videoIds) {
      if (!_seenVideoIds.contains(videoId)) {
        _seenVideoIds.add(videoId);
        hasChanges = true;
      }
    }
    
    if (hasChanges) {
      await _saveSeenVideos();
      notifyListeners();
    }
  }
  
  /// Clear all seen videos (for testing or user preference)
  Future<void> clearSeenVideos() async {
    debugPrint('🗑️ Clearing all seen videos');
    _seenVideoIds.clear();
    
    if (_prefs != null) {
      await _prefs!.remove(_seenVideosKey);
    }
    
    notifyListeners();
  }
  
  /// Remove a specific video from seen list (mark as unseen)
  Future<void> markVideoAsUnseen(String videoId) async {
    if (!_seenVideoIds.contains(videoId)) {
      return; // Not in seen list
    }
    
    debugPrint('👁️ Marking video as unseen: ${videoId.substring(0, 8)}...');
    _seenVideoIds.remove(videoId);
    
    await _saveSeenVideos();
    notifyListeners();
  }
  
  /// Get statistics about seen videos
  Map<String, dynamic> getStatistics() {
    return {
      'totalSeen': _seenVideoIds.length,
      'storageLimit': _maxSeenVideos,
      'percentageFull': (_seenVideoIds.length / _maxSeenVideos * 100).toStringAsFixed(1),
    };
  }
  
  @override
  void dispose() {
    // Save any pending changes before disposing
    _saveSeenVideos();
    super.dispose();
  }
}