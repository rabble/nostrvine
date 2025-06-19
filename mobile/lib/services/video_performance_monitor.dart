// ABOUTME: Performance monitoring service for video system analytics and alerting
// ABOUTME: Tracks memory usage, preload success rates, and error patterns for production optimization

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/video_event.dart';
import '../models/video_state.dart';
import 'video_manager_interface.dart';

/// Performance monitoring service for video system
/// 
/// This service provides comprehensive monitoring of video system performance,
/// including memory usage, preload success rates, error patterns, and user
/// engagement metrics. It supports real-time analytics and alerting for
/// production deployments.
class VideoPerformanceMonitor extends ChangeNotifier {
  final IVideoManager _videoManager;
  final Duration _samplingInterval;
  final int _maxSampleHistory;
  
  // Performance metrics
  final List<PerformanceSample> _samples = [];
  final Map<String, int> _errorCounts = {};
  final Map<String, List<Duration>> _preloadTimes = {};
  final Map<String, int> _circuitBreakerTrips = {};
  
  // Real-time monitoring
  Timer? _monitoringTimer;
  bool _isMonitoring = false;
  
  // Alert thresholds
  late final AlertThresholds _thresholds;
  final List<PerformanceAlert> _activeAlerts = [];
  final StreamController<PerformanceAlert> _alertController = 
      StreamController<PerformanceAlert>.broadcast();
  
  VideoPerformanceMonitor({
    required IVideoManager videoManager,
    Duration samplingInterval = const Duration(seconds: 30),
    int maxSampleHistory = 1000,
    AlertThresholds? thresholds,
  }) : _videoManager = videoManager,
       _samplingInterval = samplingInterval,
       _maxSampleHistory = maxSampleHistory,
       _thresholds = thresholds ?? AlertThresholds();

  /// Stream of performance alerts
  Stream<PerformanceAlert> get alerts => _alertController.stream;
  
  /// Current active alerts
  List<PerformanceAlert> get activeAlerts => List.unmodifiable(_activeAlerts);
  
  /// Whether monitoring is active
  bool get isMonitoring => _isMonitoring;
  
  /// Latest performance sample
  PerformanceSample? get currentSample => _samples.isEmpty ? null : _samples.last;
  
  /// Start performance monitoring
  void startMonitoring() {
    if (_isMonitoring) return;
    
    _isMonitoring = true;
    _monitoringTimer = Timer.periodic(_samplingInterval, (_) {
      _collectPerformanceSample();
    });
    
    debugPrint('VideoPerformanceMonitor: Started monitoring');
    notifyListeners();
  }
  
  /// Stop performance monitoring
  void stopMonitoring() {
    if (!_isMonitoring) return;
    
    _isMonitoring = false;
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    
    debugPrint('VideoPerformanceMonitor: Stopped monitoring');
    notifyListeners();
  }
  
  /// Record a video preload event
  void recordPreloadEvent({
    required String videoId,
    required bool success,
    required Duration duration,
    String? errorMessage,
  }) {
    // Track preload times
    _preloadTimes.putIfAbsent(videoId, () => []).add(duration);
    
    // Track errors
    if (!success && errorMessage != null) {
      _errorCounts[errorMessage] = (_errorCounts[errorMessage] ?? 0) + 1;
    }
    
    // Check for slow preload alert
    if (duration > _thresholds.slowPreloadThreshold) {
      _triggerAlert(PerformanceAlert(
        type: AlertType.slowPreload,
        severity: AlertSeverity.warning,
        message: 'Slow preload detected: ${duration.inMilliseconds}ms for $videoId',
        timestamp: DateTime.now(),
        metadata: {
          'videoId': videoId,
          'duration': duration.inMilliseconds,
          'threshold': _thresholds.slowPreloadThreshold.inMilliseconds,
        },
      ));
    }
    
    // Check for preload failure alert
    if (!success) {
      final failureRate = _calculatePreloadFailureRate();
      if (failureRate > _thresholds.preloadFailureRateThreshold) {
        _triggerAlert(PerformanceAlert(
          type: AlertType.highPreloadFailureRate,
          severity: AlertSeverity.critical,
          message: 'High preload failure rate: ${(failureRate * 100).toStringAsFixed(1)}%',
          timestamp: DateTime.now(),
          metadata: {
            'failureRate': failureRate,
            'threshold': _thresholds.preloadFailureRateThreshold,
          },
        ));
      }
    }
  }
  
