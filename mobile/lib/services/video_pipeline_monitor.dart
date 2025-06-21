// ABOUTME: Comprehensive video processing pipeline monitoring service
// ABOUTME: Aggregates metrics from GIF service, upload manager, and provides alerting and performance tracking

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'gif_service.dart';
import 'upload_manager.dart';
import 'circuit_breaker_service.dart';

/// Pipeline health status
enum PipelineHealth {
  healthy,
  degraded,
  critical,
  offline,
}

/// Pipeline stage metrics
class StageMetrics {
  final String stageName;
  final int successCount;
  final int failureCount;
  final Duration averageProcessingTime;
  final double errorRate;
  final Map<String, int> errorCategories;
  final DateTime lastUpdate;
  
  const StageMetrics({
    required this.stageName,
    required this.successCount,
    required this.failureCount,
    required this.averageProcessingTime,
    required this.errorRate,
    required this.errorCategories,
    required this.lastUpdate,
  });
  
  double get successRate => 
      (successCount + failureCount) > 0 
          ? (successCount / (successCount + failureCount)) * 100 
          : 0;
}

/// Performance alert levels
enum AlertLevel {
  info,
  warning,
  critical,
}

/// Performance alert
class PerformanceAlert {
  final String id;
  final AlertLevel level;
  final String title;
  final String description;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;
  final bool isResolved;
  
  const PerformanceAlert({
    required this.id,
    required this.level,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.metadata,
    this.isResolved = false,
  });
}

/// Comprehensive video pipeline monitoring
class VideoPipelineMonitor {
  static final VideoPipelineMonitor _instance = VideoPipelineMonitor._internal();
  factory VideoPipelineMonitor() => _instance;
  VideoPipelineMonitor._internal();

  // Monitoring configuration
  static const Duration _healthCheckInterval = Duration(minutes: 1);
  static const Duration _metricsRetentionPeriod = Duration(hours: 24);
  static const int _alertHistoryLimit = 100;
  
  // Health thresholds
  static const double _healthyErrorRateThreshold = 5.0; // 5%
  static const double _degradedErrorRateThreshold = 15.0; // 15%
  static const Duration _healthyProcessingTimeThreshold = Duration(seconds: 30);
  static const Duration _degradedProcessingTimeThreshold = Duration(minutes: 2);
  
  // State
  Timer? _healthCheckTimer;
  final Map<String, StageMetrics> _stageMetrics = {};
  final List<PerformanceAlert> _alerts = [];
  final StreamController<PipelineHealth> _healthController = StreamController.broadcast();
  final StreamController<PerformanceAlert> _alertController = StreamController.broadcast();
  
  PipelineHealth _currentHealth = PipelineHealth.healthy;
  DateTime _lastHealthCheck = DateTime.now();

  // Service references
  GifService? _gifService;
  UploadManager? _uploadManager;

  /// Initialize monitoring with service references
  void initialize({
    GifService? gifService,
    UploadManager? uploadManager,
  }) {
    _gifService = gifService;
    _uploadManager = uploadManager;
    
    debugPrint('🔍 Initializing VideoPipelineMonitor');
    
    // Start periodic health checks
    _startHealthChecks();
    
    debugPrint('✅ VideoPipelineMonitor initialized');
  }

