// ABOUTME: Account deletion service implementing NIP-62 Request to Vanish
// ABOUTME: NIP-62 publish is bounded-retry (5 attempts). Kind-5 batch runs in
// ABOUTME: parallel with a concurrency cap and per-event outcome tracking.

import 'dart:async';

import 'package:meta/meta.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// Maximum concurrent kind-5 deletion publishes. Conservative to avoid
/// triggering relay rate limits during burst deletion of thousands of events.
const int kAccountDeletionBatchConcurrency = 4;

/// Retry policy for NIP-62 account-deletion events. Higher than the default
/// (3 attempts) because a missing NIP-62 event means downstream indexers
/// keep surfacing the account even after the user requested deletion.
const RetryPolicy kNip62RetryPolicy = RetryPolicy(
  maxAttempts: 5,
  timeoutPerAttempt: Duration(seconds: 20),
);

/// Pre-publish failure classification for account deletion.
enum AccountDeletionFailureKind {
  /// Caller was not authenticated / had no pubkey.
  notAuthenticated,

  /// Signing the NIP-62 event failed.
  couldNotSign,

  /// NIP-62 event was published but every relay rejected or timed out.
  /// Consult [DeleteAccountResult.nip62Outcome] / [nip62Feedback] for the
  /// relay-level details.
  nip62Failed,

  /// Unexpected error (outer catch).
  unknown,
}

/// Per-event outcome for a kind-5 batch deletion.
///
/// One [BatchDeletionResult] is produced per [AccountDeletionService.deleteAccount]
/// call when the NIP-62 event landed and the batch ran.
@immutable
class BatchDeletionResult {
  const BatchDeletionResult({
    required this.succeededEventIds,
    required this.failedEventIds,
    required this.feedbacks,
  });

  /// Event IDs for which at least one relay accepted the kind-5 deletion.
  final Set<String> succeededEventIds;

  /// Event IDs whose deletion publish failed across every targeted relay.
  final Set<String> failedEventIds;

  /// Per-event user-facing feedback, keyed by the original event id. Both
  /// succeeded and failed event ids are present; UI filters on
  /// [PublishUserFeedback.retryable] when offering a retry affordance.
  final Map<String, PublishUserFeedback> feedbacks;

  int get total => succeededEventIds.length + failedEventIds.length;

  bool get allSucceeded =>
      failedEventIds.isEmpty && succeededEventIds.isNotEmpty;

  bool get allFailed => succeededEventIds.isEmpty && failedEventIds.isNotEmpty;
}

/// Cooperative cancellation token for an in-flight account deletion.
///
/// In-flight publishes finish naturally; newly-queued publishes are skipped
/// once [cancel] is called. The token cannot be reused after cancellation.
class AccountDeletionCancellationToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() {
    _cancelled = true;
  }
}

/// Result of an account deletion operation.
///
/// [success] is true iff the NIP-62 event landed on at least one relay. The
/// kind-5 batch is allowed to partially fail — those failures are reported
/// via [batch.failedEventIds] and the user can retry the subset without
/// re-signing NIP-62.
@immutable
class DeleteAccountResult {
  const DeleteAccountResult({
    required this.success,
    this.error,
    this.deleteEventId,
    this.failureKind,
    this.nip62Outcome,
    this.nip62Feedback,
    this.batch,
    this.fetchedEvents = const <Event>[],
  });

  final bool success;
  final String? error;

  /// NIP-62 event ID when publish landed on at least one relay.
  final String? deleteEventId;

  /// Classification of the pre-publish / NIP-62 failure. `null` when the
  /// flow succeeded.
  final AccountDeletionFailureKind? failureKind;

  /// Per-relay outcome for the NIP-62 publish. `null` when the failure
  /// occurred before the publish attempt (e.g. not authenticated).
  final PublishOutcome? nip62Outcome;

  /// User-facing feedback for the NIP-62 publish. `null` when
  /// [nip62Outcome] is null.
  final PublishUserFeedback? nip62Feedback;

  /// Result of the kind-5 batch. `null` when the batch was not run (NIP-62
  /// failed, user had no events, or flow aborted before batch started).
  final BatchDeletionResult? batch;

