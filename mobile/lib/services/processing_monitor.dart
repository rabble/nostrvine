// ABOUTME: Service for monitoring video processing pipeline health and performance
// ABOUTME: Tracks metrics, detects anomalies, and provides debugging information

import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

/// Processing stage identifiers
enum ProcessingStage {
  frameCapture,
  frameValidation,
  gifCreation,
  uploading,
  cloudProcessing,
  publishing,
}

/// Processing event types
enum ProcessingEventType {
  stageStarted,
  stageCompleted,
  stageFailed,
  stageRetried,
  memoryWarning,
  performanceWarning,
}

/// Individual processing event
class ProcessingEvent {
  final String sessionId;
  final ProcessingStage stage;
  final ProcessingEventType type;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;
  final String? errorMessage;
  final StackTrace? stackTrace;

  ProcessingEvent({
    required this.sessionId,
    required this.stage,
    required this.type,
    required this.timestamp,
    this.metadata = const {},
    this.errorMessage,
    this.stackTrace,
  });

  Duration get age => DateTime.now().difference(timestamp);
}

/// Processing session metrics
class ProcessingSessionMetrics {
  final String sessionId;
  final DateTime startTime;
  final DateTime? endTime;
  final Map<ProcessingStage, Duration> stageDurations;
  final Map<ProcessingStage, int> stageRetries;
  final List<ProcessingEvent> events;
  final bool wasSuccessful;
  final String? failureReason;
  final Map<String, dynamic> metadata;

  ProcessingSessionMetrics({
    required this.sessionId,
    required this.startTime,
    this.endTime,
    required this.stageDurations,
    required this.stageRetries,
    required this.events,
    required this.wasSuccessful,
    this.failureReason,
    this.metadata = const {},
  });

  Duration? get totalDuration => endTime?.difference(startTime);
  
  double get successRate {
    final completedStages = stageDurations.length;
    final totalStages = ProcessingStage.values.length;
    return completedStages / totalStages;
  }
}

/// Processing health status
class ProcessingHealthStatus {
  final bool isHealthy;
  final int recentSuccesses;
  final int recentFailures;
  final double averageProcessingTime;
  final Map<ProcessingStage, double> stageSuccessRates;
  final List<String> warnings;
  final DateTime lastUpdated;

  ProcessingHealthStatus({
    required this.isHealthy,
    required this.recentSuccesses,
    required this.recentFailures,
    required this.averageProcessingTime,
    required this.stageSuccessRates,
    required this.warnings,
    required this.lastUpdated,
  });

  double get overallSuccessRate {
    final total = recentSuccesses + recentFailures;
    return total > 0 ? recentSuccesses / total : 0.0;
  }
}

/// Monitors video processing pipeline health and performance
class ProcessingMonitor extends ChangeNotifier {
  // Configuration
  static const int maxSessionHistory = 100;
  static const int maxEventHistory = 1000;
  static const Duration sessionTimeout = Duration(minutes: 30);
  static const Duration metricsRetentionPeriod = Duration(hours: 24);
  
  // Performance thresholds
  static const Map<ProcessingStage, Duration> stageTimeoutThresholds = {
    ProcessingStage.frameCapture: Duration(seconds: 30),
    ProcessingStage.frameValidation: Duration(seconds: 10),
    ProcessingStage.gifCreation: Duration(minutes: 2),
    ProcessingStage.uploading: Duration(minutes: 10),
    ProcessingStage.cloudProcessing: Duration(minutes: 5),
    ProcessingStage.publishing: Duration(seconds: 30),
  };

  // State
  final Map<String, ProcessingSessionMetrics> _activeSessions = {};
  final Queue<ProcessingSessionMetrics> _completedSessions = Queue();
  final Queue<ProcessingEvent> _eventHistory = Queue();
  final Map<ProcessingStage, List<Duration>> _stageDurationHistory = {};
  
  // Timers
  Timer? _cleanupTimer;
  Timer? _timeoutCheckTimer;

  ProcessingMonitor() {
    _initialize();
  }

