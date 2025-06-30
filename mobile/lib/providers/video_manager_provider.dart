// ABOUTME: Provider wrapper for VideoManagerService integration with existing Flutter architecture
// ABOUTME: Bridges new TDD video system with existing Provider-based state management

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../models/video_event.dart';
import '../models/video_state.dart';
import '../services/video_manager_interface.dart';
import '../services/video_manager_service.dart';
import '../services/video_controller_manager.dart';
import '../services/nostr_video_bridge.dart';
import '../services/circuit_breaker_service.dart';
import '../services/nostr_service_interface.dart';
import '../services/seen_videos_service.dart';
import '../services/connection_status_service.dart';
import '../services/subscription_manager.dart';
import '../utils/unified_logger.dart';

/// Provider wrapper for the TDD VideoManager system
/// 
/// This class integrates the new VideoManager with the existing Provider architecture
/// while maintaining backward compatibility and providing migration path.
class VideoManagerProvider extends ChangeNotifier {
  late final VideoManagerServiceWithPlayback _videoManager;
  late final NostrVideoBridge _nostrBridge;
  late final VideoCircuitBreaker _circuitBreaker;
  
  // Migration state - helps transition from old to new system
  bool _isMigrationMode = true;
  bool _isInitialized = false;
  String? _initializationError;
  
  // Statistics tracking
  int _totalVideosProcessed = 0;
  int _memoryCleanupCount = 0;
  DateTime? _lastUpdate;

  VideoManagerProvider({
    required INostrService nostrService,
    SeenVideosService? seenVideosService,
    ConnectionStatusService? connectionService,
    VideoManagerConfig? config,
  }) {
    _initializeServices(
      nostrService: nostrService,
      seenVideosService: seenVideosService,
      connectionService: connectionService,
      config: config,
    );
  }

  // Public getters - maintain compatibility with existing code
  
  /// List of videos for display (replaces old VideoFeedProvider.videoEvents)
  List<VideoEvent> get videos => _isInitialized ? _videoManager.videos : [];
  
  /// Videos ready for immediate playback
  List<VideoEvent> get readyVideos => _isInitialized ? _videoManager.readyVideos : [];
  
  /// Whether system is loading
  bool get isLoading => !_isInitialized || _nostrBridge.processingStats['isActive'] != true;
  
  /// Current error state
  String? get error => _initializationError;
  
  /// Whether system has video events
  bool get hasEvents => videos.isNotEmpty;
  
  /// Total number of events
  int get eventCount => videos.length;
  
  /// Migration mode status (for gradual rollout)
  bool get isMigrationMode => _isMigrationMode;
  
  /// Whether system is fully initialized
  bool get isInitialized => _isInitialized;
  
  /// Current memory usage estimate
  int get estimatedMemoryMB => _isInitialized ? 
    (_videoManager.getDebugInfo()['estimatedMemoryMB'] as int? ?? 0) : 0;

  // Video management methods

  /// Get state of a specific video
  VideoState? getVideoState(String videoId) {
    return _isInitialized ? _videoManager.getVideoState(videoId) : null;
  }

  /// Manually add video event (for compatibility)
  Future<void> addVideoEvent(VideoEvent event) async {
    if (!_isInitialized) return;
    
    try {
      await _videoManager.addVideoEvent(event);
      _totalVideosProcessed++;
      _lastUpdate = DateTime.now();
      notifyListeners();
    } catch (e) {
      Log.error('VideoManagerProvider: Error adding video: $e', name: 'VideoManagerProvider', category: LogCategory.ui);
    }
  }

  /// Preload video around current position
  void preloadAroundIndex(int index) {
    if (!_isInitialized) return;
    _videoManager.preloadAroundIndex(index);
  }

  /// Start Nostr video subscription
  Future<void> startVideoSubscription({
    List<String>? authors,
    List<String>? hashtags,
    int? since,
    int? until,
    int limit = 500,
  }) async {
    if (!_isInitialized) {
      Log.info('VideoManagerProvider: Cannot start subscription - not initialized', name: 'VideoManagerProvider', category: LogCategory.ui);
      return;
    }

    try {
      await _nostrBridge.start(
        authors: authors,
        hashtags: hashtags,
        since: since,
        until: until,
        limit: limit,
      );
      
      notifyListeners();
    } catch (e) {
      _initializationError = 'Failed to start video subscription: $e';
      Log.debug('VideoManagerProvider: $e', name: 'VideoManagerProvider', category: LogCategory.ui);
      notifyListeners();
    }
  }

