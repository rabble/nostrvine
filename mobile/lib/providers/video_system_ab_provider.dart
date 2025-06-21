// ABOUTME: A/B testing integration provider for video system migration
// ABOUTME: Handles gradual rollout between legacy and new TDD video systems

import 'package:flutter/foundation.dart';
import '../services/ab_testing_service.dart';
import '../services/video_manager_interface.dart';
import '../models/video_event.dart';
import '../models/video_state.dart';
import 'package:video_player/video_player.dart';

/// Provider that bridges legacy and new video systems based on A/B testing
/// 
/// This provider allows gradual migration from legacy video architecture to
/// the new TDD-driven system by using A/B testing to determine which system
/// each user should use.
class VideoSystemABProvider extends ChangeNotifier {
  final ABTestingService _abTesting;
  final IVideoManager _newVideoManager;
  final bool _forceTreatment;
  
  // Current system state
  late final bool _useNewSystem;
  final String? _currentUserId;
  
  // Migration tracking
  DateTime? _systemSwitchTime;
  int _videoOperationsCount = 0;
  final Map<String, Duration> _operationTimes = {};
  
  VideoSystemABProvider({
    required ABTestingService abTesting,
    required IVideoManager newVideoManager,
    bool forceTreatment = false,
    String? userId,
  }) : _abTesting = abTesting,
       _newVideoManager = newVideoManager,
       _forceTreatment = forceTreatment,
       _currentUserId = userId {
    
    // Determine which system to use
    _useNewSystem = _forceTreatment || 
        _abTesting.isUserInTreatment('video_system_migration_v2', userId: userId);
    
    if (_useNewSystem) {
      _systemSwitchTime = DateTime.now();
      debugPrint('VideoSystemABProvider: Using NEW video system');
    } else {
      debugPrint('VideoSystemABProvider: Using LEGACY video system');
    }
    
    // Set up monitoring
    _setupPerformanceMonitoring();
  }
  
  /// Whether this user is using the new video system
  bool get isUsingNewSystem => _useNewSystem;
  
  /// Get videos list (delegates to appropriate system)
  List<VideoEvent> get videos {
    if (_useNewSystem) {
      _trackOperation('get_videos');
      return _newVideoManager.videos;
    } else {
      // Legacy system would be handled here
      // For now, return empty list as legacy system is being phased out
      return [];
    }
  }
  
  /// Get ready videos (delegates to appropriate system)
  List<VideoEvent> get readyVideos {
    if (_useNewSystem) {
      _trackOperation('get_ready_videos');
      return _newVideoManager.readyVideos;
    } else {
      return [];
    }
  }
  
  /// Get video state (delegates to appropriate system)
  VideoState? getVideoState(String videoId) {
    if (_useNewSystem) {
      _trackOperation('get_video_state');
      return _newVideoManager.getVideoState(videoId);
    } else {
      // Legacy system implementation would go here
      return null;
    }
  }
  
  /// Get video controller (delegates to appropriate system)
  VideoPlayerController? getController(String videoId) {
    if (_useNewSystem) {
      _trackOperation('get_controller');
      return _newVideoManager.getController(videoId);
    } else {
      // Legacy system implementation would go here
      return null;
    }
  }
  
  /// Add video event (delegates to appropriate system)
  Future<void> addVideoEvent(VideoEvent event) async {
    final startTime = DateTime.now();
    
    try {
      if (_useNewSystem) {
        await _newVideoManager.addVideoEvent(event);
        _trackOperationSuccess('add_video_event', DateTime.now().difference(startTime));
      } else {
        // Legacy system implementation would go here
        _trackOperationSuccess('add_video_event_legacy', DateTime.now().difference(startTime));
      }
      
      // Track conversion for successful video addition
      _abTesting.trackConversion(
        'video_system_migration_v2',
        'video_added',
        userId: _currentUserId,
        properties: {
          'video_id': event.id,
          'system': _useNewSystem ? 'new' : 'legacy',
        },
      );
      
    } catch (e) {
      _trackOperationFailure('add_video_event', DateTime.now().difference(startTime), e);
      rethrow;
    }
  }
  
