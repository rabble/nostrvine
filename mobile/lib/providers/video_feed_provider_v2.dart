// ABOUTME: Clean TDD implementation of VideoFeedProvider using only IVideoManager
// ABOUTME: Single source of truth provider that eliminates dual-list architecture completely

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import '../models/video_event.dart';
import '../models/video_state.dart';
import '../services/video_manager_interface.dart';

/// Clean VideoFeedProvider implementation using only IVideoManager
/// 
/// This provider represents the pure TDD approach for connecting VideoManager
/// to the UI layer without any legacy dual-list architecture dependencies.
/// It serves as a simple wrapper around IVideoManager with state management.
class VideoFeedProviderV2 extends ChangeNotifier {
  final IVideoManager _videoManager;
  
  // Provider state
  bool _isInitialized = false;
  String? _error;
  bool _disposed = false;
  
  // Stream subscription for VideoManager state changes
  StreamSubscription<void>? _stateSubscription;
  
  VideoFeedProviderV2(this._videoManager) {
    _initializeStateSubscription();
  }
  
  // Core getters - delegate to VideoManager (single source of truth)
  List<VideoEvent> get videos => _videoManager.videos;
  List<VideoEvent> get readyVideos => _videoManager.readyVideos;
  int get videoCount => _videoManager.videos.length;
  bool get hasVideos => _videoManager.videos.isNotEmpty;
  bool get isInitialized => _isInitialized;
  bool get isLoading => false; // Simplified for V2
  String? get error => _error;
  
  // Direct VideoManager access
  IVideoManager get videoManager => _videoManager;
  VideoState? getVideoState(String videoId) => _videoManager.getVideoState(videoId);
  VideoPlayerController? getController(String videoId) => _videoManager.getController(videoId);
  Map<String, dynamic> getDebugInfo() => _videoManager.getDebugInfo();
  
  /// Initialize the provider
  Future<void> initialize() async {
    if (_isInitialized || _disposed) return;
    
    try {
      _error = null;
      // VideoManager doesn't need explicit initialization
      // Just mark as initialized
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to initialize: $e';
      notifyListeners();
    }
  }
  
  /// Add video event to VideoManager
  Future<void> addVideo(VideoEvent event) async {
    if (_disposed) return;
    await _videoManager.addVideoEvent(event);
    // VideoManager will handle state notifications
  }
  
  /// Preload videos around current index
  void preloadAroundIndex(int currentIndex, {int? preloadRange}) {
    if (_disposed) return;
    _videoManager.preloadAroundIndex(currentIndex, preloadRange: preloadRange);
  }
  
  /// Preload specific video by ID
  Future<void> preloadVideo(String videoId) async {
    if (_disposed) return;
    await _videoManager.preloadVideo(videoId);
  }
  
  /// Dispose specific video
  void disposeVideo(String videoId) {
    if (_disposed) return;
    _videoManager.disposeVideo(videoId);
  }
  
  /// Handle memory pressure
  Future<void> handleMemoryPressure() async {
    if (_disposed) return;
    await _videoManager.handleMemoryPressure();
  }
  
  /// Initialize state change subscription
  void _initializeStateSubscription() {
    _stateSubscription = _videoManager.stateChanges.listen((_) {
      if (!_disposed) {
        notifyListeners();
      }
    });
  }
  
  @override
  void dispose() {
    if (_disposed) return;
    
    _disposed = true;
    _stateSubscription?.cancel();
    // Don't dispose the injected VideoManager - it's managed externally
    super.dispose();
  }
}