  /// Stop video subscription
  Future<void> stopVideoSubscription() async {
    if (!_isInitialized) return;
    
    await _nostrBridge.stop();
    notifyListeners();
  }

  /// Restart subscription (useful for network recovery)
  Future<void> restartVideoSubscription() async {
    if (!_isInitialized) return;
    
    await _nostrBridge.restart();
    notifyListeners();
  }

  // Playback control methods

  /// Play specific video
  Future<void> playVideo(String videoId) async {
    if (!_isInitialized) return;
    await _videoManager.playVideo(videoId);
  }

  /// Pause specific video
  void pauseVideo(String videoId) {
    if (!_isInitialized) return;
    _videoManager.pauseVideo(videoId);
  }

  /// Pause all videos
  void pauseAllVideos() {
    if (!_isInitialized) return;
    _videoManager.pauseAllVideos();
  }

  /// Set global mute state
  void setMuted(bool muted) {
    if (!_isInitialized) return;
    _videoManager.setMuted(muted);
  }

  /// Set video looping
  void setLooping(bool looping) {
    if (!_isInitialized) return;
    _videoManager.setLooping(looping);
  }

  /// Get currently playing video ID
  String? get currentlyPlayingVideoId => 
    _isInitialized ? _videoManager.currentlyPlayingVideoId : null;

  /// Whether videos are muted
  bool get isMuted => _isInitialized ? _videoManager.isMuted : false;

  /// Whether videos loop
  bool get isLooping => _isInitialized ? _videoManager.isLooping : true;

  // Memory and performance management

  /// Handle system memory pressure
  Future<void> handleMemoryPressure() async {
    if (!_isInitialized) return;
    
    await _videoManager.handleMemoryPressure();
    _memoryCleanupCount++;
    notifyListeners();
  }

  /// Force memory cleanup
  void performMemoryCleanup() {
    if (!_isInitialized) return;
    
    // Aggressive cleanup beyond current position
    final videos = _videoManager.videos;
    for (int i = 3; i < videos.length; i++) {
      _videoManager.disposeVideo(videos[i].id);
    }
    
    _memoryCleanupCount++;
    notifyListeners();
  }

  // Migration helpers

  /// Enable/disable migration mode
  void setMigrationMode(bool enabled) {
    if (_isMigrationMode != enabled) {
      _isMigrationMode = enabled;
      debugPrint('VideoManagerProvider: Migration mode ${enabled ? 'enabled' : 'disabled'}');
      notifyListeners();
    }
  }

  /// Get migration status and recommendations
  Map<String, dynamic> getMigrationStatus() {
    return {
      'migrationMode': _isMigrationMode,
      'initialized': _isInitialized,
      'videosManaged': videos.length,
      'memoryUsage': estimatedMemoryMB,
      'performanceGood': estimatedMemoryMB < 500,
      'recommendFullMigration': _isInitialized && estimatedMemoryMB < 300,
    };
  }

  // Debug and monitoring

  /// Get comprehensive debug information
  Map<String, dynamic> getDebugInfo() {
    if (!_isInitialized) {
      return {
        'initialized': false,
        'error': _initializationError,
      };
    }

    final videoManagerDebug = _videoManager.getDebugInfo();
    final bridgeDebug = _nostrBridge.getDebugInfo();
    final circuitBreakerDebug = _circuitBreaker.getStats();

    return {
      'provider': {
        'initialized': _isInitialized,
        'migrationMode': _isMigrationMode,
        'totalVideosProcessed': _totalVideosProcessed,
        'memoryCleanupCount': _memoryCleanupCount,
        'lastUpdate': _lastUpdate?.toIso8601String(),
      },
      'videoManager': videoManagerDebug,
      'nostrBridge': bridgeDebug,
      'circuitBreaker': circuitBreakerDebug,
    };
  }

  /// Get provider statistics for monitoring
  Map<String, dynamic> getProviderStats() {
    return {
      'initialized': _isInitialized,
      'migrationMode': _isMigrationMode,
      'videosManaged': videos.length,
      'readyVideos': readyVideos.length,
      'memoryUsageMB': estimatedMemoryMB,
      'isLoading': isLoading,
      'hasError': error != null,
      'totalProcessed': _totalVideosProcessed,
      'lastUpdate': _lastUpdate?.toIso8601String(),
    };
  }