  /// Record a circuit breaker trip
  void recordCircuitBreakerTrip(String videoId, String reason) {
    _circuitBreakerTrips[videoId] = (_circuitBreakerTrips[videoId] ?? 0) + 1;
    
    _triggerAlert(PerformanceAlert(
      type: AlertType.circuitBreakerTrip,
      severity: AlertSeverity.warning,
      message: 'Circuit breaker tripped for $videoId: $reason',
      timestamp: DateTime.now(),
      metadata: {
        'videoId': videoId,
        'reason': reason,
        'tripCount': _circuitBreakerTrips[videoId],
      },
    ));
  }
  
  /// Record a memory pressure event
  void recordMemoryPressure(int memoryUsageMB, int controllersDisposed) {
    _triggerAlert(PerformanceAlert(
      type: AlertType.memoryPressure,
      severity: memoryUsageMB > _thresholds.criticalMemoryThreshold 
          ? AlertSeverity.critical 
          : AlertSeverity.warning,
      message: 'Memory pressure event: ${memoryUsageMB}MB, disposed $controllersDisposed controllers',
      timestamp: DateTime.now(),
      metadata: {
        'memoryUsageMB': memoryUsageMB,
        'controllersDisposed': controllersDisposed,
      },
    ));
  }
  
  /// Get comprehensive performance statistics
  PerformanceStatistics getStatistics() {
    final debugInfo = _videoManager.getDebugInfo();
    final recentSamples = _samples.take(100).toList();
    
    return PerformanceStatistics(
      timestamp: DateTime.now(),
      currentMemoryMB: debugInfo['estimatedMemoryMB'] ?? 0,
      currentControllers: debugInfo['controllers'] ?? 0,
      totalVideos: debugInfo['totalVideos'] ?? 0,
      readyVideos: debugInfo['readyVideos'] ?? 0,
      loadingVideos: debugInfo['loadingVideos'] ?? 0,
      failedVideos: debugInfo['failedVideos'] ?? 0,
      averagePreloadTime: _calculateAveragePreloadTime(),
      preloadSuccessRate: _calculatePreloadSuccessRate(),
      topErrors: _getTopErrors(),
      memoryTrend: _calculateMemoryTrend(recentSamples),
      performanceTrend: _calculatePerformanceTrend(recentSamples),
      circuitBreakerTrips: Map.from(_circuitBreakerTrips),
      sampleCount: _samples.length,
    );
  }
  
  /// Get performance analytics for dashboard
  PerformanceAnalytics getAnalytics({Duration? timeRange}) {
    final cutoff = timeRange != null 
        ? DateTime.now().subtract(timeRange)
        : null;
    
    final relevantSamples = cutoff != null
        ? _samples.where((s) => s.timestamp.isAfter(cutoff)).toList()
        : _samples;
    
    return PerformanceAnalytics(
      timeRange: timeRange ?? const Duration(hours: 24),
      sampleCount: relevantSamples.length,
      memoryUsage: _analyzeMemoryUsage(relevantSamples),
      preloadPerformance: _analyzePreloadPerformance(),
      errorAnalysis: _analyzeErrors(),
      alertSummary: _analyzeAlerts(cutoff),
      recommendations: _generateRecommendations(),
    );
  }
  
  /// Clear all performance data (useful for testing)
  void clearData() {
    _samples.clear();
    _errorCounts.clear();
    _preloadTimes.clear();
    _circuitBreakerTrips.clear();
    _activeAlerts.clear();
    
    debugPrint('VideoPerformanceMonitor: Cleared all data');
    notifyListeners();
  }
  
  /// Dismiss an active alert
  void dismissAlert(String alertId) {
    _activeAlerts.removeWhere((alert) => alert.id == alertId);
    notifyListeners();
  }
  
  @override
  void dispose() {
    stopMonitoring();
    _alertController.close();
    super.dispose();
  }
  
  // Private methods
  
  void _collectPerformanceSample() {
    final debugInfo = _videoManager.getDebugInfo();
    
    final sample = PerformanceSample(
      timestamp: DateTime.now(),
      memoryUsageMB: debugInfo['estimatedMemoryMB'] ?? 0,
      controllerCount: debugInfo['controllers'] ?? 0,
      totalVideos: debugInfo['totalVideos'] ?? 0,
      readyVideos: debugInfo['readyVideos'] ?? 0,
      loadingVideos: debugInfo['loadingVideos'] ?? 0,
      failedVideos: debugInfo['failedVideos'] ?? 0,
      preloadingQueue: debugInfo['preloadingQueue'] ?? 0,
    );
    
    _samples.add(sample);
    
    // Maintain sample history limit
    if (_samples.length > _maxSampleHistory) {
      _samples.removeRange(0, _samples.length - _maxSampleHistory);
    }
    
    // Check for alerts
    _checkThresholds(sample);
    
    notifyListeners();
  }
  
