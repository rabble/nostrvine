// ABOUTME: Content reporting service for user-generated content violations
// ABOUTME: Implements NIP-56 reporting events (kind 1984) for Apple compliance and community-driven moderation

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nostr_sdk/event.dart';
import 'nostr_service_interface.dart';
import 'content_moderation_service.dart';
import '../utils/unified_logger.dart';

/// Report submission result
class ReportResult {
  final bool success;
  final String? error;
  final String? reportId;
  final DateTime timestamp;

  const ReportResult({
    required this.success,
    this.error,
    this.reportId,
    required this.timestamp,
  });

  static ReportResult createSuccess(String reportId) => ReportResult(
    success: true,
    reportId: reportId,
    timestamp: DateTime.now(),
  );

  static ReportResult failure(String error) => ReportResult(
    success: false,
    error: error,
    timestamp: DateTime.now(),
  );
}

/// Content report data
class ContentReport {
  final String reportId;
  final String eventId;
  final String? authorPubkey;
  final ContentFilterReason reason;
  final String details;
  final DateTime createdAt;
  final String? additionalContext;
  final List<String> tags;

  const ContentReport({
    required this.reportId,
    required this.eventId,
    this.authorPubkey,
    required this.reason,
    required this.details,
    required this.createdAt,
    this.additionalContext,
    this.tags = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'reportId': reportId,
      'eventId': eventId,
      'authorPubkey': authorPubkey,
      'reason': reason.name,
      'details': details,
      'createdAt': createdAt.toIso8601String(),
      'additionalContext': additionalContext,
      'tags': tags,
    };
  }

  static ContentReport fromJson(Map<String, dynamic> json) {
    return ContentReport(
      reportId: json['reportId'],
      eventId: json['eventId'],
      authorPubkey: json['authorPubkey'],
      reason: ContentFilterReason.values.firstWhere(
        (r) => r.name == json['reason'],
        orElse: () => ContentFilterReason.other,
      ),
      details: json['details'],
      createdAt: DateTime.parse(json['createdAt']),
      additionalContext: json['additionalContext'],
      tags: List<String>.from(json['tags'] ?? []),
    );
  }
}

/// Service for reporting inappropriate content
class ContentReportingService extends ChangeNotifier {
  final INostrService _nostrService;
  final SharedPreferences _prefs;
  
  // OpenVine moderation relay for reports
  static const String moderationRelayUrl = 'wss://relay.openvine.co';
  static const String reportsStorageKey = 'content_reports_history';
  
  final List<ContentReport> _reportHistory = [];
  bool _isInitialized = false;

  ContentReportingService({
    required INostrService nostrService,
    required SharedPreferences prefs,
  }) : _nostrService = nostrService,
       _prefs = prefs {
    _loadReportHistory();
  }

  // Getters
  List<ContentReport> get reportHistory => List.unmodifiable(_reportHistory);
  bool get isInitialized => _isInitialized;

  /// Initialize reporting service
  Future<void> initialize() async {
    try {
      // Ensure Nostr service is initialized
      if (!_nostrService.isInitialized) {
        Log.warning('Nostr service not initialized, cannot setup reporting', name: 'ContentReportingService', category: LogCategory.system);
        return;
      }

      _isInitialized = true;
      Log.info('Content reporting service initialized', name: 'ContentReportingService', category: LogCategory.system);
    } catch (e) {
      Log.error('Failed to initialize content reporting: $e', name: 'ContentReportingService', category: LogCategory.system);
    }
  }