  @override
  void dispose() {
    _nostrBridge.dispose();
    _circuitBreaker.dispose();
    _videoManager.dispose();
    super.dispose();
  }

  // Private methods

  void _initializeServices({
    required INostrService nostrService,
    SeenVideosService? seenVideosService,
    ConnectionStatusService? connectionService,
    VideoManagerConfig? config,
  }) {
    try {
      // Initialize circuit breaker
      _circuitBreaker = VideoCircuitBreaker(
        failureThreshold: 3,
        openTimeout: const Duration(minutes: 1),
        halfOpenTimeout: const Duration(seconds: 30),
      );

      // Initialize video manager
      final baseManager = VideoManagerService(config: config);
      _videoManager = VideoManagerServiceWithPlayback(baseManager);

      // Initialize subscription manager
      final subscriptionManager = SubscriptionManager(nostrService);

      // Initialize Nostr bridge
      _nostrBridge = NostrVideoBridge(
        videoManager: _videoManager,
        nostrService: nostrService,
        subscriptionManager: subscriptionManager,
        seenVideosService: seenVideosService,
      );

      // Listen for state changes
      _videoManager.addListener(_onVideoManagerChanged);
      _nostrBridge.addListener(_onNostrBridgeChanged);
      _circuitBreaker.addListener(_onCircuitBreakerChanged);

      _isInitialized = true;
      _initializationError = null;
      
      Log.info('VideoManagerProvider: Initialized successfully', name: 'VideoManagerProvider', category: LogCategory.ui);
      
      // Notify listeners after initialization
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });

    } catch (e) {
      _isInitialized = false;
      _initializationError = 'Initialization failed: $e';
      Log.error('VideoManagerProvider: Initialization failed: $e', name: 'VideoManagerProvider', category: LogCategory.ui);
    }
  }

  void _onVideoManagerChanged() {
    _lastUpdate = DateTime.now();
    notifyListeners();
  }

  void _onNostrBridgeChanged() {
    notifyListeners();
  }

  void _onCircuitBreakerChanged() {
    // Circuit breaker state changes might affect what videos are loadable
    notifyListeners();
  }
}

/// Factory for creating VideoManagerProvider with proper dependency injection
class VideoManagerProviderFactory {
  static VideoManagerProvider create({
    required INostrService nostrService,
    SeenVideosService? seenVideosService,
    ConnectionStatusService? connectionService,
    VideoManagerConfig? config,
  }) {
    return VideoManagerProvider(
      nostrService: nostrService,
      seenVideosService: seenVideosService,
      connectionService: connectionService,
      config: config,
    );
  }

  /// Create provider with default configuration for production
  static VideoManagerProvider createProduction({
    required INostrService nostrService,
    SeenVideosService? seenVideosService,
    ConnectionStatusService? connectionService,
  }) {
    return create(
      nostrService: nostrService,
      seenVideosService: seenVideosService,
      connectionService: connectionService,
      config: const VideoManagerConfig(
        maxVideos: 100,
        preloadAhead: 3,
        preloadBehind: 1,
        maxRetries: 3,
        preloadTimeout: Duration(seconds: 10),
        enableMemoryManagement: true,
      ),
    );
  }

  /// Create provider with conservative settings for low-memory devices
  static VideoManagerProvider createLowMemory({
    required INostrService nostrService,
    SeenVideosService? seenVideosService,
    ConnectionStatusService? connectionService,
  }) {
    return create(
      nostrService: nostrService,
      seenVideosService: seenVideosService,
      connectionService: connectionService,
      config: const VideoManagerConfig(
        maxVideos: 50,
        preloadAhead: 2,
        preloadBehind: 0,
        maxRetries: 2,
        preloadTimeout: Duration(seconds: 15),
        enableMemoryManagement: true,
      ),
    );
  }
}

/// Extension methods for easy Provider integration
extension VideoManagerProviderExtensions on BuildContext {
  /// Get VideoManagerProvider instance
  VideoManagerProvider get videoManager => read<VideoManagerProvider>();
  
  /// Watch VideoManagerProvider changes
  VideoManagerProvider get watchVideoManager => watch<VideoManagerProvider>();
  
  /// Get videos from provider
  List<VideoEvent> get videos => watch<VideoManagerProvider>().videos;
  
  /// Get ready videos from provider
  List<VideoEvent> get readyVideos => watch<VideoManagerProvider>().readyVideos;
}