  void _checkThresholds(PerformanceSample sample) {
    // High memory usage
    if (sample.memoryUsageMB > _thresholds.highMemoryThreshold) {
      _triggerAlert(PerformanceAlert(
        type: AlertType.highMemoryUsage,
        severity: sample.memoryUsageMB > _thresholds.criticalMemoryThreshold 
            ? AlertSeverity.critical 
            : AlertSeverity.warning,
        message: 'High memory usage: ${sample.memoryUsageMB}MB',
        timestamp: sample.timestamp,
        metadata: {'memoryUsageMB': sample.memoryUsageMB},
      ));
    }
    
    // Too many controllers
    if (sample.controllerCount > _thresholds.maxControllers) {
      _triggerAlert(PerformanceAlert(
        type: AlertType.tooManyControllers,
        severity: AlertSeverity.warning,
        message: 'Too many controllers: ${sample.controllerCount}',
        timestamp: sample.timestamp,
        metadata: {'controllerCount': sample.controllerCount},
      ));
    }
    
    // High failure rate
    final failureRate = sample.totalVideos > 0 
        ? sample.failedVideos / sample.totalVideos 
        : 0.0;
    
    if (failureRate > _thresholds.highFailureRateThreshold) {
      _triggerAlert(PerformanceAlert(
        type: AlertType.highFailureRate,
        severity: AlertSeverity.critical,
        message: 'High failure rate: ${(failureRate * 100).toStringAsFixed(1)}%',
        timestamp: sample.timestamp,
        metadata: {
          'failureRate': failureRate,
          'failedVideos': sample.failedVideos,
          'totalVideos': sample.totalVideos,
        },
      ));
    }
  }
  
  void _triggerAlert(PerformanceAlert alert) {
    // Avoid duplicate alerts
    final existingAlert = _activeAlerts.firstWhere(
      (a) => a.type == alert.type && a.severity == alert.severity,
      orElse: () => PerformanceAlert(
        type: AlertType.unknown,
        severity: AlertSeverity.info,
        message: '',
        timestamp: DateTime.now(),
      ),
    );
    
    if (existingAlert.type == AlertType.unknown) {
      _activeAlerts.add(alert);
      _alertController.add(alert);
      
      debugPrint('VideoPerformanceMonitor: Alert triggered - ${alert.message}');
    }
  }
  
  double _calculateAveragePreloadTime() {
    if (_preloadTimes.isEmpty) return 0.0;
    
    final allTimes = _preloadTimes.values.expand((times) => times).toList();
    if (allTimes.isEmpty) return 0.0;
    
    final totalMs = allTimes.fold(0, (sum, duration) => sum + duration.inMilliseconds);
    return totalMs / allTimes.length;
  }
  
  double _calculatePreloadSuccessRate() {
    if (_preloadTimes.isEmpty) return 1.0;
    
    final totalAttempts = _preloadTimes.length;
    final successfulAttempts = _preloadTimes.values
        .where((times) => times.isNotEmpty)
        .length;
    
    return totalAttempts > 0 ? successfulAttempts / totalAttempts : 1.0;
  }
  
  double _calculatePreloadFailureRate() {
    return 1.0 - _calculatePreloadSuccessRate();
  }
  
  List<ErrorSummary> _getTopErrors() {
    final sortedErrors = _errorCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedErrors.take(10).map((entry) => ErrorSummary(
      message: entry.key,
      count: entry.value,
      percentage: _errorCounts.values.isEmpty 
          ? 0.0 
          : entry.value / _errorCounts.values.fold(0, (a, b) => a + b),
    )).toList();
  }
  
  MemoryTrend _calculateMemoryTrend(List<PerformanceSample> samples) {
    if (samples.length < 2) {
      return MemoryTrend(direction: TrendDirection.stable, changeRate: 0.0);
    }
    
    final recent = samples.takeLast(10).toList();
    final older = samples.take(samples.length - 10).takeLast(10).toList();
    
    final recentAvg = recent.fold(0, (sum, s) => sum + s.memoryUsageMB) / recent.length;
    final olderAvg = older.fold(0, (sum, s) => sum + s.memoryUsageMB) / older.length;
    
    final changeRate = (recentAvg - olderAvg) / olderAvg;
    
    final direction = changeRate > 0.1 
        ? TrendDirection.increasing 
        : changeRate < -0.1 
            ? TrendDirection.decreasing 
            : TrendDirection.stable;
    
    return MemoryTrend(direction: direction, changeRate: changeRate);
  }
  