  /// Preload video (delegates to appropriate system)
  Future<void> preloadVideo(String videoId) async {
    final startTime = DateTime.now();
    
    try {
      if (_useNewSystem) {
        await _newVideoManager.preloadVideo(videoId);
        _trackOperationSuccess('preload_video', DateTime.now().difference(startTime));
      } else {
        // Legacy system implementation would go here
        _trackOperationSuccess('preload_video_legacy', DateTime.now().difference(startTime));
      }
      
      // Track conversion for successful preload
      _abTesting.trackConversion(
        'video_system_migration_v2',
        'video_preloaded',
        userId: _currentUserId,
        properties: {
          'video_id': videoId,
          'system': _useNewSystem ? 'new' : 'legacy',
          'duration_ms': DateTime.now().difference(startTime).inMilliseconds,
        },
      );
      
    } catch (e) {
      _trackOperationFailure('preload_video', DateTime.now().difference(startTime), e);
      rethrow;
    }
  }
  
  /// Preload around index (delegates to appropriate system)
  void preloadAroundIndex(int currentIndex, {int? preloadRange}) {
    if (_useNewSystem) {
      _trackOperation('preload_around_index');
      _newVideoManager.preloadAroundIndex(currentIndex, preloadRange: preloadRange);
    } else {
      // Legacy system implementation would go here
    }
  }
  
  /// Dispose video (delegates to appropriate system)
  void disposeVideo(String videoId) {
    if (_useNewSystem) {
      _trackOperation('dispose_video');
      _newVideoManager.disposeVideo(videoId);
    } else {
      // Legacy system implementation would go here
    }
  }
  
  /// Handle memory pressure (delegates to appropriate system)
  Future<void> handleMemoryPressure() async {
    final startTime = DateTime.now();
    
    try {
      if (_useNewSystem) {
        await _newVideoManager.handleMemoryPressure();
        _trackOperationSuccess('handle_memory_pressure', DateTime.now().difference(startTime));
      } else {
        // Legacy system implementation would go here
        _trackOperationSuccess('handle_memory_pressure_legacy', DateTime.now().difference(startTime));
      }
      
      // Track memory pressure handling
      _abTesting.trackEvent(
        'video_system_migration_v2',
        'memory_pressure_handled',
        userId: _currentUserId,
        properties: {
          'system': _useNewSystem ? 'new' : 'legacy',
          'duration_ms': DateTime.now().difference(startTime).inMilliseconds,
        },
      );
      
    } catch (e) {
      _trackOperationFailure('handle_memory_pressure', DateTime.now().difference(startTime), e);
      rethrow;
    }
  }
  
  /// Get debug information (delegates to appropriate system)
  Map<String, dynamic> getDebugInfo() {
    if (_useNewSystem) {
      _trackOperation('get_debug_info');
      final debugInfo = _newVideoManager.getDebugInfo();
      
      // Add A/B testing metadata
      return {
        ...debugInfo,
        'ab_testing': {
          'experiment_id': 'video_system_migration_v2',
          'variant': 'treatment',
          'system_type': 'new_tdd_system',
          'switch_time': _systemSwitchTime?.toIso8601String(),
          'operations_count': _videoOperationsCount,
          'avg_operation_time_ms': _calculateAverageOperationTime(),
        },
      };
    } else {
      return {
        'ab_testing': {
          'experiment_id': 'video_system_migration_v2',
          'variant': 'control',
          'system_type': 'legacy_system',
          'operations_count': _videoOperationsCount,
        },
      };
    }
  }
  
  /// Get A/B testing results for the video system experiment
  Map<String, dynamic> getExperimentResults() {
    final results = _abTesting.getExperimentResults('video_system_migration_v2');
    
    return {
      'experiment_results': results.toJson(),
      'user_variant': _useNewSystem ? 'treatment' : 'control',
      'performance_metrics': {
        'operations_count': _videoOperationsCount,
        'avg_operation_time_ms': _calculateAverageOperationTime(),
        'operation_breakdown': Map.fromEntries(
          _operationTimes.entries.map((e) => MapEntry(e.key, e.value.inMilliseconds)),
        ),
      },
    };
  }
  