  /// Original user events fetched from relays, retained so Retry-failed can
  /// re-publish kind-5 deletions for the [BatchDeletionResult.failedEventIds]
  /// subset without re-fetching.
  final List<Event> fetchedEvents;

  /// Number of user events for which deletion was successfully published.
  /// Zero when the batch did not run.
  int get deletedEventsCount => batch?.succeededEventIds.length ?? 0;

  static DeleteAccountResult nip62Success({
    required String deleteEventId,
    required PublishOutcome outcome,
    required PublishUserFeedback feedback,
    BatchDeletionResult? batch,
    List<Event> fetchedEvents = const <Event>[],
  }) => DeleteAccountResult(
    success: true,
    deleteEventId: deleteEventId,
    nip62Outcome: outcome,
    nip62Feedback: feedback,
    batch: batch,
    fetchedEvents: fetchedEvents,
  );

  static DeleteAccountResult failure({
    required String error,
    required AccountDeletionFailureKind failureKind,
    PublishOutcome? nip62Outcome,
    PublishUserFeedback? nip62Feedback,
  }) => DeleteAccountResult(
    success: false,
    error: error,
    failureKind: failureKind,
    nip62Outcome: nip62Outcome,
    nip62Feedback: nip62Feedback,
  );
}

/// Service for deleting a user's entire Nostr account via NIP-62.
///
/// Contract:
/// 1. Publish the NIP-62 kind-62 event first using a 5-attempt retry policy.
/// 2. If it never lands on any relay, **abort** — do not issue any kind-5
///    deletion requests. Local auth-state cleanup (performed by the caller)
///    must also be skipped so the user can retry.
/// 3. If NIP-62 lands, run the kind-5 batch in parallel (concurrency 4) with
///    per-event [publishEventWithRetry]. Partial failures are surfaced via
///    [BatchDeletionResult]; the user can retry the failed subset without
///    re-publishing NIP-62.
class AccountDeletionService {
  AccountDeletionService({
    required NostrClient nostrService,
    required AuthService authService,
  }) : _nostrService = nostrService,
       _authService = authService;

  final NostrClient _nostrService;
  final AuthService _authService;

  /// Delete the user's account using NIP-62 Request to Vanish.
  ///
  /// [onProgress] receives `(completed, total)` during the kind-5 batch.
  /// [cancellationToken] lets the user abort mid-batch; in-flight publishes
  /// finish naturally, queued ones are skipped.
  Future<DeleteAccountResult> deleteAccount({
    String? customReason,
    void Function(int completed, int total)? onProgress,
    AccountDeletionCancellationToken? cancellationToken,
  }) async {
    try {
      if (!_authService.isAuthenticated) {
        return DeleteAccountResult.failure(
          error: 'Not authenticated',
          failureKind: AccountDeletionFailureKind.notAuthenticated,
        );
      }

      final pubkey = _authService.currentPublicKeyHex;
      if (pubkey == null || pubkey.isEmpty) {
        return DeleteAccountResult.failure(
          error: 'No pubkey available',
          failureKind: AccountDeletionFailureKind.notAuthenticated,
        );
      }

      final reason =
          customReason ?? 'User requested account deletion via Divine app';

      Log.info(
        'Starting account deletion for pubkey: $pubkey',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );

      // Step 1: Publish the NIP-62 kind-62 event FIRST.
      // If this never lands on any relay, abort the flow — local auth
      // cleanup (handled by the caller) must also be skipped so the user
      // can retry.
      final nip62Event = await createNip62Event(reason: reason);
      if (nip62Event == null) {
        return DeleteAccountResult.failure(
          error: 'Failed to create deletion event',
          failureKind: AccountDeletionFailureKind.couldNotSign,
        );
      }

      final nip62Outcome = await _nostrService.publishEventWithRetry(
        nip62Event,
        policy: kNip62RetryPolicy,
      );
      final nip62Feedback = PublishResultMapper.map(nip62Outcome);

      if (!nip62Outcome.acceptedByAny) {
        Log.error(
          'NIP-62 publish failed, aborting account deletion flow: '
          '$nip62Outcome',
          name: 'AccountDeletionService',
          category: LogCategory.system,
        );
        return DeleteAccountResult.failure(
          error: 'Failed to publish deletion request to relays',
          failureKind: AccountDeletionFailureKind.nip62Failed,
          nip62Outcome: nip62Outcome,
          nip62Feedback: nip62Feedback,
        );
      }

      Log.info(
        'NIP-62 deletion request accepted by '
        '${nip62Outcome.acceptedBy.length} relay(s)',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );

      // Step 2: Run the kind-5 batch.
      final userEvents = await _fetchAllUserEvents(pubkey);
      Log.info(
        'Found ${userEvents.length} events for kind-5 batch deletion',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );

      BatchDeletionResult? batch;
      if (userEvents.isNotEmpty) {
        batch = await _publishDeletionEventsForAll(
          userEvents,
          reason,
          onProgress: onProgress,
          cancellationToken: cancellationToken,
        );
        Log.info(
          'Kind-5 batch complete: '
          '${batch.succeededEventIds.length} succeeded, '
          '${batch.failedEventIds.length} failed',
          name: 'AccountDeletionService',
          category: LogCategory.system,
        );
      }

      return DeleteAccountResult.nip62Success(
        deleteEventId: nip62Event.id,
        outcome: nip62Outcome,
        feedback: nip62Feedback,
        batch: batch,
        fetchedEvents: userEvents,
      );
    } catch (e, stackTrace) {
      Log.error(
        'Account deletion failed: $e\nStack: $stackTrace',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );
      return DeleteAccountResult.failure(
        error: 'Account deletion failed: $e',
        failureKind: AccountDeletionFailureKind.unknown,
      );
    }
  }