  PerformanceTrend _calculatePerformanceTrend(List<PerformanceSample> samples) {
    if (samples.length < 2) {
      return PerformanceTrend(direction: TrendDirection.stable, score: 1.0);
    }
    
    // Calculate performance score based on multiple factors
    final recentSamples = samples.takeLast(10).toList();
    final avgMemory = recentSamples.fold(0, (sum, s) => sum + s.memoryUsageMB) / recentSamples.length;
    final avgControllers = recentSamples.fold(0, (sum, s) => sum + s.controllerCount) / recentSamples.length;
    final avgFailureRate = recentSamples.fold(0.0, (sum, s) => 
        sum + (s.totalVideos > 0 ? s.failedVideos / s.totalVideos : 0.0)) / recentSamples.length;
    
    // Normalize scores (0-1, higher is better)
    final memoryScore = (1000 - avgMemory) / 1000; // Assume 1000MB is worst case
    final controllerScore = (20 - avgControllers) / 20; // Assume 20 controllers is worst case
    final failureScore = 1.0 - avgFailureRate;
    
    final overallScore = (memoryScore + controllerScore + failureScore) / 3;
    
    return PerformanceTrend(
      direction: overallScore > 0.8 
          ? TrendDirection.increasing 
          : overallScore < 0.6 
              ? TrendDirection.decreasing 
              : TrendDirection.stable,
      score: overallScore,
    );
  }
  
  MemoryUsageAnalysis _analyzeMemoryUsage(List<PerformanceSample> samples) {
    if (samples.isEmpty) {
      return MemoryUsageAnalysis(
        average: 0.0,
        peak: 0,
        minimum: 0,
        trend: MemoryTrend(direction: TrendDirection.stable, changeRate: 0.0),
        distribution: [],
      );
    }
    
    final memoryValues = samples.map((s) => s.memoryUsageMB).toList();
    final average = memoryValues.fold(0, (sum, val) => sum + val) / memoryValues.length;
    final peak = memoryValues.reduce(max);
    final minimum = memoryValues.reduce(min);
    
    return MemoryUsageAnalysis(
      average: average,
      peak: peak,
      minimum: minimum,
      trend: _calculateMemoryTrend(samples),
      distribution: _calculateMemoryDistribution(memoryValues),
    );
  }
  
  PreloadPerformanceAnalysis _analyzePreloadPerformance() {
    final allTimes = _preloadTimes.values.expand((times) => times).toList();
    
    if (allTimes.isEmpty) {
      return PreloadPerformanceAnalysis(
        averageTime: Duration.zero,
        medianTime: Duration.zero,
        successRate: 1.0,
        slowPreloads: 0,
        fastPreloads: 0,
      );
    }
    
    allTimes.sort((a, b) => a.compareTo(b));
    
    final totalMs = allTimes.fold(0, (sum, duration) => sum + duration.inMilliseconds);
    final averageTime = Duration(milliseconds: totalMs ~/ allTimes.length);
    final medianTime = allTimes[allTimes.length ~/ 2];
    
    final slowPreloads = allTimes.where((time) => time > _thresholds.slowPreloadThreshold).length;
    final fastPreloads = allTimes.where((time) => time < const Duration(seconds: 1)).length;
    
    return PreloadPerformanceAnalysis(
      averageTime: averageTime,
      medianTime: medianTime,
      successRate: _calculatePreloadSuccessRate(),
      slowPreloads: slowPreloads,
      fastPreloads: fastPreloads,
    );
  }
  
  ErrorAnalysis _analyzeErrors() {
    final totalErrors = _errorCounts.values.fold(0, (sum, count) => sum + count);
    
    return ErrorAnalysis(
      totalErrors: totalErrors,
      uniqueErrors: _errorCounts.length,
      topErrors: _getTopErrors(),
      errorRate: _calculatePreloadFailureRate(),
    );
  }
  
