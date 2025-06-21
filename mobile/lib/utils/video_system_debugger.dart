// ABOUTME: Debug utility to test and compare VideoManagerService vs legacy VideoCacheService
// ABOUTME: Provides runtime switching between video systems to measure performance differences

import 'package:flutter/material.dart';
import '../models/video_event.dart';

/// Available video systems
enum VideoSystem {
  legacy,     // Pure VideoCacheService (old dual-list)
  manager,    // Pure VideoManagerService (new single source)
  hybrid,     // Current mixed state
}

/// System performance metrics
class SystemMetrics {
  int videosLoaded = 0;
  int videosFailedToLoad = 0;
  double averageLoadTime = 0.0;
  int memoryUsageMB = 0;
  DateTime? lastMeasurement;
  List<double> loadTimes = [];
  
  double get successRate => videosLoaded + videosFailedToLoad > 0 
      ? (videosLoaded / (videosLoaded + videosFailedToLoad)) * 100 
      : 0.0;
}

/// Debug utility for comparing video system performance
class VideoSystemDebugger {
  static final VideoSystemDebugger _instance = VideoSystemDebugger._internal();
  factory VideoSystemDebugger() => _instance;
  VideoSystemDebugger._internal();

  /// Current active video system
  VideoSystem _currentSystem = VideoSystem.hybrid; // Default to current hybrid state
  
  /// Debug metrics
  final Map<VideoSystem, SystemMetrics> _metrics = {};
  
  /// Debug overlay visibility
  bool _showDebugOverlay = false;
  
  /// Performance measurement start time
  DateTime? _measurementStartTime;

  // Getters
  VideoSystem get currentSystem => _currentSystem;
  bool get showDebugOverlay => _showDebugOverlay;
  Map<VideoSystem, SystemMetrics> get metrics => Map.unmodifiable(_metrics);

  /// Switch to a specific video system
  void switchToSystem(VideoSystem system) {
    if (_currentSystem == system) return;
    
    debugPrint('🔄 VideoSystemDebugger: Switching from $_currentSystem to $system');
    debugPrint('📊 System switching will affect next video loads and UI rebuilds');
    _currentSystem = system;
    _measurementStartTime = DateTime.now();
    
    // Initialize metrics for the new system if not exists
    _metrics.putIfAbsent(system, () => SystemMetrics());
    
    debugPrint('💡 Switch to a different video and back to see performance differences');
    debugPrint('📋 Use "Performance Report" in debug menu to compare systems');
  }

  /// Toggle debug overlay visibility
  void toggleDebugOverlay() {
    _showDebugOverlay = !_showDebugOverlay;
    debugPrint('🐛 Debug overlay ${_showDebugOverlay ? 'enabled' : 'disabled'}');
  }

  /// Record video load success
  void recordVideoLoad(VideoEvent video, Duration loadTime) {
    final metrics = _metrics.putIfAbsent(_currentSystem, () => SystemMetrics());
    metrics.videosLoaded++;
    metrics.loadTimes.add(loadTime.inMilliseconds.toDouble());
    metrics.averageLoadTime = metrics.loadTimes.reduce((a, b) => a + b) / metrics.loadTimes.length;
    metrics.lastMeasurement = DateTime.now();
    
    debugPrint('📊 ${_currentSystem.name.toUpperCase()}: Video loaded in ${loadTime.inMilliseconds}ms (avg: ${metrics.averageLoadTime.toStringAsFixed(1)}ms)');
  }

  /// Record video load failure
  void recordVideoFailure(VideoEvent video, String error) {
    final metrics = _metrics.putIfAbsent(_currentSystem, () => SystemMetrics());
    metrics.videosFailedToLoad++;
    metrics.lastMeasurement = DateTime.now();
    
    debugPrint('❌ ${_currentSystem.name.toUpperCase()}: Video failed to load - $error');
  }

  /// Update memory usage
  void updateMemoryUsage(int memoryMB) {
    final metrics = _metrics.putIfAbsent(_currentSystem, () => SystemMetrics());
    metrics.memoryUsageMB = memoryMB;
  }

  /// Get system comparison report
  String getComparisonReport() {
    if (_metrics.isEmpty) return 'No metrics collected yet';

    final buffer = StringBuffer();
    buffer.writeln('🏁 VIDEO SYSTEM PERFORMANCE COMPARISON');
    buffer.writeln('═' * 50);
    
    for (final system in VideoSystem.values) {
      final metrics = _metrics[system];
      if (metrics == null) {
        buffer.writeln('${system.name.toUpperCase()}: No data collected');
        continue;
      }
      
      buffer.writeln('${system.name.toUpperCase()}:');
      buffer.writeln('  📈 Success Rate: ${metrics.successRate.toStringAsFixed(1)}%');
      buffer.writeln('  ⚡ Avg Load Time: ${metrics.averageLoadTime.toStringAsFixed(1)}ms');
      buffer.writeln('  ✅ Videos Loaded: ${metrics.videosLoaded}');
      buffer.writeln('  ❌ Failed Loads: ${metrics.videosFailedToLoad}');
      buffer.writeln('  🧠 Memory Usage: ${metrics.memoryUsageMB}MB');
      buffer.writeln('  ⏰ Last Update: ${metrics.lastMeasurement?.toString() ?? 'Never'}');
      buffer.writeln();
    }
    
    // Determine winner
    if (_metrics.length >= 2) {
      final bestSystem = _findBestPerformingSystem();
      buffer.writeln('🏆 WINNER: ${bestSystem.name.toUpperCase()}');
    }
    
    return buffer.toString();
  }