  /// Re-run kind-5 deletion for a previously-failed subset.
  ///
  /// Given the full original event list and the set of event IDs that
  /// failed in the first pass, publish kind-5 deletion requests for just
  /// those events. Returns a new [BatchDeletionResult] scoped to the
  /// subset.
  Future<BatchDeletionResult> retryFailedDeletions({
    required List<Event> originalEvents,
    required Set<String> failedEventIds,
    String? customReason,
    void Function(int completed, int total)? onProgress,
    AccountDeletionCancellationToken? cancellationToken,
  }) async {
    final subset = originalEvents
        .where((e) => failedEventIds.contains(e.id))
        .toList();
    if (subset.isEmpty) {
      return const BatchDeletionResult(
        succeededEventIds: <String>{},
        failedEventIds: <String>{},
        feedbacks: <String, PublishUserFeedback>{},
      );
    }
    final reason =
        customReason ?? 'User requested account deletion via Divine app';
    return _publishDeletionEventsForAll(
      subset,
      reason,
      onProgress: onProgress,
      cancellationToken: cancellationToken,
    );
  }

  /// Fetch all events authored by the user from relays.
  Future<List<Event>> _fetchAllUserEvents(String pubkey) async {
    try {
      final filter = Filter(authors: [pubkey], limit: 10000);
      final events = await _nostrService.queryEvents([filter]);
      Log.debug(
        'Fetched ${events.length} events for user $pubkey',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );
      return events;
    } catch (e) {
      Log.error(
        'Failed to fetch user events: $e',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );
      return <Event>[];
    }
  }