  AlertSummary _analyzeAlerts(DateTime? cutoff) {
    final relevantAlerts = cutoff != null
        ? _activeAlerts.where((alert) => alert.timestamp.isAfter(cutoff)).toList()
        : _activeAlerts;
    
    final criticalCount = relevantAlerts.where((a) => a.severity == AlertSeverity.critical).length;
    final warningCount = relevantAlerts.where((a) => a.severity == AlertSeverity.warning).length;
    final infoCount = relevantAlerts.where((a) => a.severity == AlertSeverity.info).length;
    
    return AlertSummary(
      totalAlerts: relevantAlerts.length,
      criticalAlerts: criticalCount,
      warningAlerts: warningCount,
      infoAlerts: infoCount,
      recentAlerts: relevantAlerts.take(10).toList(),
    );
  }
  
  List<PerformanceRecommendation> _generateRecommendations() {
    final recommendations = <PerformanceRecommendation>[];
    final stats = getStatistics();
    
    // Memory recommendations
    if (stats.currentMemoryMB > _thresholds.highMemoryThreshold) {
      recommendations.add(PerformanceRecommendation(
        type: RecommendationType.memory,
        priority: RecommendationPriority.high,
        title: 'Reduce Memory Usage',
        description: 'Current memory usage is ${stats.currentMemoryMB}MB. Consider reducing preload range or implementing more aggressive cleanup.',
        action: 'Reduce preload range or increase cleanup frequency',
      ));
    }
    
    // Controller recommendations
    if (stats.currentControllers > _thresholds.maxControllers) {
      recommendations.add(PerformanceRecommendation(
        type: RecommendationType.performance,
        priority: RecommendationPriority.medium,
        title: 'Too Many Controllers',
        description: 'Currently managing ${stats.currentControllers} controllers. Consider reducing the maximum limit.',
        action: 'Reduce maximum controller limit in configuration',
      ));
    }
    
    // Preload recommendations
    if (stats.preloadSuccessRate < 0.9) {
      recommendations.add(PerformanceRecommendation(
        type: RecommendationType.network,
        priority: RecommendationPriority.high,
        title: 'Low Preload Success Rate',
        description: 'Preload success rate is ${(stats.preloadSuccessRate * 100).toStringAsFixed(1)}%. Check network conditions and URL validity.',
        action: 'Improve URL validation and network error handling',
      ));
    }
    
    return recommendations;
  }
  
  List<MemoryDistributionBucket> _calculateMemoryDistribution(List<int> memoryValues) {
    final buckets = <MemoryDistributionBucket>[];
    final bucketSize = 100; // 100MB buckets
    final maxMemory = memoryValues.isEmpty ? 0 : memoryValues.reduce(max);
    
    for (int i = 0; i <= maxMemory; i += bucketSize) {
      final count = memoryValues.where((val) => val >= i && val < i + bucketSize).length;
      if (count > 0) {
        buckets.add(MemoryDistributionBucket(
          rangeStart: i,
          rangeEnd: i + bucketSize,
          count: count,
          percentage: count / memoryValues.length,
        ));
      }
    }
    
    return buckets;
  }
}

// Data classes for performance monitoring

class PerformanceSample {
  final DateTime timestamp;
  final int memoryUsageMB;
  final int controllerCount;
  final int totalVideos;
  final int readyVideos;
  final int loadingVideos;
  final int failedVideos;
  final int preloadingQueue;
  
  const PerformanceSample({
    required this.timestamp,
    required this.memoryUsageMB,
    required this.controllerCount,
    required this.totalVideos,
    required this.readyVideos,
    required this.loadingVideos,
    required this.failedVideos,
    required this.preloadingQueue,
  });
}

class PerformanceStatistics {
  final DateTime timestamp;
  final int currentMemoryMB;
  final int currentControllers;
  final int totalVideos;
  final int readyVideos;
  final int loadingVideos;
  final int failedVideos;
  final double averagePreloadTime;
  final double preloadSuccessRate;
  final List<ErrorSummary> topErrors;
  final MemoryTrend memoryTrend;
  final PerformanceTrend performanceTrend;
  final Map<String, int> circuitBreakerTrips;
  final int sampleCount;
  
  const PerformanceStatistics({
    required this.timestamp,
    required this.currentMemoryMB,
    required this.currentControllers,
    required this.totalVideos,
    required this.readyVideos,
    required this.loadingVideos,
    required this.failedVideos,
    required this.averagePreloadTime,
    required this.preloadSuccessRate,
    required this.topErrors,
    required this.memoryTrend,
    required this.performanceTrend,
    required this.circuitBreakerTrips,
    required this.sampleCount,
  });
}