  /// Start periodic health monitoring
  void _startHealthChecks() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(_healthCheckInterval, (_) {
      _performHealthCheck();
    });
  }

  /// Perform comprehensive health check
  Future<void> _performHealthCheck() async {
    try {
      debugPrint('🔍 Performing pipeline health check...');
      
      // Collect metrics from all stages
      await _collectGifServiceMetrics();
      await _collectUploadManagerMetrics();
      
      // Evaluate overall health
      final newHealth = _evaluateOverallHealth();
      
      // Check for performance issues and generate alerts
      _checkPerformanceAlerts();
      
      // Update health status
      if (newHealth != _currentHealth) {
        debugPrint('🚨 Pipeline health changed: $_currentHealth → $newHealth');
        _currentHealth = newHealth;
        _healthController.add(newHealth);
      }
      
      _lastHealthCheck = DateTime.now();
      
    } catch (e) {
      debugPrint('❌ Health check failed: $e');
      _currentHealth = PipelineHealth.critical;
      _healthController.add(_currentHealth);
    }
  }

  /// Collect GIF service metrics
  Future<void> _collectGifServiceMetrics() async {
    try {
      // For now, we'll track basic metrics
      // In a real implementation, the GIF service would expose more detailed metrics
      
      _stageMetrics['gif_processing'] = StageMetrics(
        stageName: 'GIF Processing',
        successCount: 0, // Would be tracked by GIF service
        failureCount: 0, // Would be tracked by GIF service
        averageProcessingTime: const Duration(seconds: 5), // Placeholder
        errorRate: 0.0,
        errorCategories: const {},
        lastUpdate: DateTime.now(),
      );
      
    } catch (e) {
      debugPrint('⚠️ Failed to collect GIF service metrics: $e');
    }
  }

  /// Collect upload manager metrics
  Future<void> _collectUploadManagerMetrics() async {
    try {
      if (_uploadManager == null) return;
      
      final performanceMetrics = _uploadManager!.getPerformanceMetrics();
      final recentMetrics = _uploadManager!.getRecentMetrics();
      
      // Calculate average processing time from recent uploads
      final avgProcessingTime = recentMetrics.isNotEmpty
          ? Duration(
              milliseconds: (recentMetrics
                      .where((m) => m.uploadDuration != null)
                      .map((m) => m.uploadDuration!.inMilliseconds)
                      .fold(0, (sum, duration) => sum + duration) /
                  recentMetrics.length).round())
          : Duration.zero;
      
      _stageMetrics['upload_manager'] = StageMetrics(
        stageName: 'Upload Manager',
        successCount: performanceMetrics['successful_uploads'] ?? 0,
        failureCount: performanceMetrics['failed_uploads'] ?? 0,
        averageProcessingTime: avgProcessingTime,
        errorRate: 100.0 - (performanceMetrics['success_rate']?.toDouble() ?? 0.0),
        errorCategories: Map<String, int>.from(performanceMetrics['error_categories'] ?? {}),
        lastUpdate: DateTime.now(),
      );
      
    } catch (e) {
      debugPrint('⚠️ Failed to collect upload manager metrics: $e');
    }
  }

  /// Evaluate overall pipeline health
  PipelineHealth _evaluateOverallHealth() {
    if (_stageMetrics.isEmpty) {
      return PipelineHealth.offline;
    }
    
    bool hasCriticalIssues = false;
    bool hasDegradedPerformance = false;
    
    for (final metrics in _stageMetrics.values) {
      // Check error rates
      if (metrics.errorRate >= _degradedErrorRateThreshold) {
        hasCriticalIssues = true;
      } else if (metrics.errorRate >= _healthyErrorRateThreshold) {
        hasDegradedPerformance = true;
      }
      
      // Check processing times
      if (metrics.averageProcessingTime >= _degradedProcessingTimeThreshold) {
        hasCriticalIssues = true;
      } else if (metrics.averageProcessingTime >= _healthyProcessingTimeThreshold) {
        hasDegradedPerformance = true;
      }
    }
    
    if (hasCriticalIssues) {
      return PipelineHealth.critical;
    } else if (hasDegradedPerformance) {
      return PipelineHealth.degraded;
    }
    
    return PipelineHealth.healthy;
  }

  /// Check for performance issues and generate alerts
  void _checkPerformanceAlerts() {
    for (final metrics in _stageMetrics.values) {
      _checkStageAlerts(metrics);
    }
    
    // Clean up old alerts
    _alerts.removeWhere((alert) => 
        DateTime.now().difference(alert.timestamp) > _metricsRetentionPeriod);
    
    // Limit alert history
    if (_alerts.length > _alertHistoryLimit) {
      _alerts.removeRange(_alertHistoryLimit, _alerts.length);
    }
  }

  /// Check alerts for a specific stage
  void _checkStageAlerts(StageMetrics metrics) {
    final now = DateTime.now();
    
    // High error rate alert
    if (metrics.errorRate >= _degradedErrorRateThreshold) {
      _addAlert(PerformanceAlert(
        id: '${metrics.stageName.toLowerCase()}_high_error_rate_${now.millisecondsSinceEpoch}',
        level: metrics.errorRate >= 25 ? AlertLevel.critical : AlertLevel.warning,
        title: 'High Error Rate in ${metrics.stageName}',
        description: 'Error rate is ${metrics.errorRate.toStringAsFixed(1)}% (threshold: ${_degradedErrorRateThreshold.toStringAsFixed(1)}%)',
        timestamp: now,
        metadata: {
          'stage': metrics.stageName,
          'error_rate': metrics.errorRate,
          'success_count': metrics.successCount,
          'failure_count': metrics.failureCount,
          'error_categories': metrics.errorCategories,
        },
      ));
    }
    
    // Slow processing alert
    if (metrics.averageProcessingTime >= _degradedProcessingTimeThreshold) {
      _addAlert(PerformanceAlert(
        id: '${metrics.stageName.toLowerCase()}_slow_processing_${now.millisecondsSinceEpoch}',
        level: metrics.averageProcessingTime >= const Duration(minutes: 5) 
            ? AlertLevel.critical 
            : AlertLevel.warning,
        title: 'Slow Processing in ${metrics.stageName}',
        description: 'Average processing time is ${metrics.averageProcessingTime.inSeconds}s',
        timestamp: now,
        metadata: {
          'stage': metrics.stageName,
          'average_processing_time_seconds': metrics.averageProcessingTime.inSeconds,
          'threshold_seconds': _degradedProcessingTimeThreshold.inSeconds,
        },
      ));
    }
    
    // No recent activity alert (if stage has been inactive for >15 minutes)
    final timeSinceLastUpdate = now.difference(metrics.lastUpdate);
    if (timeSinceLastUpdate > const Duration(minutes: 15)) {
      _addAlert(PerformanceAlert(
        id: '${metrics.stageName.toLowerCase()}_inactive_${now.millisecondsSinceEpoch}',
        level: AlertLevel.warning,
        title: '${metrics.stageName} Inactive',
        description: 'No activity detected for ${timeSinceLastUpdate.inMinutes} minutes',
        timestamp: now,
        metadata: {
          'stage': metrics.stageName,
          'inactive_duration_minutes': timeSinceLastUpdate.inMinutes,
          'last_update': metrics.lastUpdate.toIso8601String(),
        },
      ));
    }
  }

  /// Add new alert and notify listeners
  void _addAlert(PerformanceAlert alert) {
    // Check if similar alert already exists (prevent spam)
    final existingSimilar = _alerts.where((existing) => 
        existing.title == alert.title && 
        !existing.isResolved &&
        DateTime.now().difference(existing.timestamp) < const Duration(minutes: 10)
    );
    
    if (existingSimilar.isEmpty) {
      _alerts.insert(0, alert); // Add to front
      _alertController.add(alert);
      
      debugPrint('🚨 ${alert.level.name.toUpperCase()}: ${alert.title}');
      debugPrint('   ${alert.description}');
    }
  }

  /// Get current pipeline health
  PipelineHealth get currentHealth => _currentHealth;

  /// Get health status stream
  Stream<PipelineHealth> get healthStream => _healthController.stream;

  /// Get alerts stream
  Stream<PerformanceAlert> get alertStream => _alertController.stream;

  /// Get current stage metrics
  Map<String, StageMetrics> get stageMetrics => Map.unmodifiable(_stageMetrics);

  /// Get recent alerts
  List<PerformanceAlert> get recentAlerts => List.unmodifiable(_alerts);

  /// Get unresolved alerts
  List<PerformanceAlert> get unresolvedAlerts => 
      _alerts.where((alert) => !alert.isResolved).toList();

  /// Get performance summary
  Map<String, dynamic> getPerformanceSummary() {
    final totalSuccess = _stageMetrics.values.fold(0, (sum, metrics) => sum + metrics.successCount);
    final totalFailures = _stageMetrics.values.fold(0, (sum, metrics) => sum + metrics.failureCount);
    final totalOperations = totalSuccess + totalFailures;
    
    return {
      'overall_health': _currentHealth.name,
      'total_operations': totalOperations,
      'overall_success_rate': totalOperations > 0 ? (totalSuccess / totalOperations * 100) : 0,
      'active_stages': _stageMetrics.length,
      'unresolved_alerts': unresolvedAlerts.length,
      'last_health_check': _lastHealthCheck.toIso8601String(),
      'stage_summary': _stageMetrics.map((name, metrics) => MapEntry(name, {
        'success_rate': metrics.successRate,
        'error_rate': metrics.errorRate,
        'avg_processing_time_seconds': metrics.averageProcessingTime.inSeconds,
      })),
    };
  }

  /// Manual health check trigger
  Future<void> triggerHealthCheck() async {
    debugPrint('🔍 Manual health check triggered');
    await _performHealthCheck();
  }

  /// Resolve an alert
  void resolveAlert(String alertId) {
    final alertIndex = _alerts.indexWhere((alert) => alert.id == alertId);
    if (alertIndex >= 0) {
      final alert = _alerts[alertIndex];
      _alerts[alertIndex] = PerformanceAlert(
        id: alert.id,
        level: alert.level,
        title: alert.title,
        description: alert.description,
        timestamp: alert.timestamp,
        metadata: alert.metadata,
        isResolved: true,
      );
      
      debugPrint('✅ Alert resolved: ${alert.title}');
    }
  }

  /// Dispose of monitoring resources
  void dispose() {
    debugPrint('🔍 Disposing VideoPipelineMonitor');
    
    _healthCheckTimer?.cancel();
    _healthController.close();
    _alertController.close();
    
    _stageMetrics.clear();
    _alerts.clear();
  }
}