  /// Find the best performing system based on metrics
  VideoSystem _findBestPerformingSystem() {
    VideoSystem? bestSystem;
    double bestScore = -1;
    
    for (final entry in _metrics.entries) {
      final metrics = entry.value;
      if (metrics.videosLoaded == 0) continue;
      
      // Calculate composite score (success rate weight 60%, speed weight 40%)
      final speedScore = metrics.averageLoadTime > 0 ? (1000 / metrics.averageLoadTime) * 100 : 0;
      final score = (metrics.successRate * 0.6) + (speedScore * 0.4);
      
      if (score > bestScore) {
        bestScore = score;
        bestSystem = entry.key;
      }
    }
    
    return bestSystem ?? VideoSystem.hybrid;
  }

  /// Reset all metrics
  void resetMetrics() {
    _metrics.clear();
    debugPrint('🔄 All video system metrics reset');
  }

  /// Get debug info for current system
  Map<String, dynamic> getCurrentSystemDebugInfo() {
    final metrics = _metrics[_currentSystem];
    return {
      'currentSystem': _currentSystem.name,
      'measurementDuration': _measurementStartTime != null 
          ? DateTime.now().difference(_measurementStartTime!).inSeconds 
          : 0,
      'metrics': metrics != null ? {
        'videosLoaded': metrics.videosLoaded,
        'videosFailedToLoad': metrics.videosFailedToLoad,
        'successRate': metrics.successRate,
        'averageLoadTime': metrics.averageLoadTime,
        'memoryUsageMB': metrics.memoryUsageMB,
      } : null,
    };
  }
}

/// Debug overlay widget to display system information
class VideoSystemDebugOverlay extends StatelessWidget {
  final Widget child;
  
  const VideoSystemDebugOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (VideoSystemDebugger().showDebugOverlay)
          Positioned(
            top: 100,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple, width: 1),
              ),
              constraints: const BoxConstraints(maxWidth: 250),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '🐛 VIDEO SYSTEM DEBUG',
                    style: TextStyle(
                      color: Colors.purple[300],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildSystemSelector(),
                  const SizedBox(height: 8),
                  _buildCurrentMetrics(),
                  const SizedBox(height: 8),
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSystemSelector() {
    final debugger = VideoSystemDebugger();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Current: ${debugger.currentSystem.name.toUpperCase()}',
          style: const TextStyle(color: Colors.white, fontSize: 11),
        ),
        const SizedBox(height: 4),
        ...VideoSystem.values.map((system) {
          final isActive = debugger.currentSystem == system;
          return GestureDetector(
            onTap: () => debugger.switchToSystem(system),
            child: Container(
              margin: const EdgeInsets.only(bottom: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isActive ? Colors.purple[700] : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${isActive ? '• ' : '  '}${system.name}',
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.grey[400],
                  fontSize: 10,
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildCurrentMetrics() {
    final debugger = VideoSystemDebugger();
    final metrics = debugger.metrics[debugger.currentSystem];
    
    if (metrics == null) {
      return const Text(
        'No metrics yet',
        style: TextStyle(color: Colors.grey, fontSize: 10),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Success: ${metrics.successRate.toStringAsFixed(1)}%',
          style: const TextStyle(color: Colors.green, fontSize: 10),
        ),
        Text(
          'Load: ${metrics.averageLoadTime.toStringAsFixed(0)}ms',
          style: const TextStyle(color: Colors.blue, fontSize: 10),
        ),
        Text(
          'Memory: ${metrics.memoryUsageMB}MB',
          style: const TextStyle(color: Colors.orange, fontSize: 10),
        ),
        Text(
          'Videos: ${metrics.videosLoaded}/${metrics.videosLoaded + metrics.videosFailedToLoad}',
          style: const TextStyle(color: Colors.white, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final debugger = VideoSystemDebugger();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            debugPrint(debugger.getComparisonReport());
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue[700],
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Report',
              style: TextStyle(color: Colors.white, fontSize: 9),
            ),
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: debugger.resetMetrics,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red[700],
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Reset',
              style: TextStyle(color: Colors.white, fontSize: 9),
            ),
          ),
        ),
      ],
    );
  }
}