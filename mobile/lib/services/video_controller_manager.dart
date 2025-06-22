// ABOUTME: Video controller lifecycle management with play/pause coordination
// ABOUTME: Handles video playback state coordination and prevents multiple videos playing simultaneously

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import '../models/video_event.dart';
import '../models/video_state.dart';
import 'video_manager_interface.dart';

/// Extension methods for VideoManagerService to handle playback control
/// 
/// This class manages the lifecycle of video playback including:
/// - Play/pause coordination (only one video plays at a time)
/// - Volume management
/// - Looping behavior
/// - Performance optimization
mixin VideoControllerManager on ChangeNotifier {
  // Current playback state
  String? _currentlyPlayingVideoId;
  bool _isMuted = false;
  bool _isLooping = true;

  // Performance tracking
  final Map<String, DateTime> _lastPlayTime = {};
  final Map<String, int> _playCount = {};

  /// Get the currently playing video ID
  String? get currentlyPlayingVideoId => _currentlyPlayingVideoId;

  /// Whether videos should play muted by default
  bool get isMuted => _isMuted;

  /// Whether videos should loop
  bool get isLooping => _isLooping;

  /// Play a specific video and pause all others
  Future<void> playVideo(String videoId) async {
    try {
      // Get the video manager (this mixin is used with VideoManagerService)
      final videoManager = this as IVideoManager;
      final controller = videoManager.getController(videoId);
      
      if (controller == null) {
        debugPrint('VideoControllerManager: No controller found for $videoId');
        return;
      }

      // Pause currently playing video if different
      if (_currentlyPlayingVideoId != null && _currentlyPlayingVideoId != videoId) {
        await pauseVideo(_currentlyPlayingVideoId!);
      }

      // Configure and play new video
      await _configureController(controller);
      await controller.play();
      
      _currentlyPlayingVideoId = videoId;
      _trackPlayback(videoId);
      
      debugPrint('VideoControllerManager: Playing video $videoId');
      notifyListeners();

    } catch (e) {
      debugPrint('VideoControllerManager: Error playing video $videoId: $e');
    }
  }

  /// Pause a specific video
  Future<void> pauseVideo(String videoId) async {
    try {
      final videoManager = this as IVideoManager;
      final controller = videoManager.getController(videoId);
      
      if (controller == null) return;

      await controller.pause();
      
      if (_currentlyPlayingVideoId == videoId) {
        _currentlyPlayingVideoId = null;
      }
      
      debugPrint('VideoControllerManager: Paused video $videoId');
      notifyListeners();

    } catch (e) {
      debugPrint('VideoControllerManager: Error pausing video $videoId: $e');
    }
  }

  /// Pause all currently playing videos
  Future<void> pauseAllVideos() async {
    if (_currentlyPlayingVideoId != null) {
      await pauseVideo(_currentlyPlayingVideoId!);
    }
    
    // Backup: pause any controller that might be playing
    final videoManager = this as IVideoManager;
    final allVideos = videoManager.videos;
    
    for (final video in allVideos) {
      final controller = videoManager.getController(video.id);
      if (controller?.value.isPlaying == true) {
        await controller!.pause();
      }
    }
    
    _currentlyPlayingVideoId = null;
    notifyListeners();
  }

  /// Resume the currently active video (for app lifecycle management)
  Future<void> resumeCurrentVideo() async {
    if (_currentlyPlayingVideoId != null) {
      await playVideo(_currentlyPlayingVideoId!);
    }
  }

  /// Set global mute state for all videos
  void setMuted(bool muted) {
    _isMuted = muted;
    
    // Apply to currently playing video immediately
    if (_currentlyPlayingVideoId != null) {
      final videoManager = this as IVideoManager;
      final controller = videoManager.getController(_currentlyPlayingVideoId!);
      controller?.setVolume(muted ? 0.0 : 1.0);
    }
    
    notifyListeners();
  }

  /// Set looping behavior for videos
  void setLooping(bool looping) {
    _isLooping = looping;
    
    // Apply to currently playing video immediately
    if (_currentlyPlayingVideoId != null) {
      final videoManager = this as IVideoManager;
      final controller = videoManager.getController(_currentlyPlayingVideoId!);
      controller?.setLooping(looping);
    }
    
    notifyListeners();
  }

  /// Get playback statistics for debugging
  Map<String, dynamic> getPlaybackStats() {
    return {
      'currentlyPlaying': _currentlyPlayingVideoId,
      'isMuted': _isMuted,
      'isLooping': _isLooping,
      'totalPlaysTracked': _playCount.values.fold(0, (sum, count) => sum + count),
      'uniqueVideosPlayed': _playCount.length,
      'lastPlayTimes': _lastPlayTime.map((key, value) => 
        MapEntry(key, value.toIso8601String())),
    };
  }

  /// Handle video completion (for analytics and next video logic)
  void onVideoCompleted(String videoId) {
    debugPrint('VideoControllerManager: Video $videoId completed');
    
    if (_currentlyPlayingVideoId == videoId) {
      // If looping is disabled, move to next video
      if (!_isLooping) {
        _currentlyPlayingVideoId = null;
        _tryPlayNextVideo(videoId);
      }
    }
  }

  /// Handle video errors during playback
  void onVideoError(String videoId, String error) {
    debugPrint('VideoControllerManager: Playback error for $videoId: $error');
    
    if (_currentlyPlayingVideoId == videoId) {
      _currentlyPlayingVideoId = null;
      notifyListeners();
    }
  }

  /// Clean up playback tracking when videos are disposed
  void onVideoDisposed(String videoId) {
    if (_currentlyPlayingVideoId == videoId) {
      _currentlyPlayingVideoId = null;
    }
    
    _lastPlayTime.remove(videoId);
    _playCount.remove(videoId);
  }

  // Private helper methods

  Future<void> _configureController(VideoPlayerController controller) async {
    try {
      // Set volume based on mute state
      await controller.setVolume(_isMuted ? 0.0 : 1.0);
      
      // Set looping behavior
      await controller.setLooping(_isLooping);
      
      // Seek to beginning if needed
      if (controller.value.position != Duration.zero) {
        await controller.seekTo(Duration.zero);
      }

    } catch (e) {
      debugPrint('VideoControllerManager: Error configuring controller: $e');
    }
  }

  void _trackPlayback(String videoId) {
    _lastPlayTime[videoId] = DateTime.now();
    _playCount[videoId] = (_playCount[videoId] ?? 0) + 1;
  }

  void _tryPlayNextVideo(String completedVideoId) {
    // Find next video in sequence and play it
    final videoManager = this as IVideoManager;
    final videos = videoManager.videos;
    
    final currentIndex = videos.indexWhere((v) => v.id == completedVideoId);
    if (currentIndex >= 0 && currentIndex < videos.length - 1) {
      final nextVideo = videos[currentIndex + 1];
      
      // Schedule next video playback
      Future.delayed(const Duration(milliseconds: 100), () {
        playVideo(nextVideo.id);
      });
    }
  }
}