  /// Report content for violation
  Future<ReportResult> reportContent({
    required String eventId,
    required String authorPubkey,
    required ContentFilterReason reason,
    required String details,
    String? additionalContext,
    List<String> hashtags = const [],
  }) async {
    try {
      if (!_isInitialized) {
        return ReportResult.failure('Reporting service not initialized');
      }

      // Generate report ID
      final reportId = 'report_${DateTime.now().millisecondsSinceEpoch}';

      // Create and broadcast NIP-56 reporting event (kind 1984)
      final reportEvent = await _createReportingEvent(
        reportId: reportId,
        eventId: eventId,
        authorPubkey: authorPubkey,
        reason: reason,
        details: details,
        additionalContext: additionalContext,
        hashtags: hashtags,
      );

      if (reportEvent != null) {
        final broadcastResult = await _nostrService.broadcastEvent(reportEvent);
        if (broadcastResult.successCount == 0) {
          Log.error('Failed to broadcast report to relays', name: 'ContentReportingService', category: LogCategory.system);
          // Still save locally even if broadcast fails
        } else {
          Log.info('Report broadcast to ${broadcastResult.successCount} relays', name: 'ContentReportingService', category: LogCategory.system);
        }
      }

      // Save report to local history
      final report = ContentReport(
        reportId: reportId,
        eventId: eventId,
        authorPubkey: authorPubkey,
        reason: reason,
        details: details,
        createdAt: DateTime.now(),
        additionalContext: additionalContext,
        tags: hashtags,
      );

      _reportHistory.add(report);
      await _saveReportHistory();
      notifyListeners();

      Log.debug('Content report submitted: $reportId', name: 'ContentReportingService', category: LogCategory.system);
      return ReportResult.createSuccess(reportId);

    } catch (e) {
      Log.error('Failed to submit content report: $e', name: 'ContentReportingService', category: LogCategory.system);
      return ReportResult.failure('Failed to submit report: $e');
    }
  }

  /// Report user for harassment or abuse
  Future<ReportResult> reportUser({
    required String userPubkey,
    required ContentFilterReason reason,
    required String details,
    List<String>? relatedEventIds,
  }) async {
    // Use first related event or create a user-focused report
    final eventId = relatedEventIds?.first ?? 'user_$userPubkey';
    
    return reportContent(
      eventId: eventId,
      authorPubkey: userPubkey,
      reason: reason,
      details: details,
      additionalContext: relatedEventIds != null 
        ? 'Related events: ${relatedEventIds.join(', ')}'
        : null,
      hashtags: ['user-report'],
    );
  }

  /// Quick report for common violations
  Future<ReportResult> quickReport({
    required String eventId,
    required String authorPubkey,
    required ContentFilterReason reason,
  }) async {
    final details = _getQuickReportDetails(reason);
    
    return reportContent(
      eventId: eventId,
      authorPubkey: authorPubkey,
      reason: reason,
      details: details,
      hashtags: ['quick-report'],
    );
  }

  /// Check if content has been reported before
  bool hasBeenReported(String eventId) {
    return _reportHistory.any((report) => report.eventId == eventId);
  }

  /// Get reports for specific event
  List<ContentReport> getReportsForEvent(String eventId) {
    return _reportHistory.where((report) => report.eventId == eventId).toList();
  }

  /// Get reports by user
  List<ContentReport> getReportsByUser(String authorPubkey) {
    return _reportHistory
        .where((report) => report.authorPubkey == authorPubkey)
        .toList();
  }

  /// Get reporting statistics
  Map<String, dynamic> getReportingStats() {
    final reasonCounts = <String, int>{};
    for (final reason in ContentFilterReason.values) {
      reasonCounts[reason.name] = _reportHistory
          .where((report) => report.reason == reason)
          .length;
    }

    final last30Days = DateTime.now().subtract(const Duration(days: 30));
    final recentReports = _reportHistory
        .where((report) => report.createdAt.isAfter(last30Days))
        .length;

    return {
      'totalReports': _reportHistory.length,
      'recentReports': recentReports,
      'reasonBreakdown': reasonCounts,
      'averageReportsPerDay': recentReports / 30,
    };
  }

  /// Clear old reports (privacy cleanup)
  Future<void> clearOldReports({Duration maxAge = const Duration(days: 90)}) async {
    final cutoffDate = DateTime.now().subtract(maxAge);
    final initialCount = _reportHistory.length;
    
    _reportHistory.removeWhere((report) => report.createdAt.isBefore(cutoffDate));
    
    if (_reportHistory.length != initialCount) {
      await _saveReportHistory();
      notifyListeners();
      
      final removedCount = initialCount - _reportHistory.length;
      Log.debug('🧹 Cleared $removedCount old reports', name: 'ContentReportingService', category: LogCategory.system);
    }
  }