  /// Publish NIP-09 kind-5 deletion events for [events] in parallel with
  /// a concurrency cap. Returns per-event outcomes.
  ///
  /// We group by kind (one kind-5 event can reference multiple events of
  /// the same kind via multiple `e` tags), and then publish each grouped
  /// kind-5 event with [publishEventWithRetry]. When a grouped publish
  /// succeeds, every original event id in that group is marked as
  /// succeeded; when it fails, every id is marked as failed.
  Future<BatchDeletionResult> _publishDeletionEventsForAll(
    List<Event> events,
    String reason, {
    int concurrency = kAccountDeletionBatchConcurrency,
    void Function(int completed, int total)? onProgress,
    AccountDeletionCancellationToken? cancellationToken,
  }) async {
    final succeeded = <String>{};
    final failed = <String>{};
    final feedbacks = <String, PublishUserFeedback>{};

    // Group events by kind — kind-5 events can reference many events of the
    // same kind (one `e` tag per). This keeps relay round-trips proportional
    // to the number of distinct kinds rather than the number of events.
    final eventsByKind = <int, List<Event>>{};
    for (final event in events) {
      eventsByKind.putIfAbsent(event.kind, () => []).add(event);
    }

    final groups = eventsByKind.entries.toList();
    final queue = List<MapEntry<int, List<Event>>>.from(groups);
    var completedEvents = 0;
    final total = events.length;

    Future<void> worker() async {
      while (queue.isNotEmpty) {
        if (cancellationToken?.isCancelled ?? false) return;
        final MapEntry<int, List<Event>> entry;
        if (queue.isEmpty) return;
        entry = queue.removeAt(0);

        final kind = entry.key;
        final kindEvents = entry.value;

        final deleteEvent = await _createBatchDeleteEvent(
          events: kindEvents,
          kind: kind,
          reason: reason,
        );

        if (deleteEvent == null) {
          for (final e in kindEvents) {
            failed.add(e.id);
            feedbacks[e.id] = const PublishUserFeedback(
              severity: PublishSeverity.error,
              messageKey: 'publish_rejected_permanent',
              retryable: false,
            );
          }
          completedEvents += kindEvents.length;
          onProgress?.call(completedEvents, total);
          continue;
        }

        final outcome = await _nostrService.publishEventWithRetry(deleteEvent);
        final feedback = PublishResultMapper.map(outcome);

        if (outcome.acceptedByAny) {
          for (final e in kindEvents) {
            succeeded.add(e.id);
            feedbacks[e.id] = feedback;
          }
          Log.debug(
            'Published batch deletion for ${kindEvents.length} '
            'kind $kind events',
            name: 'AccountDeletionService',
            category: LogCategory.system,
          );
        } else {
          for (final e in kindEvents) {
            failed.add(e.id);
            feedbacks[e.id] = feedback;
          }
          Log.warning(
            'Batch deletion for kind $kind failed: $outcome',
            name: 'AccountDeletionService',
            category: LogCategory.system,
          );
        }

        completedEvents += kindEvents.length;
        onProgress?.call(completedEvents, total);
      }
    }

    await Future.wait(List.generate(concurrency, (_) => worker()));

    return BatchDeletionResult(
      succeededEventIds: succeeded,
      failedEventIds: failed,
      feedbacks: feedbacks,
    );
  }

  /// Create NIP-09 kind-5 deletion event for multiple events of the same
  /// kind.
  Future<Event?> _createBatchDeleteEvent({
    required List<Event> events,
    required int kind,
    required String reason,
  }) async {
    try {
      if (!_authService.isAuthenticated) return null;

      final tags = <List<String>>[];
      for (final event in events) {
        tags.add(['e', event.id]);
      }
      tags.add(['k', kind.toString()]);

      return await _authService.createAndSignEvent(
        kind: 5,
        content: reason,
        tags: tags,
      );
    } catch (e) {
      Log.error(
        'Failed to create batch delete event: $e',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );
      return null;
    }
  }

  /// Create NIP-62 kind-62 event with ALL_RELAYS tag.
  Future<Event?> createNip62Event({required String reason}) async {
    try {
      if (!_authService.isAuthenticated) {
        Log.error(
          'Cannot create NIP-62 event: not authenticated',
          name: 'AccountDeletionService',
          category: LogCategory.system,
        );
        return null;
      }

      final pubkey = _authService.currentPublicKeyHex;
      if (pubkey == null || pubkey.isEmpty) {
        Log.error(
          'Cannot create NIP-62 event: no pubkey available',
          name: 'AccountDeletionService',
          category: LogCategory.system,
        );
        return null;
      }

      // NIP-62 requires relay tag with ALL_RELAYS for network-wide deletion.
      final tags = <List<String>>[
        ['relay', 'ALL_RELAYS'],
      ];

      Log.info(
        'Creating NIP-62 event with pubkey: $pubkey, kind: 62, reason: $reason',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );

      final signedEvent = await _authService.createAndSignEvent(
        kind: 62,
        content: reason,
        tags: tags,
      );

      if (signedEvent == null) {
        Log.error(
          'Failed to create and sign NIP-62 event',
          name: 'AccountDeletionService',
          category: LogCategory.system,
        );
        return null;
      }

      Log.info(
        'Created NIP-62 deletion event (kind 62): ${signedEvent.id}',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );
      return signedEvent;
    } catch (e, stackTrace) {
      Log.error(
        'Failed to create NIP-62 event: $e\nStack trace: $stackTrace',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );
      return null;
    }
  }
}