/// Enhanced VideoManagerService with playback control
class VideoManagerServiceWithPlayback extends ChangeNotifier 
    implements IVideoManager {
  
  final IVideoManager _baseManager;
  
  VideoManagerServiceWithPlayback(this._baseManager);

  // Delegate all IVideoManager methods to base implementation
  @override
  List<VideoEvent> get videos => _baseManager.videos;

  @override
  List<VideoEvent> get readyVideos => _baseManager.readyVideos;

  @override
  VideoState? getVideoState(String videoId) => _baseManager.getVideoState(videoId);

  @override
  VideoPlayerController? getController(String videoId) => _baseManager.getController(videoId);

  @override
  Future<void> addVideoEvent(VideoEvent event) => _baseManager.addVideoEvent(event);

  @override
  Future<void> preloadVideo(String videoId) => _baseManager.preloadVideo(videoId);

  @override
  void preloadAroundIndex(int currentIndex, {int? preloadRange}) => 
      _baseManager.preloadAroundIndex(currentIndex, preloadRange: preloadRange);

  @override
  void disposeVideo(String videoId) {
    _baseManager.disposeVideo(videoId);
    _onVideoDisposed(videoId);
  }

  @override
  Map<String, dynamic> getDebugInfo() {
    final baseInfo = _baseManager.getDebugInfo();
    final playbackInfo = _getPlaybackStats();
    
    return {
      ...baseInfo,
      'playback': playbackInfo,
    };
  }

  @override
  Stream<void> get stateChanges => _baseManager.stateChanges;

  @override
  Future<void> handleMemoryPressure() async {
    await _baseManager.handleMemoryPressure();
    
    // Also pause all videos during memory pressure
    pauseAllVideos();
  }

  @override
  void dispose() {
    _baseManager.dispose();
    super.dispose();
  }

  // Playback control methods
  String? _currentlyPlayingVideoId;
  bool _isMuted = false;
  bool _isLooping = true;
  final Map<String, DateTime> _lastPlayTime = {};
  final Map<String, int> _playCount = {};

  String? get currentlyPlayingVideoId => _currentlyPlayingVideoId;
  bool get isMuted => _isMuted;
  bool get isLooping => _isLooping;

  Future<void> playVideo(String videoId) async {
    final controller = getController(videoId);
    if (controller == null) return;

    // Pause current video if different
    if (_currentlyPlayingVideoId != null && _currentlyPlayingVideoId != videoId) {
      pauseVideo(_currentlyPlayingVideoId!);
    }

    // Configure and play
    await controller.setVolume(_isMuted ? 0.0 : 1.0);
    await controller.setLooping(_isLooping);
    await controller.play();
    
    _currentlyPlayingVideoId = videoId;
    _trackPlayback(videoId);
    notifyListeners();
  }

  @override
  void pauseVideo(String videoId) {
    final controller = getController(videoId);
    if (controller == null) return;

    try {
      controller.pause();
      if (_currentlyPlayingVideoId == videoId) {
        _currentlyPlayingVideoId = null;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error pausing video $videoId: $e');
    }
  }

  @override
  void pauseAllVideos() {
    if (_currentlyPlayingVideoId != null) {
      pauseVideo(_currentlyPlayingVideoId!);
    }
  }

  @override
  void resumeVideo(String videoId) {
    final controller = getController(videoId);
    if (controller == null) return;

    try {
      controller.play();
      _currentlyPlayingVideoId = videoId;
      _trackPlayback(videoId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error resuming video $videoId: $e');
    }
  }

  void setMuted(bool muted) {
    _isMuted = muted;
    
    if (_currentlyPlayingVideoId != null) {
      final controller = getController(_currentlyPlayingVideoId!);
      controller?.setVolume(muted ? 0.0 : 1.0);
    }
    
    notifyListeners();
  }

  void setLooping(bool looping) {
    _isLooping = looping;
    
    if (_currentlyPlayingVideoId != null) {
      final controller = getController(_currentlyPlayingVideoId!);
      controller?.setLooping(looping);
    }
    
    notifyListeners();
  }

  void _trackPlayback(String videoId) {
    _lastPlayTime[videoId] = DateTime.now();
    _playCount[videoId] = (_playCount[videoId] ?? 0) + 1;
  }

  void _onVideoDisposed(String videoId) {
    if (_currentlyPlayingVideoId == videoId) {
      _currentlyPlayingVideoId = null;
    }
    _lastPlayTime.remove(videoId);
    _playCount.remove(videoId);
  }

  Map<String, dynamic> _getPlaybackStats() {
    return {
      'currentlyPlaying': _currentlyPlayingVideoId,
      'isMuted': _isMuted,
      'isLooping': _isLooping,
      'totalPlays': _playCount.values.fold(0, (sum, count) => sum + count),
      'uniqueVideosPlayed': _playCount.length,
    };
  }
}