// ABOUTME: Content deletion service for user's own content using NIP-09 delete events
// ABOUTME: Implements kind 5 delete events for Apple App Store compliance and user content management

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nostr_sdk/event.dart';
import 'nostr_service_interface.dart';
import '../models/video_event.dart';

/// Delete request result
class DeleteResult {
  final bool success;
  final String? error;
  final String? deleteEventId;
  final DateTime timestamp;

  const DeleteResult({
    required this.success,
    this.error,
    this.deleteEventId,
    required this.timestamp,
  });

  static DeleteResult createSuccess(String deleteEventId) => DeleteResult(
    success: true,
    deleteEventId: deleteEventId,
    timestamp: DateTime.now(),
  );

  static DeleteResult failure(String error) => DeleteResult(
    success: false,
    error: error,
    timestamp: DateTime.now(),
  );
}

/// Content deletion record for tracking
class ContentDeletion {
  final String deleteEventId;
  final String originalEventId;
  final String reason;
  final DateTime deletedAt;
  final String? additionalContext;

  const ContentDeletion({
    required this.deleteEventId,
    required this.originalEventId,
    required this.reason,
    required this.deletedAt,
    this.additionalContext,
  });

  Map<String, dynamic> toJson() {
    return {
      'deleteEventId': deleteEventId,
      'originalEventId': originalEventId,
      'reason': reason,
      'deletedAt': deletedAt.toIso8601String(),
      'additionalContext': additionalContext,
    };
  }

  static ContentDeletion fromJson(Map<String, dynamic> json) {
    return ContentDeletion(
      deleteEventId: json['deleteEventId'],
      originalEventId: json['originalEventId'],
      reason: json['reason'],
      deletedAt: DateTime.parse(json['deletedAt']),
      additionalContext: json['additionalContext'],
    );
  }
}

/// Service for deleting user's own content via NIP-09
class ContentDeletionService extends ChangeNotifier {
  final INostrService _nostrService;
  final SharedPreferences _prefs;
  
  static const String deletionsStorageKey = 'content_deletions_history';
  
  final List<ContentDeletion> _deletionHistory = [];
  bool _isInitialized = false;

  ContentDeletionService({
    required INostrService nostrService,
    required SharedPreferences prefs,
  }) : _nostrService = nostrService,
       _prefs = prefs {
    _loadDeletionHistory();
  }

  // Getters
  List<ContentDeletion> get deletionHistory => List.unmodifiable(_deletionHistory);
  bool get isInitialized => _isInitialized;

  /// Initialize deletion service
  Future<void> initialize() async {
    try {
      if (!_nostrService.isInitialized) {
        debugPrint('⚠️ Nostr service not initialized, cannot setup content deletion');
        return;
      }

      _isInitialized = true;
      debugPrint('✅ Content deletion service initialized');
    } catch (e) {
      debugPrint('⚠️ Failed to initialize content deletion: $e');
    }
  }

  /// Delete user's own content using NIP-09
  Future<DeleteResult> deleteContent({
    required VideoEvent video,
    required String reason,
    String? additionalContext,
  }) async {
    try {
      if (!_isInitialized) {
        return DeleteResult.failure('Deletion service not initialized');
      }

      // Verify this is the user's own content
      if (!_isUserOwnContent(video)) {
        return DeleteResult.failure('Can only delete your own content');
      }

      // Create NIP-09 delete event (kind 5)
      final deleteEvent = await _createDeleteEvent(
        originalEventId: video.id,
        reason: reason,
        additionalContext: additionalContext,
      );

      if (deleteEvent != null) {
        final broadcastResult = await _nostrService.broadcastEvent(deleteEvent);
        if (broadcastResult.successCount == 0) {
          debugPrint('⚠️ Failed to broadcast delete request to relays');
          // Still save locally even if broadcast fails
        } else {
          debugPrint('📡 Delete request broadcast to ${broadcastResult.successCount} relays');
        }

        // Save deletion to local history
        final deletion = ContentDeletion(
          deleteEventId: deleteEvent.id,
          originalEventId: video.id,
          reason: reason,
          deletedAt: DateTime.now(),
          additionalContext: additionalContext,
        );

        _deletionHistory.add(deletion);
        await _saveDeletionHistory();
        notifyListeners();

        debugPrint('🗑️ Content deletion request submitted: ${deleteEvent.id}');
        return DeleteResult.createSuccess(deleteEvent.id);
      } else {
        return DeleteResult.failure('Failed to create delete event');
      }

    } catch (e) {
      debugPrint('❌ Failed to delete content: $e');
      return DeleteResult.failure('Failed to delete content: $e');
    }
  }

  /// Quick delete with common reasons
  Future<DeleteResult> quickDelete({
    required VideoEvent video,
    required DeleteReason reason,
  }) async {
    final reasonText = _getDeleteReasonText(reason);
    
    return deleteContent(
      video: video,
      reason: reasonText,
      additionalContext: 'Quick delete: ${reason.name}',
    );
  }

  /// Check if content has been deleted by user
  bool hasBeenDeleted(String eventId) {
    return _deletionHistory.any((deletion) => deletion.originalEventId == eventId);
  }