  void _initialize() {
    // Initialize stage duration history
    for (final stage in ProcessingStage.values) {
      _stageDurationHistory[stage] = [];
    }

    // Start periodic cleanup
    _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _cleanupOldData();
    });

    // Start timeout checker
    _timeoutCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkForTimeouts();
    });
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    _timeoutCheckTimer?.cancel();
    super.dispose();
  }

  /// Start monitoring a new processing session
  String startSession({Map<String, dynamic>? metadata}) {
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    
    _activeSessions[sessionId] = ProcessingSessionMetrics(
      sessionId: sessionId,
      startTime: DateTime.now(),
      stageDurations: {},
      stageRetries: {},
      events: [],
      wasSuccessful: false,
      metadata: metadata ?? {},
    );

    _recordEvent(ProcessingEvent(
      sessionId: sessionId,
      stage: ProcessingStage.frameCapture,
      type: ProcessingEventType.stageStarted,
      timestamp: DateTime.now(),
      metadata: metadata ?? {},
    ));

    debugPrint('📊 Started processing session: $sessionId');
    notifyListeners();
    
    return sessionId;
  }

  /// Record stage start
  void recordStageStart(String sessionId, ProcessingStage stage, {Map<String, dynamic>? metadata}) {
    final session = _activeSessions[sessionId];
    if (session == null) {
      debugPrint('⚠️ Unknown session: $sessionId');
      return;
    }

    _recordEvent(ProcessingEvent(
      sessionId: sessionId,
      stage: stage,
      type: ProcessingEventType.stageStarted,
      timestamp: DateTime.now(),
      metadata: metadata ?? {},
    ));

    debugPrint('🎬 Stage started: ${stage.name} for session $sessionId');
  }

  /// Record stage completion
  void recordStageComplete(String sessionId, ProcessingStage stage, {Map<String, dynamic>? metadata}) {
    final session = _activeSessions[sessionId];
    if (session == null) {
      debugPrint('⚠️ Unknown session: $sessionId');
      return;
    }

    // Calculate stage duration
    final stageStartEvent = session.events.lastWhere(
      (e) => e.stage == stage && e.type == ProcessingEventType.stageStarted,
      orElse: () => ProcessingEvent(
        sessionId: sessionId,
        stage: stage,
        type: ProcessingEventType.stageStarted,
        timestamp: DateTime.now(),
      ),
    );

    final duration = DateTime.now().difference(stageStartEvent.timestamp);
    session.stageDurations[stage] = duration;

    // Record duration history
    _stageDurationHistory[stage]!.add(duration);
    if (_stageDurationHistory[stage]!.length > 100) {
      _stageDurationHistory[stage]!.removeAt(0);
    }

    _recordEvent(ProcessingEvent(
      sessionId: sessionId,
      stage: stage,
      type: ProcessingEventType.stageCompleted,
      timestamp: DateTime.now(),
      metadata: {
        'duration_ms': duration.inMilliseconds,
        ...?metadata,
      },
    ));

    // Check for performance warnings
    final threshold = stageTimeoutThresholds[stage];
    if (threshold != null && duration > threshold * 0.8) {
      recordPerformanceWarning(
        sessionId,
        stage,
        'Stage took ${duration.inSeconds}s (threshold: ${threshold.inSeconds}s)',
      );
    }

    debugPrint('✅ Stage completed: ${stage.name} in ${duration.inMilliseconds}ms');
    notifyListeners();
  }

  /// Record stage failure
  void recordStageFailure(
    String sessionId,
    ProcessingStage stage,
    String error, {
    StackTrace? stackTrace,
    Map<String, dynamic>? metadata,
  }) {
    final session = _activeSessions[sessionId];
    if (session == null) {
      debugPrint('⚠️ Unknown session: $sessionId');
      return;
    }

    _recordEvent(ProcessingEvent(
      sessionId: sessionId,
      stage: stage,
      type: ProcessingEventType.stageFailed,
      timestamp: DateTime.now(),
      errorMessage: error,
      stackTrace: stackTrace,
      metadata: metadata ?? {},
    ));

    // Update retry count
    session.stageRetries[stage] = (session.stageRetries[stage] ?? 0) + 1;

    debugPrint('❌ Stage failed: ${stage.name} - $error');
    notifyListeners();
  }

  /// Record stage retry
  void recordStageRetry(String sessionId, ProcessingStage stage, int attemptNumber) {
    _recordEvent(ProcessingEvent(
      sessionId: sessionId,
      stage: stage,
      type: ProcessingEventType.stageRetried,
      timestamp: DateTime.now(),
      metadata: {'attempt': attemptNumber},
    ));

    debugPrint('🔄 Stage retry: ${stage.name} attempt $attemptNumber');
  }

  /// Record memory warning
  void recordMemoryWarning(String sessionId, int availableMemoryMB, int requiredMemoryMB) {
    _recordEvent(ProcessingEvent(
      sessionId: sessionId,
      stage: ProcessingStage.values.first, // Use current stage
      type: ProcessingEventType.memoryWarning,
      timestamp: DateTime.now(),
      metadata: {
        'available_mb': availableMemoryMB,
        'required_mb': requiredMemoryMB,
      },
    ));

    debugPrint('⚠️ Memory warning: ${availableMemoryMB}MB available, ${requiredMemoryMB}MB required');
  }

  /// Record performance warning
  void recordPerformanceWarning(String sessionId, ProcessingStage stage, String warning) {
    _recordEvent(ProcessingEvent(
      sessionId: sessionId,
      stage: stage,
      type: ProcessingEventType.performanceWarning,
      timestamp: DateTime.now(),
      metadata: {'warning': warning},
    ));

    debugPrint('⚠️ Performance warning at ${stage.name}: $warning');
  }

  /// Complete a processing session
  void completeSession(String sessionId, {bool success = true, String? failureReason}) {
    final session = _activeSessions[sessionId];
    if (session == null) {
      debugPrint('⚠️ Unknown session: $sessionId');
      return;
    }

    // Move to completed sessions
    final completedSession = ProcessingSessionMetrics(
      sessionId: session.sessionId,
      startTime: session.startTime,
      endTime: DateTime.now(),
      stageDurations: Map.from(session.stageDurations),
      stageRetries: Map.from(session.stageRetries),
      events: List.from(session.events),
      wasSuccessful: success,
      failureReason: failureReason,
      metadata: Map.from(session.metadata),
    );

    _completedSessions.addLast(completedSession);
    if (_completedSessions.length > maxSessionHistory) {
      _completedSessions.removeFirst();
    }

    _activeSessions.remove(sessionId);

    debugPrint('🏁 Session completed: $sessionId (success: $success)');
    notifyListeners();
  }

  /// Get current health status
  ProcessingHealthStatus getHealthStatus() {
    final recentSessions = _completedSessions.where(
      (s) => DateTime.now().difference(s.startTime) < const Duration(hours: 1),
    ).toList();

    final recentSuccesses = recentSessions.where((s) => s.wasSuccessful).length;
    final recentFailures = recentSessions.length - recentSuccesses;

    // Calculate average processing time
    final successfulSessions = recentSessions.where((s) => s.wasSuccessful && s.totalDuration != null);
    final averageTime = successfulSessions.isEmpty
        ? 0.0
        : successfulSessions.map((s) => s.totalDuration!.inSeconds).reduce((a, b) => a + b) / successfulSessions.length;

    // Calculate stage success rates
    final stageSuccessRates = <ProcessingStage, double>{};
    for (final stage in ProcessingStage.values) {
      final stageEvents = _eventHistory.where((e) => e.stage == stage);
      final completed = stageEvents.where((e) => e.type == ProcessingEventType.stageCompleted).length;
      final failed = stageEvents.where((e) => e.type == ProcessingEventType.stageFailed).length;
      final total = completed + failed;
      stageSuccessRates[stage] = total > 0 ? completed / total : 1.0;
    }

    // Generate warnings
    final warnings = <String>[];
    
    // Check overall success rate
    final overallSuccessRate = recentSessions.isEmpty
        ? 1.0
        : recentSuccesses / recentSessions.length;
    if (overallSuccessRate < 0.8) {
      warnings.add('Low success rate: ${(overallSuccessRate * 100).toStringAsFixed(1)}%');
    }

    // Check for stuck sessions
    final stuckSessions = _activeSessions.values.where(
      (s) => DateTime.now().difference(s.startTime) > sessionTimeout,
    );
    if (stuckSessions.isNotEmpty) {
      warnings.add('${stuckSessions.length} sessions appear stuck');
    }

    // Check stage performance
    for (final stage in ProcessingStage.values) {
      if (stageSuccessRates[stage]! < 0.7) {
        warnings.add('${stage.name} has low success rate: ${(stageSuccessRates[stage]! * 100).toStringAsFixed(1)}%');
      }
    }

    return ProcessingHealthStatus(
      isHealthy: warnings.isEmpty && overallSuccessRate > 0.8,
      recentSuccesses: recentSuccesses,
      recentFailures: recentFailures,
      averageProcessingTime: averageTime,
      stageSuccessRates: stageSuccessRates,
      warnings: warnings,
      lastUpdated: DateTime.now(),
    );
  }

  /// Get session metrics
  ProcessingSessionMetrics? getSessionMetrics(String sessionId) {
    return _activeSessions[sessionId] ?? 
           _completedSessions.firstWhere(
             (s) => s.sessionId == sessionId,
             orElse: () => null as dynamic,
           );
  }

  /// Get recent events for debugging
  List<ProcessingEvent> getRecentEvents({int limit = 50}) {
    return _eventHistory.toList()
        .reversed
        .take(limit)
        .toList();
  }

  /// Get stage performance statistics
  Map<ProcessingStage, Map<String, dynamic>> getStageStatistics() {
    final stats = <ProcessingStage, Map<String, dynamic>>{};

    for (final stage in ProcessingStage.values) {
      final durations = _stageDurationHistory[stage] ?? [];
      if (durations.isEmpty) {
        stats[stage] = {
          'count': 0,
          'average_ms': 0,
          'min_ms': 0,
          'max_ms': 0,
          'p50_ms': 0,
          'p95_ms': 0,
        };
        continue;
      }

      // Sort durations for percentile calculations
      final sorted = List<Duration>.from(durations)
        ..sort((a, b) => a.compareTo(b));

      stats[stage] = {
        'count': durations.length,
        'average_ms': durations.map((d) => d.inMilliseconds).reduce((a, b) => a + b) ~/ durations.length,
        'min_ms': sorted.first.inMilliseconds,
        'max_ms': sorted.last.inMilliseconds,
        'p50_ms': sorted[sorted.length ~/ 2].inMilliseconds,
        'p95_ms': sorted[(sorted.length * 0.95).floor()].inMilliseconds,
      };
    }

    return stats;
  }

  /// Record an event
  void _recordEvent(ProcessingEvent event) {
    final session = _activeSessions[event.sessionId];
    session?.events.add(event);

    _eventHistory.addLast(event);
    if (_eventHistory.length > maxEventHistory) {
      _eventHistory.removeFirst();
    }
  }

  /// Check for timed out sessions
  void _checkForTimeouts() {
    final now = DateTime.now();
    final timedOutSessions = <String>[];

    for (final entry in _activeSessions.entries) {
      final session = entry.value;
      final age = now.difference(session.startTime);

      if (age > sessionTimeout) {
        timedOutSessions.add(entry.key);
      } else {
        // Check individual stage timeouts
        for (final stage in ProcessingStage.values) {
          final lastStageStart = session.events
              .where((e) => e.stage == stage && e.type == ProcessingEventType.stageStarted)
              .lastOrNull;

          if (lastStageStart != null && !session.stageDurations.containsKey(stage)) {
            final stageAge = now.difference(lastStageStart.timestamp);
            final threshold = stageTimeoutThresholds[stage];

            if (threshold != null && stageAge > threshold) {
              recordPerformanceWarning(
                session.sessionId,
                stage,
                'Stage timeout: ${stageAge.inSeconds}s elapsed',
              );
            }
          }
        }
      }
    }

    // Complete timed out sessions
    for (final sessionId in timedOutSessions) {
      completeSession(sessionId, success: false, failureReason: 'Session timeout');
    }
  }

  /// Clean up old data
  void _cleanupOldData() {
    final cutoff = DateTime.now().subtract(metricsRetentionPeriod);

    // Clean up old events
    while (_eventHistory.isNotEmpty && _eventHistory.first.timestamp.isBefore(cutoff)) {
      _eventHistory.removeFirst();
    }

    // Clean up old completed sessions
    while (_completedSessions.isNotEmpty && _completedSessions.first.startTime.isBefore(cutoff)) {
      _completedSessions.removeFirst();
    }

    debugPrint('🧹 Cleaned up old monitoring data');
  }

  /// Export metrics for analysis
  Map<String, dynamic> exportMetrics() {
    return {
      'health_status': {
        'is_healthy': getHealthStatus().isHealthy,
        'success_rate': getHealthStatus().overallSuccessRate,
        'warnings': getHealthStatus().warnings,
      },
      'active_sessions': _activeSessions.length,
      'completed_sessions': _completedSessions.length,
      'stage_statistics': getStageStatistics(),
      'recent_events': getRecentEvents(limit: 20).map((e) => {
        'session': e.sessionId,
        'stage': e.stage.name,
        'type': e.type.name,
        'timestamp': e.timestamp.toIso8601String(),
        'error': e.errorMessage,
      }).toList(),
    };
  }
}