class PerformanceAnalytics {
  final Duration timeRange;
  final int sampleCount;
  final MemoryUsageAnalysis memoryUsage;
  final PreloadPerformanceAnalysis preloadPerformance;
  final ErrorAnalysis errorAnalysis;
  final AlertSummary alertSummary;
  final List<PerformanceRecommendation> recommendations;
  
  const PerformanceAnalytics({
    required this.timeRange,
    required this.sampleCount,
    required this.memoryUsage,
    required this.preloadPerformance,
    required this.errorAnalysis,
    required this.alertSummary,
    required this.recommendations,
  });
}

class PerformanceAlert {
  final String id;
  final AlertType type;
  final AlertSeverity severity;
  final String message;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;
  
  PerformanceAlert({
    String? id,
    required this.type,
    required this.severity,
    required this.message,
    required this.timestamp,
    this.metadata = const {},
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();
}

class AlertThresholds {
  final int highMemoryThreshold;
  final int criticalMemoryThreshold;
  final int maxControllers;
  final double highFailureRateThreshold;
  final double preloadFailureRateThreshold;
  final Duration slowPreloadThreshold;
  
  const AlertThresholds({
    this.highMemoryThreshold = 500,
    this.criticalMemoryThreshold = 800,
    this.maxControllers = 15,
    this.highFailureRateThreshold = 0.2,
    this.preloadFailureRateThreshold = 0.1,
    this.slowPreloadThreshold = const Duration(seconds: 5),
  });
}

class ErrorSummary {
  final String message;
  final int count;
  final double percentage;
  
  const ErrorSummary({
    required this.message,
    required this.count,
    required this.percentage,
  });
}

class MemoryTrend {
  final TrendDirection direction;
  final double changeRate;
  
  const MemoryTrend({required this.direction, required this.changeRate});
}

class PerformanceTrend {
  final TrendDirection direction;
  final double score;
  
  const PerformanceTrend({required this.direction, required this.score});
}

class MemoryUsageAnalysis {
  final double average;
  final int peak;
  final int minimum;
  final MemoryTrend trend;
  final List<MemoryDistributionBucket> distribution;
  
  const MemoryUsageAnalysis({
    required this.average,
    required this.peak,
    required this.minimum,
    required this.trend,
    required this.distribution,
  });
}

class MemoryDistributionBucket {
  final int rangeStart;
  final int rangeEnd;
  final int count;
  final double percentage;
  
  const MemoryDistributionBucket({
    required this.rangeStart,
    required this.rangeEnd,
    required this.count,
    required this.percentage,
  });
}

class PreloadPerformanceAnalysis {
  final Duration averageTime;
  final Duration medianTime;
  final double successRate;
  final int slowPreloads;
  final int fastPreloads;
  
  const PreloadPerformanceAnalysis({
    required this.averageTime,
    required this.medianTime,
    required this.successRate,
    required this.slowPreloads,
    required this.fastPreloads,
  });
}

class ErrorAnalysis {
  final int totalErrors;
  final int uniqueErrors;
  final List<ErrorSummary> topErrors;
  final double errorRate;
  
  const ErrorAnalysis({
    required this.totalErrors,
    required this.uniqueErrors,
    required this.topErrors,
    required this.errorRate,
  });
}

class AlertSummary {
  final int totalAlerts;
  final int criticalAlerts;
  final int warningAlerts;
  final int infoAlerts;
  final List<PerformanceAlert> recentAlerts;
  
  const AlertSummary({
    required this.totalAlerts,
    required this.criticalAlerts,
    required this.warningAlerts,
    required this.infoAlerts,
    required this.recentAlerts,
  });
}

class PerformanceRecommendation {
  final RecommendationType type;
  final RecommendationPriority priority;
  final String title;
  final String description;
  final String action;
  
  const PerformanceRecommendation({
    required this.type,
    required this.priority,
    required this.title,
    required this.description,
    required this.action,
  });
}

// Enums
enum AlertType {
  highMemoryUsage,
  criticalMemoryUsage,
  tooManyControllers,
  highFailureRate,
  slowPreload,
  highPreloadFailureRate,
  circuitBreakerTrip,
  memoryPressure,
  unknown,
}

enum AlertSeverity { info, warning, critical }

enum TrendDirection { increasing, decreasing, stable }

enum RecommendationType { memory, performance, network, configuration }

enum RecommendationPriority { low, medium, high, critical }

// Extension for better list operations
extension ListExtensions<T> on List<T> {
  List<T> takeLast(int count) {
    if (count >= length) return this;
    return sublist(length - count);
  }
}