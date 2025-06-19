// ABOUTME: Structured logging utility for debugging video loading, queue, and scrolling issues
// ABOUTME: Provides categorized, contextual logs with correlation IDs for easier debugging

import 'package:flutter/foundation.dart';

enum LogCategory { QUEUE, LIFECYCLE, CACHE, UI, PERF, NOSTR, ERROR }

/// Structured logger for video app debugging
/// 
/// Format: [CATEGORY][Platform] Emoji Message | id: <video_id>, details: {key: value}
/// This allows easy filtering and correlation of logs across the video pipeline
void appLog(LogCategory category, String emoji, String message, {
  String? videoId,
  Map<String, dynamic>? details,
}) {
  if (kDebugMode) {
    final platform = kIsWeb ? 'Web' : 'Mobile';
    final idStr = videoId != null ? 'id: ${videoId.substring(0, 8)}, ' : '';
    final detailsStr = details != null && details.isNotEmpty ? 'details: $details' : '';
    final separator = idStr.isNotEmpty || detailsStr.isNotEmpty ? ' | ' : '';
    
    debugPrint('[${category.name}][$platform] $emoji $message$separator$idStr$detailsStr');
  }
}

/// Log queue state changes for debugging index mismatches
void logQueueState(String trigger, {
  required int allEvents,
  required int readyQueue,
  int? pendingPreload,
  int? cacheControllers,
  Map<String, dynamic>? extraDetails,
}) {
  final details = <String, dynamic>{
    'trigger': trigger,
    'allEvents': allEvents,
    'readyQueue': readyQueue,
    if (pendingPreload != null) 'pendingPreload': pendingPreload,
    if (cacheControllers != null) 'cacheControllers': cacheControllers,
    if (extraDetails != null) ...extraDetails,
  };
  
  appLog(LogCategory.QUEUE, '🚦', 'Queue state updated', details: details);
}

/// Log video lifecycle events with timing
void logVideoLifecycle(String stage, String videoId, {
  int? durationMs,
  String? error,
  Map<String, dynamic>? extraDetails,
}) {
  final details = <String, dynamic>{
    'stage': stage,
    if (durationMs != null) 'duration_ms': durationMs,
    if (error != null) 'error': error,
    if (extraDetails != null) ...extraDetails,
  };
  
  final emoji = error != null ? '❌' : '✅';
  final category = error != null ? LogCategory.ERROR : LogCategory.LIFECYCLE;
  
  appLog(category, emoji, stage, videoId: videoId, details: details);
}

/// Log performance metrics
void logPerformance(String operation, int durationMs, {
  Map<String, dynamic>? details,
}) {
  appLog(LogCategory.PERF, '⏱️', operation, details: {
    'duration_ms': durationMs,
    if (details != null) ...details,
  });
}