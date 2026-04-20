// ABOUTME: Content deletion service for user's own content using NIP-09 delete events
// ABOUTME: Implements kind 5 delete events for Apple App Store compliance and user content management

import 'dart:convert';

import 'package:models/models.dart' hide LogCategory, NIP71VideoKinds;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// Machine-readable reason when [DeleteResult.success] is false.
///
/// Distinguishes **pre-publish** failure causes — these arise before the
/// deletion event has been offered to any relay. Post-publish failures
/// (rejected by relays, transient no-response) are represented via
/// [DeleteResult.outcome] and [DeleteResult.feedback] instead.
enum DeleteFailureKind {
  /// [ContentDeletionService] was not initialized.
  notInitialized,

  /// The video does not belong to the signed-in user.
  notOwner,

  /// User is not authenticated when creating the delete event.
  notAuthenticated,

  /// Signing or constructing the kind 5 delete event failed.
  couldNotSign,

  /// Relay-side publish failure — see [DeleteResult.outcome] and
  /// [DeleteResult.feedback] for details (transient, rejected, etc.).
  publishFailed,

  /// Unexpected error (including outer [deleteContent] catch).
  unknown,
}

/// Delete request result.
///
/// Carries both the pre-publish failure classification ([failureKind]) and
/// the post-publish per-relay outcome ([outcome]) with its mapped user
/// feedback ([feedback]). UI layers pick whichever is populated:
/// [failureKind] for pre-publish errors, [feedback] for relay-level
/// failures.
class DeleteResult {
  const DeleteResult({
    required this.success,
    required this.timestamp,
    this.error,
    this.deleteEventId,
    this.failureKind,
    this.outcome,
    this.feedback,
  });

  final bool success;
  final String? error;
  final String? deleteEventId;
  final DateTime timestamp;

  /// Set when [success] is false; use for localized UI messages driven by
  /// the pre-publish failure cause. `null` when the failure occurred at
  /// the relay round-trip — consult [feedback] in that case.
  final DeleteFailureKind? failureKind;

  /// Per-relay outcome for the deletion publish. `null` when the failure
  /// occurred before the relay round-trip (e.g. event creation failed).
  final PublishOutcome? outcome;

  /// User-facing feedback mapped via [PublishResultMapper]. `null` for
  /// pre-publish failures; populated whenever [outcome] is populated.
  final PublishUserFeedback? feedback;

  static DeleteResult createSuccess({
    required String deleteEventId,
    required PublishOutcome outcome,
    required PublishUserFeedback feedback,
  }) =>
      DeleteResult(
        success: true,
        deleteEventId: deleteEventId,
        outcome: outcome,
        feedback: feedback,
        timestamp: DateTime.now(),
      );

  static DeleteResult failure({
    required String error,
    DeleteFailureKind? failureKind,
    PublishOutcome? outcome,
    PublishUserFeedback? feedback,
  }) =>
      DeleteResult(
        success: false,
        error: error,
        failureKind: failureKind,
        outcome: outcome,
        feedback: feedback,
        timestamp: DateTime.now(),
      );
}

/// Content deletion record for tracking
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class ContentDeletion {
  const ContentDeletion({
    required this.deleteEventId,
    required this.originalEventId,
    required this.reason,
    required this.deletedAt,
    this.additionalContext,
  });
  final String deleteEventId;
  final String originalEventId;
  final String reason;
  final DateTime deletedAt;
  final String? additionalContext;

  Map<String, dynamic> toJson() => {
    'deleteEventId': deleteEventId,
    'originalEventId': originalEventId,
    'reason': reason,
    'deletedAt': deletedAt.toIso8601String(),
    'additionalContext': additionalContext,
  };

  static ContentDeletion fromJson(Map<String, dynamic> json) => ContentDeletion(
    deleteEventId: json['deleteEventId'] as String,
    originalEventId: json['originalEventId'] as String,
    reason: json['reason'] as String,
    deletedAt: DateTime.parse(json['deletedAt'] as String),
    additionalContext: json['additionalContext'] as String?,
  );
}