  /// Create NIP-56 reporting event (kind 1984) for Apple compliance
  Future<Event?> _createReportingEvent({
    required String reportId,
    required String eventId,
    required String authorPubkey,
    required ContentFilterReason reason,
    required String details,
    String? additionalContext,
    List<String> hashtags = const [],
  }) async {
    try {
      if (!_nostrService.hasKeys) {
        Log.error('Cannot create report event: no keys available', name: 'ContentReportingService', category: LogCategory.system);
        return null;
      }

      // Build NIP-56 compliant tags (kind 1984)
      final tags = <List<String>>[
        ['e', eventId], // Event being reported
        ['p', authorPubkey], // Author of reported content
        ['report', reason.name], // Report reason as per NIP-56
        ['client', 'openvine'], // Reporting client
      ];

      // Add hashtags as 't' tags
      for (final hashtag in hashtags) {
        tags.add(['t', hashtag]);
      }

      // Add additional context as tags if provided
      if (additionalContext != null) {
        tags.add(['alt', additionalContext]); // Alternative description
      }

      // Create NIP-56 compliant content
      final reportContent = _formatNip56ReportContent(reason, details, additionalContext);
      
      // Create kind 1984 event using nostr_sdk (same pattern as video events)
      final createdAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final event = Event(
        _nostrService.keyManager.keyPair!.public,
        1984, // NIP-56 reporting event kind
        tags,
        reportContent,
        createdAt: createdAt,
      );
      
      // Sign the event
      event.sign(_nostrService.keyManager.keyPair!.private);
      
      Log.info('Created NIP-56 report event (kind 1984): ${event.id}', name: 'ContentReportingService', category: LogCategory.system);
      Log.verbose('Tags: ${tags.length}, Content length: ${reportContent.length}', name: 'ContentReportingService', category: LogCategory.system);
      Log.debug('Reporting: $eventId for $reason', name: 'ContentReportingService', category: LogCategory.system);
      
      return event;
    } catch (e) {
      Log.error('Failed to create NIP-56 report event: $e', name: 'ContentReportingService', category: LogCategory.system);
      return null;
    }
  }

  /// Format report content for NIP-56 compliance (kind 1984)
  String _formatNip56ReportContent(ContentFilterReason reason, String details, String? additionalContext) {
    final buffer = StringBuffer();
    buffer.writeln('CONTENT REPORT - NIP-56');
    buffer.writeln('Reason: ${reason.name}');
    buffer.writeln('Details: $details');
    
    if (additionalContext != null) {
      buffer.writeln('Additional Context: $additionalContext');
    }
    
    buffer.writeln('Reported via OpenVine for community safety and Apple App Store compliance');
    return buffer.toString();
  }

  /// Create metadata for report (for our internal tracking)
  // ignore: unused_element
  dynamic _createReportMetadata(String reportId, ContentFilterReason reason) {
    // This would return proper NIP-94 metadata for the report
    // For now, return a placeholder
    return {
      'reportId': reportId,
      'reason': reason.name,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Get quick report details for common violations
  String _getQuickReportDetails(ContentFilterReason reason) {
    switch (reason) {
      case ContentFilterReason.spam:
        return 'This content appears to be spam or unwanted promotional material.';
      case ContentFilterReason.harassment:
        return 'This content contains harassment, bullying, or abusive behavior.';
      case ContentFilterReason.violence:
        return 'This content contains violence, threats, or harmful behavior.';
      case ContentFilterReason.sexualContent:
        return 'This content contains inappropriate sexual or adult material.';
      case ContentFilterReason.copyright:
        return 'This content appears to violate copyright or intellectual property rights.';
      case ContentFilterReason.falseInformation:
        return 'This content contains misinformation or deliberately false information.';
      case ContentFilterReason.csam:
        return 'This content violates child safety policies and may contain illegal material.';
      case ContentFilterReason.other:
        return 'This content violates community guidelines.';
    }
  }

  /// Load report history from storage
  void _loadReportHistory() {
    final historyJson = _prefs.getString(reportsStorageKey);
    if (historyJson != null) {
      try {
        final List<dynamic> reportsJson = jsonDecode(historyJson);
        _reportHistory.clear();
        _reportHistory.addAll(
          reportsJson.map((json) => ContentReport.fromJson(json))
        );
        Log.debug('� Loaded ${_reportHistory.length} reports from history', name: 'ContentReportingService', category: LogCategory.system);
      } catch (e) {
        Log.error('Failed to load report history: $e', name: 'ContentReportingService', category: LogCategory.system);
      }
    }
  }

  /// Save report history to storage
  Future<void> _saveReportHistory() async {
    try {
      final reportsJson = _reportHistory
          .map((report) => report.toJson())
          .toList();
      await _prefs.setString(reportsStorageKey, jsonEncode(reportsJson));
    } catch (e) {
      Log.error('Failed to save report history: $e', name: 'ContentReportingService', category: LogCategory.system);
    }
  }

  @override
  void dispose() {
    // Clean up any active operations
    super.dispose();
  }
}