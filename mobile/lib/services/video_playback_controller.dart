// ABOUTME: Consolidated video playback controller with common patterns and best practices
// ABOUTME: Reusable controller for consistent video behavior across different UI contexts

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';
import '../models/video_event.dart';
import '../utils/unified_logger.dart';

/// Configuration for video playback behavior
class VideoPlaybackConfig {
  final bool autoPlay;
  final bool looping;
  final double volume;
  final bool pauseOnNavigation;
  final bool resumeOnReturn;
  final bool handleAppLifecycle;
  final Duration retryDelay;
  final int maxRetries;

  const VideoPlaybackConfig({
    this.autoPlay = true,
    this.looping = true,
    this.volume = 0.0, // Default muted for feed videos
    this.pauseOnNavigation = true,
    this.resumeOnReturn = true,
    this.handleAppLifecycle = true,
    this.retryDelay = const Duration(seconds: 2),
    this.maxRetries = 3,
  });

  /// Configuration for feed videos (muted, auto-play)
  static const VideoPlaybackConfig feed = VideoPlaybackConfig(
    autoPlay: true,
    looping: true,
    volume: 0.0,
    pauseOnNavigation: true,
    resumeOnReturn: true,
  );

  /// Configuration for fullscreen videos (with audio)
  static const VideoPlaybackConfig fullscreen = VideoPlaybackConfig(
    autoPlay: true,
    looping: true,
    volume: 1.0,
    pauseOnNavigation: true,
    resumeOnReturn: true,
  );

  /// Configuration for preview videos (no auto-play)
  static const VideoPlaybackConfig preview = VideoPlaybackConfig(
    autoPlay: false,
    looping: false,
    volume: 0.0,
    pauseOnNavigation: false,
    resumeOnReturn: false,
    handleAppLifecycle: false,
  );
}

/// State of video playback
enum VideoPlaybackState {
  notInitialized,
  initializing,
  ready,
  playing,
  paused,
  buffering,
  error,
  disposed,
}

/// Video playback events
abstract class VideoPlaybackEvent {}

class VideoStateChanged extends VideoPlaybackEvent {
  final VideoPlaybackState state;
  VideoStateChanged(this.state);
}

class VideoError extends VideoPlaybackEvent {
  final String message;
  final dynamic error;
  VideoError(this.message, this.error);
}

class VideoPositionChanged extends VideoPlaybackEvent {
  final Duration position;
  final Duration duration;
  VideoPositionChanged(this.position, this.duration);
}

/// Consolidated video playback controller with best practices
class VideoPlaybackController extends ChangeNotifier with WidgetsBindingObserver {
  final VideoEvent video;
  final VideoPlaybackConfig config;

  VideoPlayerController? _controller;
  VideoPlaybackState _state = VideoPlaybackState.notInitialized;
  String? _errorMessage;
  int _retryCount = 0;
  bool _isActive = false;
  bool _wasPlayingBeforeNavigation = false;
  Timer? _positionTimer;
  
  final StreamController<VideoPlaybackEvent> _eventController = 
      StreamController<VideoPlaybackEvent>.broadcast();

  VideoPlaybackController({
    required this.video,
    this.config = VideoPlaybackConfig.feed,
  }) {
    if (config.handleAppLifecycle) {
      WidgetsBinding.instance.addObserver(this);
    }
  }

  // Getters
  VideoPlayerController? get controller => _controller;
  VideoPlaybackState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isInitialized => _controller?.value.isInitialized ?? false;
  bool get isPlaying => _controller?.value.isPlaying ?? false;
  bool get hasError => _state == VideoPlaybackState.error;
  bool get isActive => _isActive;
  Duration get position => _controller?.value.position ?? Duration.zero;
  Duration get duration => _controller?.value.duration ?? Duration.zero;
  double get aspectRatio => _controller?.value.aspectRatio ?? 16/9;
  Stream<VideoPlaybackEvent> get events => _eventController.stream;