/// Service for deleting user's own content via NIP-09
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class ContentDeletionService {
  ContentDeletionService({
    required NostrClient nostrService,
    required AuthService authService,
    required SharedPreferences prefs,
  }) : _nostrService = nostrService,
       _authService = authService,
       _prefs = prefs {
    _loadDeletionHistory();
  }
  final NostrClient _nostrService;
  final AuthService _authService;
  final SharedPreferences _prefs;

  static const String deletionsStorageKey = 'content_deletions_history';

  final List<ContentDeletion> _deletionHistory = [];
  bool _isInitialized = false;

  // Getters
  List<ContentDeletion> get deletionHistory =>
      List.unmodifiable(_deletionHistory);
  bool get isInitialized => _isInitialized;

  /// Initialize deletion service
  Future<void> initialize() async {
    try {
      if (!_nostrService.isInitialized) {
        Log.warning(
          'Nostr service not initialized, cannot setup content deletion',
          name: 'ContentDeletionService',
          category: LogCategory.system,
        );
        return;
      }

      _isInitialized = true;
      Log.info(
        'Content deletion service initialized',
        name: 'ContentDeletionService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to initialize content deletion: $e',
        name: 'ContentDeletionService',
        category: LogCategory.system,
      );
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
        return DeleteResult.failure(
          error: 'Deletion service not initialized',
          failureKind: DeleteFailureKind.notInitialized,
        );
      }

      // Verify this is the user's own content
      if (!_isUserOwnContent(video)) {
        return DeleteResult.failure(
          error: 'Can only delete your own content',
          failureKind: DeleteFailureKind.notOwner,
        );
      }

      // Create NIP-09 delete event (kind 5)
      // OpenVine only uses kind 34236 (addressable short videos)
      final createResult = await _createDeleteEvent(
        originalEventId: video.id,
        originalEventKind: NIP71VideoKinds.getPreferredKind(),
        reason: reason,
        additionalContext: additionalContext,
      );

      final deleteEvent = createResult.event;
      if (deleteEvent == null) {
        final kind = createResult.failureKind ?? DeleteFailureKind.unknown;
        return DeleteResult.failure(
          error: _failureMessageForKind(kind),
          failureKind: kind,
        );
      }

      final outcome = await _nostrService.publishEventWithRetry(deleteEvent);
      final feedback = PublishResultMapper.map(outcome);

      if (!outcome.acceptedByAny) {
        Log.error(
          'Delete request rejected by every relay: $outcome',
          name: 'ContentDeletionService',
          category: LogCategory.system,
        );
        // Durable deletion requires at least one relay accept. We do NOT
        // persist to local history on failure — the previous "save
        // locally even on failure" behavior left the UI believing
        // content was deleted while every other client could still see
        // it. The user must retry.
        return DeleteResult.failure(
          error: 'Failed to publish delete request',
          failureKind: DeleteFailureKind.publishFailed,
          outcome: outcome,
          feedback: feedback,
        );
      }

      Log.info(
        'Delete request accepted by ${outcome.acceptedBy.length} relay(s)',
        name: 'ContentDeletionService',
        category: LogCategory.system,
      );

      final deletion = ContentDeletion(
        deleteEventId: deleteEvent.id,
        originalEventId: video.id,
        reason: reason,
        deletedAt: DateTime.now(),
        additionalContext: additionalContext,
      );

      _deletionHistory.add(deletion);
      await _saveDeletionHistory();

      return DeleteResult.createSuccess(
        deleteEventId: deleteEvent.id,
        outcome: outcome,
        feedback: feedback,
      );
    } catch (e) {
      Log.error(
        'Failed to delete content: $e',
        name: 'ContentDeletionService',
        category: LogCategory.system,
      );
      return DeleteResult.failure(
        error: 'Failed to delete content: $e',
        failureKind: DeleteFailureKind.unknown,
      );
    }
  }

  static String _failureMessageForKind(DeleteFailureKind kind) {
    switch (kind) {
      case DeleteFailureKind.notInitialized:
        return 'Deletion service not initialized';
      case DeleteFailureKind.notOwner:
        return 'Can only delete your own content';
      case DeleteFailureKind.notAuthenticated:
        return 'Cannot create delete event: not authenticated';
      case DeleteFailureKind.couldNotSign:
        return 'Failed to create delete event';
      case DeleteFailureKind.publishFailed:
        return 'Failed to publish delete request';
      case DeleteFailureKind.unknown:
        return 'Failed to delete content';
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
  bool hasBeenDeleted(String eventId) =>
      _deletionHistory.any((deletion) => deletion.originalEventId == eventId);

  /// Get deletion record for event
  ContentDeletion? getDeletionForEvent(String eventId) {
    try {
      return _deletionHistory.firstWhere(
        (deletion) => deletion.originalEventId == eventId,
      );
    } catch (e) {
      return null;
    }
  }

  /// Clear old deletion records (privacy cleanup)
  Future<void> clearOldDeletions({
    Duration maxAge = const Duration(days: 90),
  }) async {
    final cutoffDate = DateTime.now().subtract(maxAge);
    final initialCount = _deletionHistory.length;

    _deletionHistory.removeWhere(
      (deletion) => deletion.deletedAt.isBefore(cutoffDate),
    );

    if (_deletionHistory.length != initialCount) {
      await _saveDeletionHistory();

      final removedCount = initialCount - _deletionHistory.length;
      Log.debug(
        '🧹 Cleared $removedCount old deletion records',
        name: 'ContentDeletionService',
        category: LogCategory.system,
      );
    }
  }

  /// Create NIP-09 delete event (kind 5).
  /// On success [event] is non-null and [failureKind] is null; otherwise [event] is null.
  Future<({Event? event, DeleteFailureKind? failureKind})> _createDeleteEvent({
    required String originalEventId,
    required int originalEventKind,
    required String reason,
    String? additionalContext,
  }) async {
    try {
      if (!_authService.isAuthenticated) {
        Log.error(
          'Cannot create delete event: not authenticated',
          name: 'ContentDeletionService',
          category: LogCategory.system,
        );
        return (event: null, failureKind: DeleteFailureKind.notAuthenticated);
      }

      // Build NIP-09 compliant tags (kind 5)
      // Per NIP-09: 'e' tag references event to delete, 'k' tag specifies event kind
      final tags = <List<String>>[
        ['e', originalEventId], // Event being deleted
        [
          'k',
          originalEventKind.toString(),
        ], // Kind of event being deleted (NIP-09)
        ['client', 'diVine'], // Deleting client
      ];

      // Add additional context as tags if provided
      if (additionalContext != null) {
        tags.add(['alt', additionalContext]); // Alternative description
      }

      // Create NIP-09 compliant content
      final deleteContent = _formatNip09DeleteContent(
        reason,
        additionalContext,
      );

      // Create and sign event via AuthService
      final signedEvent = await _authService.createAndSignEvent(
        kind: 5, // NIP-09 delete event kind
        content: deleteContent,
        tags: tags,
      );

      if (signedEvent == null) {
        Log.error(
          'Failed to create and sign NIP-09 delete event',
          name: 'ContentDeletionService',
          category: LogCategory.system,
        );
        return (event: null, failureKind: DeleteFailureKind.couldNotSign);
      }

      Log.info(
        'Created NIP-09 delete event (kind 5): ${signedEvent.id}',
        name: 'ContentDeletionService',
        category: LogCategory.system,
      );
      Log.debug(
        'Deleting: $originalEventId for reason: $reason',
        name: 'ContentDeletionService',
        category: LogCategory.system,
      );

      return (event: signedEvent, failureKind: null);
    } catch (e) {
      Log.error(
        'Failed to create NIP-09 delete event: $e',
        name: 'ContentDeletionService',
        category: LogCategory.system,
      );
      return (event: null, failureKind: DeleteFailureKind.unknown);
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

    buffer.writeln(
      'Content deleted by author via Divine for Apple App Store compliance',
    );
    return buffer.toString();
  }

  /// Check if this is the user's own content
  bool _isUserOwnContent(VideoEvent video) {
    final userPubkey = _authService.currentPublicKeyHex;

    return video.pubkey == userPubkey;
  }

  /// Get delete reason text for common cases
  String _getDeleteReasonText(DeleteReason reason) {
    switch (reason) {
      case DeleteReason.personalChoice:
        return 'Personal choice - no longer wish to share this content';
      case DeleteReason.privacy:
        return 'Privacy concerns';
      case DeleteReason.inaccurate:
        return 'Content is inaccurate or outdated';
      case DeleteReason.appStoreCompliance:
        return 'Apple App Store compliance - content removal request';
      case DeleteReason.inappropriate:
        return 'Content no longer appropriate';
      case DeleteReason.other:
        return 'Other reason';
    }
  }

  /// Load deletion history from persistent storage
  Future<void> _loadDeletionHistory() async {
    try {
      final historyJson = _prefs.getString(deletionsStorageKey);
      if (historyJson != null) {
        final List<dynamic> historyList = json.decode(historyJson);
        _deletionHistory.clear();
        _deletionHistory.addAll(
          historyList.map(
            (json) => ContentDeletion.fromJson(json as Map<String, dynamic>),
          ),
        );
      }
    } catch (e) {
      Log.error(
        'Failed to load deletion history: $e',
        name: 'ContentDeletionService',
        category: LogCategory.system,
      );
    }
  }

  /// Save deletion history to persistent storage
  Future<void> _saveDeletionHistory() async {
    try {
      final historyJson = json.encode(
        _deletionHistory.map((d) => d.toJson()).toList(),
      );
      await _prefs.setString(deletionsStorageKey, historyJson);
    } catch (e) {
      Log.error(
        'Failed to save deletion history: $e',
        name: 'ContentDeletionService',
        category: LogCategory.system,
      );
    }
  }
}

/// Reasons for content deletion
enum DeleteReason {
  personalChoice,
  privacy,
  inaccurate,
  appStoreCompliance,
  inappropriate,
  other,
}
