// ABOUTME: Models for curation publishing status and results
// ABOUTME: Tracks publish state for NIP-51 curations (kind 30005).

/// Status of a curation publish attempt.
///
/// After the migration to [NostrClient.publishEventWithRetry], relay-level
/// retries, timeouts, and backoff are handled inside the client — this
/// status only needs to carry a few UI-visible fields: whether a publish
/// is currently in flight, whether the last publish succeeded, and which
/// relays accepted it.
class CurationPublishStatus {
  const CurationPublishStatus({
    required this.curationId,
    required this.isPublishing,
    required this.isPublished,
    this.lastPublishedAt,
    this.publishedEventId,
    this.lastAttemptAt,
    this.hasFailed = false,
    this.successfulRelays = const [],
  });

  final String curationId;
  final bool isPublishing;
  final bool isPublished;
  final DateTime? lastPublishedAt;
  final String? publishedEventId;
  final DateTime? lastAttemptAt;

  /// Whether the last publish attempt finished without any relay
  /// accepting. The root-cause reason lives on the [PublishOutcome]
  /// returned from [CurationService.publishCuration] — callers that need
  /// a human-readable message should read that outcome's feedback via
  /// [PublishResultMapper], not a string stored on this status.
  final bool hasFailed;

  final List<String> successfulRelays;

  /// UI-friendly status text.
  String get statusText {
    if (isPublishing) return 'Publishing...';
    if (isPublished) {
      if (successfulRelays.isNotEmpty) {
        return 'Published (${successfulRelays.length} relays)';
      }
      return 'Published';
    }
    if (hasFailed) {
      return 'Error publishing';
    }
    return 'Not published';
  }

  /// Whether this status represents an error state.
  bool get isError => !isPublished && !isPublishing && hasFailed;
}

/// Result of a curation publish operation.
///
/// Retained for backwards compatibility with callers that only need a
/// coarse success flag. For per-relay diagnostics and retry affordances,
/// use the richer `CurationResult` returned by
/// `CurationService.publishCuration` (carries `PublishOutcome` +
/// `PublishUserFeedback`).
class CurationPublishResult {
  const CurationPublishResult({
    required this.success,
    required this.successCount,
    required this.totalRelays,
    this.eventId,
    this.errors = const {},
    this.failedRelays = const [],
  });

  final bool success;
  final int successCount;
  final int totalRelays;
  final String? eventId;
  final Map<String, String> errors;
  final List<String> failedRelays;

  @override
  String toString() =>
      'CurationPublishResult(success: $success, $successCount/$totalRelays relays)';
}