  /// Force switch to new system (for testing)
  void forceSwitchToNewSystem() {
    if (!_useNewSystem) {
      // This would require restarting the provider, so just log for now
      debugPrint('VideoSystemABProvider: Force switch requested - restart required');
      
      _abTesting.trackEvent(
        'video_system_migration_v2',
        'force_switch_requested',
        userId: _currentUserId,
        properties: {
          'from_system': 'legacy',
          'to_system': 'new',
        },
      );
    }
  }
  
  /// Track user engagement metrics
  void trackUserEngagement(Map<String, dynamic> engagementMetrics) {
    _abTesting.trackEvent(
      'video_system_migration_v2',
      'user_engagement',
      userId: _currentUserId,
      properties: {
        'system': _useNewSystem ? 'new' : 'legacy',
        ...engagementMetrics,
      },
    );
  }
  
  /// Stream of state changes
  Stream<void> get stateChanges {
    if (_useNewSystem) {
      return _newVideoManager.stateChanges;
    } else {
      // Return empty stream for legacy system
      return const Stream.empty();
    }
  }
  
  @override
  void dispose() {
    // Track session end
    if (_systemSwitchTime != null) {
      final sessionDuration = DateTime.now().difference(_systemSwitchTime!);
      
      _abTesting.trackEvent(
        'video_system_migration_v2',
        'session_ended',
        userId: _currentUserId,
        properties: {
          'system': _useNewSystem ? 'new' : 'legacy',
          'session_duration_minutes': sessionDuration.inMinutes,
          'operations_count': _videoOperationsCount,
          'avg_operation_time_ms': _calculateAverageOperationTime(),
        },
      );
    }
    
    super.dispose();
  }
  
  // Private methods
  
  void _setupPerformanceMonitoring() {
    // Monitor state changes if using new system
    if (_useNewSystem) {
      _newVideoManager.stateChanges.listen((_) {
        notifyListeners();
      });
    }
  }
  
  void _trackOperation(String operationName) {
    _videoOperationsCount++;
    
    _abTesting.trackEvent(
      'video_system_migration_v2',
      'operation',
      userId: _currentUserId,
      properties: {
        'operation': operationName,
        'system': _useNewSystem ? 'new' : 'legacy',
      },
    );
  }
  
  void _trackOperationSuccess(String operationName, Duration duration) {
    _operationTimes[operationName] = duration;
    
    _abTesting.trackEvent(
      'video_system_migration_v2',
      'operation_success',
      userId: _currentUserId,
      properties: {
        'operation': operationName,
        'system': _useNewSystem ? 'new' : 'legacy',
        'duration_ms': duration.inMilliseconds,
      },
    );
  }
  
  void _trackOperationFailure(String operationName, Duration duration, dynamic error) {
    _abTesting.trackEvent(
      'video_system_migration_v2',
      'operation_failure',
      userId: _currentUserId,
      properties: {
        'operation': operationName,
        'system': _useNewSystem ? 'new' : 'legacy',
        'duration_ms': duration.inMilliseconds,
        'error': error.toString(),
      },
    );
  }
  
  double _calculateAverageOperationTime() {
    if (_operationTimes.isEmpty) return 0.0;
    
    final totalMs = _operationTimes.values
        .fold(0, (sum, duration) => sum + duration.inMilliseconds);
    
    return totalMs / _operationTimes.length;
  }
}

/// Factory for creating VideoSystemABProvider with dependencies
class VideoSystemABProviderFactory {
  static VideoSystemABProvider create({
    required ABTestingService abTesting,
    required IVideoManager newVideoManager,
    String? userId,
    bool forceTreatment = false,
  }) {
    return VideoSystemABProvider(
      abTesting: abTesting,
      newVideoManager: newVideoManager,
      userId: userId,
      forceTreatment: forceTreatment,
    );
  }
  
  /// Create provider for testing with forced treatment
  static VideoSystemABProvider createForTesting({
    required IVideoManager newVideoManager,
  }) {
    return VideoSystemABProvider(
      abTesting: ABTestingService.instance,
      newVideoManager: newVideoManager,
      forceTreatment: true,
      userId: 'test-user',
    );
  }
}