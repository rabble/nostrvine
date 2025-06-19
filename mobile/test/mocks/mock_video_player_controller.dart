// ABOUTME: Mock video player controller for testing video system without real video dependencies
// ABOUTME: Simulates VideoPlayerController behavior for TDD tests

import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

/// Mock implementation of VideoPlayerController for testing
/// 
/// Provides controllable behavior that simulates real video player
/// functionality without requiring actual video files or network access.
class MockVideoPlayerController extends VideoPlayerController.networkUrl {
  static const String _defaultMockUrl = 'https://mock-video.com/test.mp4';
  
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isLooping = false;
  bool _isDisposed = false;
  Duration _position = Duration.zero;
  Duration _duration = const Duration(seconds: 30);
  Size _size = const Size(1920, 1080);
  
  // Test control flags
  bool _shouldFailInitialization = false;
  Duration _initializationDelay = Duration.zero;
  
  MockVideoPlayerController({String? url}) 
      : super(Uri.parse(url ?? _defaultMockUrl));
  
  @override
  Future<void> initialize() async {
    if (_isDisposed) {
      throw PlatformException(
        code: 'VideoError',
        message: 'Video controller is disposed',
      );
    }
    
    // Simulate initialization delay
    if (_initializationDelay > Duration.zero) {
      await Future.delayed(_initializationDelay);
    }
    
    // Simulate initialization failure
    if (_shouldFailInitialization) {
      throw PlatformException(
        code: 'VideoError',
        message: 'Mock initialization failure',
      );
    }
    
    _isInitialized = true;
    
    // Update value to reflect initialized state
    value = value.copyWith(
      isInitialized: true,
      duration: _duration,
      size: _size,
      position: _position,
      isPlaying: _isPlaying,
      isLooping: _isLooping,
    );
  }
  
  @override
  Future<void> play() async {
    _ensureNotDisposed();
    _ensureInitialized();
    
    _isPlaying = true;
    value = value.copyWith(isPlaying: true);
  }
  
  @override
  Future<void> pause() async {
    _ensureNotDisposed();
    _ensureInitialized();
    
    _isPlaying = false;
    value = value.copyWith(isPlaying: false);
  }
  
  @override
  Future<void> setLooping(bool looping) async {
    _ensureNotDisposed();
    _ensureInitialized();
    
    _isLooping = looping;
    value = value.copyWith(isLooping: looping);
  }
  
  @override
  Future<void> seekTo(Duration position) async {
    _ensureNotDisposed();
    _ensureInitialized();
    
    _position = position.clamp(Duration.zero, _duration);
    value = value.copyWith(position: _position);
  }
  
  @override
  Future<void> setVolume(double volume) async {
    _ensureNotDisposed();
    _ensureInitialized();
    
    value = value.copyWith(volume: volume.clamp(0.0, 1.0));
  }
  
  @override
  Future<void> setPlaybackSpeed(double speed) async {
    _ensureNotDisposed();
    _ensureInitialized();
    
    value = value.copyWith(playbackSpeed: speed);
  }
  
  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    
    _isDisposed = true;
    _isInitialized = false;
    _isPlaying = false;
    
    await super.dispose();
  }
  
  // Test control methods
  
  /// Control whether initialization should fail
  void setFailInitialization(bool shouldFail) {
    _shouldFailInitialization = shouldFail;
  }
  
  /// Set artificial delay for initialization
  void setInitializationDelay(Duration delay) {
    _initializationDelay = delay;
  }
  
  /// Set mock video duration
  void setDuration(Duration duration) {
    _duration = duration;
    if (_isInitialized) {
      value = value.copyWith(duration: duration);
    }
  }
  
  /// Set mock video size
  void setSize(Size size) {
    _size = size;
    if (_isInitialized) {
      value = value.copyWith(size: size);
    }
  }
  
  /// Simulate playback progress
  void simulatePlayback({required Duration position}) {
    if (_isInitialized && !_isDisposed) {
      _position = position.clamp(Duration.zero, _duration);
      value = value.copyWith(position: _position);
    }
  }
  
  /// Simulate an error during playback
  void simulateError(String errorDescription) {
    if (!_isDisposed) {
      value = value.copyWith(
        hasError: true,
        errorDescription: errorDescription,
      );
    }
  }
  
  /// Check if controller is in a valid state
  bool get isValid => !_isDisposed && _isInitialized;
  
  // Private helper methods
  
  void _ensureNotDisposed() {
    if (_isDisposed) {
      throw PlatformException(
        code: 'VideoError',
        message: 'Video controller is disposed',
      );
    }
  }
  
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw PlatformException(
        code: 'VideoError',
        message: 'Video controller is not initialized',
      );
    }
  }
}

/// Factory for creating MockVideoPlayerController instances
/// 
/// Provides convenient methods for creating controllers with
/// specific test configurations.
class MockVideoPlayerControllerFactory {
  /// Create a controller that initializes successfully
  static MockVideoPlayerController createWorking({
    String? url,
    Duration duration = const Duration(seconds: 30),
    Size size = const Size(1920, 1080),
  }) {
    final controller = MockVideoPlayerController(url: url);
    controller.setDuration(duration);
    controller.setSize(size);
    return controller;
  }
  
  /// Create a controller that fails to initialize
  static MockVideoPlayerController createFailing({
    String? url,
    Duration delay = Duration.zero,
  }) {
    final controller = MockVideoPlayerController(url: url);
    controller.setFailInitialization(true);
    controller.setInitializationDelay(delay);
    return controller;
  }
  
  /// Create a controller with slow initialization
  static MockVideoPlayerController createSlow({
    String? url,
    Duration delay = const Duration(seconds: 2),
  }) {
    final controller = MockVideoPlayerController(url: url);
    controller.setInitializationDelay(delay);
    return controller;
  }
  
  /// Create a controller for a GIF (usually no initialization needed)
  static MockVideoPlayerController createForGif({
    String? url,
  }) {
    final controller = MockVideoPlayerController(url: url ?? 'https://example.com/test.gif');
    controller.setDuration(Duration.zero); // GIFs typically don't have duration
    return controller;
  }
}