  /// Get deletion record for event
  ContentDeletion? getDeletionForEvent(String eventId) {
    try {
      return _deletionHistory.firstWhere(
        (deletion) => deletion.originalEventId == eventId
      );
    } catch (e) {
      return null;
    }
  }

  /// Clear old deletion records (privacy cleanup)
  Future<void> clearOldDeletions({Duration maxAge = const Duration(days: 90)}) async {
    final cutoffDate = DateTime.now().subtract(maxAge);
    final initialCount = _deletionHistory.length;
    
    _deletionHistory.removeWhere((deletion) => deletion.deletedAt.isBefore(cutoffDate));
    
    if (_deletionHistory.length != initialCount) {
      await _saveDeletionHistory();
      notifyListeners();
      
      final removedCount = initialCount - _deletionHistory.length;
      debugPrint('🧹 Cleared $removedCount old deletion records');
    }
  }

  /// Create NIP-09 delete event (kind 5)
  Future<Event?> _createDeleteEvent({
    required String originalEventId,
    required String reason,
    String? additionalContext,
  }) async {
    try {
      if (!_nostrService.hasKeys) {
        debugPrint('❌ Cannot create delete event: no keys available');
        return null;
      }

      // Build NIP-09 compliant tags (kind 5)
      final tags = <List<String>>[
        ['e', originalEventId], // Event being deleted
        ['client', 'openvine'], // Deleting client
      ];

      // Add additional context as tags if provided
      if (additionalContext != null) {
        tags.add(['alt', additionalContext]); // Alternative description
      }

      // Create NIP-09 compliant content
      final deleteContent = _formatNip09DeleteContent(reason, additionalContext);
      
      // Create kind 5 event using nostr_sdk (same pattern as other events)
      final createdAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final event = Event(
        _nostrService.keyManager.keyPair!.public,
        5, // NIP-09 delete event kind
        tags,
        deleteContent,
        createdAt: createdAt,
      );
      
      // Sign the event
      event.sign(_nostrService.keyManager.keyPair!.private);
      
      debugPrint('🗑️ Created NIP-09 delete event (kind 5): ${event.id}');
      debugPrint('🎯 Deleting: $originalEventId for reason: $reason');
      
      return event;
    } catch (e) {
      debugPrint('❌ Failed to create NIP-09 delete event: $e');
      return null;
    }
  }

  /// Format delete content for NIP-09 compliance (kind 5)
  String _formatNip09DeleteContent(String reason, String? additionalContext) {
    final buffer = StringBuffer();
    buffer.writeln('CONTENT DELETION - NIP-09');
    buffer.writeln('Reason: $reason');
    
    if (additionalContext != null) {
      buffer.writeln('Additional Context: $additionalContext');
    }
    
    buffer.writeln('Content deleted by author via OpenVine for Apple App Store compliance');
    return buffer.toString();
  }

  /// Check if this is the user's own content
  bool _isUserOwnContent(VideoEvent video) {
    final userPubkey = _nostrService.publicKey;
    if (userPubkey == null) return false;
    
    return video.pubkey == userPubkey;
  }

  /// Get delete reason text for common cases
  String _getDeleteReasonText(DeleteReason reason) {
    switch (reason) {
      case DeleteReason.personalChoice:
        return 'Personal choice - no longer wish to share this content';
      case DeleteReason.privacy:
        return 'Privacy concerns - content contains personal information';
      case DeleteReason.inappropriate:
        return 'Content inappropriate - does not meet community standards';
      case DeleteReason.copyrightViolation:
        return 'Copyright violation - content may infringe on intellectual property';
      case DeleteReason.technicalIssues:
        return 'Technical issues - content has quality or playback problems';
      case DeleteReason.other:
        return 'Other reasons - user requested content removal';
    }
  }

  /// Load deletion history from storage
  void _loadDeletionHistory() {
    final historyJson = _prefs.getString(deletionsStorageKey);
    if (historyJson != null) {
      try {
        final List<dynamic> deletionsJson = jsonDecode(historyJson);
        _deletionHistory.clear();
        _deletionHistory.addAll(
          deletionsJson.map((json) => ContentDeletion.fromJson(json))
        );
        debugPrint('📁 Loaded ${_deletionHistory.length} deletions from history');
      } catch (e) {
        debugPrint('⚠️ Failed to load deletion history: $e');
      }
    }
  }

  /// Save deletion history to storage
  Future<void> _saveDeletionHistory() async {
    try {
      final deletionsJson = _deletionHistory
          .map((deletion) => deletion.toJson())
          .toList();
      await _prefs.setString(deletionsStorageKey, jsonEncode(deletionsJson));
    } catch (e) {
      debugPrint('⚠️ Failed to save deletion history: $e');
    }
  }

  @override
  void dispose() {
    // Clean up any active operations
    super.dispose();
  }
}

/// Common delete reasons for user content
enum DeleteReason {
  personalChoice,
  privacy,
  inappropriate,
  copyrightViolation,
  technicalIssues,
  other,
}