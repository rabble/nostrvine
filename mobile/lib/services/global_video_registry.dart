// ABOUTME: Singleton registry for tracking all video controllers across the app
// ABOUTME: Provides centralized control to ensure only one video plays at a time

import 'package:video_player/video_player.dart';
import '../utils/unified_logger.dart';

/// Global singleton registry for all video controllers in the app
/// 
/// This registry tracks both managed (VideoManager) and unmanaged 
/// (direct VideoPlayerController) instances to ensure proper video
/// lifecycle management and prevent multiple simultaneous playbacks.
/// 
/// Usage:
/// ```dart
/// // Register a controller
/// GlobalVideoRegistry().registerController(controller);
/// 
/// // Pause all videos
/// GlobalVideoRegistry().pauseAllControllers();
/// 
/// // Pause all except one
/// GlobalVideoRegistry().pauseAllExcept(activeController);
/// 
/// // Unregister when disposing
/// GlobalVideoRegistry().unregisterController(controller);
/// ```
class GlobalVideoRegistry {
  static GlobalVideoRegistry? _instance;
  
  /// Get the singleton instance
  factory GlobalVideoRegistry() {
    _instance ??= GlobalVideoRegistry._internal();
    return _instance!;
  }
  
  GlobalVideoRegistry._internal();
  
  /// Reset the singleton (for testing only)
  static void resetForTesting() {
    _instance = null;
  }
  
  /// Set of all active video controllers
  final Set<VideoPlayerController> _activeControllers = {};
  
  /// Register a video controller with the global registry
  void registerController(VideoPlayerController controller) {
    if (_activeControllers.add(controller)) {
      Log.debug('📹 Registered video controller. Total: ${_activeControllers.length}', 
          name: 'GlobalVideoRegistry', category: LogCategory.video);
    }
  }
  
  /// Unregister a video controller from the global registry
  void unregisterController(VideoPlayerController controller) {
    if (_activeControllers.remove(controller)) {
      Log.debug('📹 Unregistered video controller. Remaining: ${_activeControllers.length}', 
          name: 'GlobalVideoRegistry', category: LogCategory.video);
    }
  }
  
  /// Pause all registered video controllers
  void pauseAllControllers() {
    Log.debug('🎬 pauseAllControllers called with ${_activeControllers.length} controllers', 
        name: 'GlobalVideoRegistry', category: LogCategory.video);
    
    int pausedCount = 0;
    int playingCount = 0;
    
    for (final controller in _activeControllers) {
      try {
        if (controller.value.isInitialized) {
          if (controller.value.isPlaying) {
            playingCount++;
            Log.debug('  - Pausing controller (playing: ${controller.value.isPlaying}, position: ${controller.value.position})', 
                name: 'GlobalVideoRegistry', category: LogCategory.video);
            controller.pause();
            pausedCount++;
          } else {
            Log.debug('  - Controller already paused', 
                name: 'GlobalVideoRegistry', category: LogCategory.video);
          }
        } else {
          Log.debug('  - Controller not initialized', 
              name: 'GlobalVideoRegistry', category: LogCategory.video);
        }
      } catch (e) {
        Log.warning('Failed to pause controller: $e', 
            name: 'GlobalVideoRegistry', category: LogCategory.video);
      }
    }
    
    Log.info('⏸️ Paused $pausedCount of $playingCount playing video(s) from ${_activeControllers.length} total', 
        name: 'GlobalVideoRegistry', category: LogCategory.video);
  }
  
  /// Pause all controllers except the specified one
  void pauseAllExcept(VideoPlayerController? exceptController) {
    if (exceptController == null) {
      pauseAllControllers();
      return;
    }
    
    Log.debug('🎬 pauseAllExcept called with ${_activeControllers.length} controllers', 
        name: 'GlobalVideoRegistry', category: LogCategory.video);
    
    int pausedCount = 0;
    int skippedCount = 0;
    int playingCount = 0;
    
    for (final controller in _activeControllers) {
      if (controller == exceptController) {
        skippedCount++;
        Log.debug('  - Skipping exception controller', 
            name: 'GlobalVideoRegistry', category: LogCategory.video);
        continue;
      }
      
      try {
        if (controller.value.isInitialized) {
          if (controller.value.isPlaying) {
            playingCount++;
            Log.debug('  - Pausing controller (playing: ${controller.value.isPlaying})', 
                name: 'GlobalVideoRegistry', category: LogCategory.video);
            controller.pause();
            pausedCount++;
          }
        }
      } catch (e) {
        Log.warning('Failed to pause controller: $e', 
            name: 'GlobalVideoRegistry', category: LogCategory.video);
      }
    }
    
    Log.info('⏸️ Paused $pausedCount of $playingCount playing video(s), skipped $skippedCount', 
        name: 'GlobalVideoRegistry', category: LogCategory.video);
  }
  
  /// Get the number of active controllers
  int get activeControllerCount => _activeControllers.length;
  
  /// Get a copy of active controllers (for testing/debugging)
  List<VideoPlayerController> get activeControllers => 
      List.unmodifiable(_activeControllers);
  
  /// Clean up any disposed controllers
  void cleanupDisposedControllers() {
    final disposedControllers = <VideoPlayerController>[];
    
    for (final controller in _activeControllers) {
      try {
        // Check if controller is disposed by trying to access its value
        // This is a bit hacky but VideoPlayerController doesn't expose disposal state
        final _ = controller.value;
      } catch (e) {
        disposedControllers.add(controller);
      }
    }
    
    for (final controller in disposedControllers) {
      _activeControllers.remove(controller);
    }
    
    if (disposedControllers.isNotEmpty) {
      Log.debug('🧹 Cleaned up ${disposedControllers.length} disposed controller(s)', 
          name: 'GlobalVideoRegistry', category: LogCategory.video);
    }
  }
  
  /// Get debug information about the registry state
  Map<String, dynamic> getDebugInfo() {
    int playingCount = 0;
    int pausedCount = 0;
    
    for (final controller in _activeControllers) {
      try {
        if (controller.value.isInitialized) {
          if (controller.value.isPlaying) {
            playingCount++;
          } else {
            pausedCount++;
          }
        }
      } catch (e) {
        // Controller might be disposed
      }
    }
    
    return {
      'totalControllers': _activeControllers.length,
      'playingControllers': playingCount,
      'pausedControllers': pausedCount,
    };
  }
}