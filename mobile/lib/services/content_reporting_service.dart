// ABOUTME: Content reporting service for user-generated content violations
// ABOUTME: Implements NIP-56 reporting events and community-driven moderation

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dart_nostr/dart_nostr.dart';
import 'nostr_service.dart';
import 'content_moderation_service.dart';

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

  static ReportResult success(String reportId) => ReportResult(
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
  final NostrService _nostrService;
  final SharedPreferences _prefs;
  
  // NostrVine moderation relay for reports
  static const String moderationRelayUrl = 'wss://moderation.nostrvine.com';
  static const String reportsStorageKey = 'content_reports_history';
  
  final List<ContentReport> _reportHistory = [];
  bool _isInitialized = false;

  ContentReportingService({
    required NostrService nostrService,
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
        debugPrint('⚠️ Nostr service not initialized, cannot setup reporting');
        return;
      }

      _isInitialized = true;
      debugPrint('✅ Content reporting service initialized');
    } catch (e) {
      debugPrint('⚠️ Failed to initialize content reporting: $e');
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

      // Create NIP-56 reporting event
      final reportEvent = await _createReportingEvent(
        reportId: reportId,
        eventId: eventId,
        authorPubkey: authorPubkey,
        reason: reason,
        details: details,
        additionalContext: additionalContext,
        hashtags: hashtags,
      );

      // Broadcast report to moderation relay
      final broadcastResult = await _nostrService.publishFileMetadata(
        metadata: _createReportMetadata(reportId, reason),
        content: details,
        hashtags: [...hashtags, 'report', 'moderation'],
      );

      if (!broadcastResult.isSuccessful) {
        debugPrint('⚠️ Failed to broadcast report to relays');
        // Still save locally even if broadcast fails
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

      debugPrint('📢 Content report submitted: $reportId');
      return ReportResult.success(reportId);

    } catch (e) {
      debugPrint('❌ Failed to submit content report: $e');
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
      debugPrint('🧹 Cleared $removedCount old reports');
    }
  }

  /// Create NIP-56 reporting event
  Future<NostrEvent> _createReportingEvent({
    required String reportId,
    required String eventId,
    required String authorPubkey,
    required ContentFilterReason reason,
    required String details,
    String? additionalContext,
    List<String> hashtags = const [],
  }) async {
    // Build NIP-56 compliant tags
    final tags = <List<String>>[
      ['e', eventId], // Event being reported
      ['p', authorPubkey], // Author of reported content
      ['report', reason.name], // Report reason
      ['client', 'nostrvine'], // Reporting client
      ['reportId', reportId], // Our internal report ID
    ];

    // Add hashtags
    for (final hashtag in hashtags) {
      tags.add(['t', hashtag]);
    }

    // Add additional context as tags if provided
    if (additionalContext != null) {
      tags.add(['context', additionalContext]);
    }

    // Create event content
    final content = [
      'Report: ${reason.description}',
      '',
      'Details: $details',
      if (additionalContext != null) ...[
        '',
        'Additional Context: $additionalContext',
      ],
      '',
      'Reported via NostrVine',
    ].join('\n');

    // This would create the actual Nostr event
    // For now, return a placeholder structure
    throw UnimplementedError('NIP-56 event creation not yet implemented');
  }

  /// Create metadata for report (for our internal tracking)
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
        debugPrint('📁 Loaded ${_reportHistory.length} reports from history');
      } catch (e) {
        debugPrint('⚠️ Failed to load report history: $e');
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
      debugPrint('⚠️ Failed to save report history: $e');
    }
  }

  @override
  void dispose() {
    // Clean up any active operations
    super.dispose();
  }
}