  /// Initialize the video controller
  Future<void> initialize() async {
    if (_state != VideoPlaybackState.notInitialized) {
      return;
    }

    _setState(VideoPlaybackState.initializing);
    _errorMessage = null;

    try {
      final videoUrl = video.videoUrl;
      if (videoUrl == null) {
        throw Exception('Video URL is null');
      }
      
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
      );

      // Configure controller
      await _controller!.initialize();
      await _controller!.setLooping(config.looping);
      await _controller!.setVolume(config.volume);

      // Add listeners
      _controller!.addListener(_onControllerUpdate);

      _setState(VideoPlaybackState.ready);
      
      // Auto-play if configured and active
      if (config.autoPlay && _isActive) {
        await play();
      }

      UnifiedLogger.info('Initialized video: ${video.id.substring(0, 8)}...', 
          name: 'VideoPlaybackController');

    } catch (e) {
      _handleError('Failed to initialize video', e);
    }
  }

  /// Play the video with safety checks
  Future<void> play() async {
    if (!_canPlay()) {
      return;
    }

    try {
      await _controller!.play();
      _setState(VideoPlaybackState.playing);
      _startPositionTimer();
      
      UnifiedLogger.debug('Playing video: ${video.id.substring(0, 8)}...', 
          name: 'VideoPlaybackController');
          
    } catch (e) {
      _handleError('Failed to play video', e);
    }
  }

  /// Pause the video with safety checks
  Future<void> pause() async {
    if (!_canPause()) {
      return;
    }

    try {
      await _controller!.pause();
      _setState(VideoPlaybackState.paused);
      _stopPositionTimer();
      
      UnifiedLogger.debug('Paused video: ${video.id.substring(0, 8)}...', 
          name: 'VideoPlaybackController');
          
    } catch (e) {
      _handleError('Failed to pause video', e);
    }
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  /// Seek to specific position
  Future<void> seekTo(Duration position) async {
    if (!_canSeek()) {
      return;
    }

    try {
      await _controller!.seekTo(position);
      _emitEvent(VideoPositionChanged(position, duration));
    } catch (e) {
      _handleError('Failed to seek video', e);
    }
  }

  /// Set video volume
  Future<void> setVolume(double volume) async {
    if (_controller?.value.isInitialized ?? false) {
      try {
        await _controller!.setVolume(volume);
      } catch (e) {
        UnifiedLogger.warning('Failed to set volume: $e', 
            name: 'VideoPlaybackController');
      }
    }
  }

  /// Set active state (for feed videos)
  void setActive(bool active) {
    if (_isActive == active) return;
    
    _isActive = active;
    
    if (active) {
      if (_state == VideoPlaybackState.ready && config.autoPlay) {
        play();
      }
    } else {
      if (isPlaying) {
        pause();
      }
    }
  }

  /// Handle navigation away (pause if configured)
  Future<void> onNavigationAway() async {
    if (!config.pauseOnNavigation) return;
    
    _wasPlayingBeforeNavigation = isPlaying;
    if (_wasPlayingBeforeNavigation) {
      await pause();
    }
  }

  /// Handle navigation return (resume if configured)
  Future<void> onNavigationReturn() async {
    if (!config.resumeOnReturn) return;
    
    if (_wasPlayingBeforeNavigation && _isActive) {
      await play();
    }
    _wasPlayingBeforeNavigation = false;
  }

  /// Retry video initialization after error
  Future<void> retry() async {
    if (_retryCount >= config.maxRetries) {
      UnifiedLogger.warning('Max retries reached for video: ${video.id.substring(0, 8)}...', 
          name: 'VideoPlaybackController');
      return;
    }

    _retryCount++;
    UnifiedLogger.info('Retrying video (attempt $_retryCount): ${video.id.substring(0, 8)}...', 
        name: 'VideoPlaybackController');

    // Clean up current controller
    await _disposeController();
    
    // Wait before retrying
    await Future.delayed(config.retryDelay);
    
    // Reset state and retry
    _state = VideoPlaybackState.notInitialized;
    await initialize();
  }

  /// Navigation helper for consistent pause/resume behavior
  Future<T?> navigateWithPause<T>(Future<T?> Function() navigation) async {
    await onNavigationAway();
    try {
      final result = await navigation();
      await onNavigationReturn();
      return result;
    } catch (e) {
      await onNavigationReturn();
      rethrow;
    }
  }

  // Private methods

  bool _canPlay() {
    return _controller != null && 
           _controller!.value.isInitialized && 
           !_controller!.value.hasError &&
           _state != VideoPlaybackState.disposed;
  }

  bool _canPause() {
    return _controller != null && 
           _controller!.value.isInitialized && 
           _controller!.value.isPlaying;
  }

  bool _canSeek() {
    return _controller != null && 
           _controller!.value.isInitialized && 
           !_controller!.value.hasError;
  }

  void _setState(VideoPlaybackState newState) {
    if (_state != newState) {
      _state = newState;
      _emitEvent(VideoStateChanged(newState));
      notifyListeners();
    }
  }

  void _handleError(String message, dynamic error) {
    _errorMessage = message;
    _setState(VideoPlaybackState.error);
    _emitEvent(VideoError(message, error));
    
    UnifiedLogger.error('$message: $error (Video: ${video.id.substring(0, 8)}...)', 
        name: 'VideoPlaybackController', error: error);
  }

  void _emitEvent(VideoPlaybackEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  void _onControllerUpdate() {
    if (_controller == null) return;

    final value = _controller!.value;
    
    // Handle state changes
    if (value.hasError) {
      _handleError('Video player error', value.errorDescription);
    } else if (value.isBuffering) {
      _setState(VideoPlaybackState.buffering);
    } else if (value.isPlaying) {
      _setState(VideoPlaybackState.playing);
    } else if (value.isInitialized) {
      _setState(VideoPlaybackState.paused);
    }
  }

  void _startPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_controller?.value.isInitialized ?? false) {
        _emitEvent(VideoPositionChanged(position, duration));
      }
    });
  }

  void _stopPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }

  Future<void> _disposeController() async {
    _stopPositionTimer();
    
    if (_controller != null) {
      _controller!.removeListener(_onControllerUpdate);
      await _controller!.dispose();
      _controller = null;
    }
  }

  // App lifecycle handling
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!config.handleAppLifecycle) return;
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        if (isPlaying) {
          pause();
        }
        break;
      case AppLifecycleState.resumed:
        if (_isActive && _state == VideoPlaybackState.paused) {
          play();
        }
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void dispose() {
    UnifiedLogger.debug('Disposing controller for video: ${video.id.substring(0, 8)}...', 
        name: 'VideoPlaybackController');
        
    _setState(VideoPlaybackState.disposed);
    
    if (config.handleAppLifecycle) {
      WidgetsBinding.instance.removeObserver(this);
    }
    
    _disposeController();
    _eventController.close();
    
    super.dispose();
  }
}

/// Helper extension for VideoPlayerController integration
extension VideoPlayerControllerExtension on VideoPlayerController {
  /// Create VideoPlaybackController from existing controller
  static VideoPlaybackController fromController(
    VideoPlayerController controller,
    VideoEvent video, {
    VideoPlaybackConfig config = VideoPlaybackConfig.feed,
  }) {
    final playbackController = VideoPlaybackController(
      video: video,
      config: config,
    );
    playbackController._controller = controller;
    playbackController._setState(VideoPlaybackState.ready);
    return playbackController;
  }
}