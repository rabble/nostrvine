// ABOUTME: Service for managing account-level content warning self-labels
// ABOUTME: Persists labels in SharedPreferences and publishes Kind 1985 events

import 'dart:async';

import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// Result of [AccountLabelService.setAccountLabels].
///
/// On success the local labels are persisted and, when labels are
/// non-empty, the kind 1985 self-label event has been accepted by at
/// least one relay. On failure [feedback] carries the mapped publish
/// feedback for retry UX; the local mutation is rolled back so app state
/// matches the relay.
class AccountLabelResult {
  const AccountLabelResult({
    required this.success,
    this.outcome,
    this.feedback,
  });

  /// Whether the requested mutation is durable (persisted locally and, for
  /// non-empty label sets, accepted by at least one relay).
  final bool success;

  /// Per-relay outcome. `null` when the mutation skipped publishing
  /// (e.g. clearing labels when already empty, unauthenticated user).
  final PublishOutcome? outcome;

  /// Mapped user feedback. `null` iff [outcome] is `null`.
  final PublishUserFeedback? feedback;

  static AccountLabelResult successResult({
    PublishOutcome? outcome,
    PublishUserFeedback? feedback,
  }) => AccountLabelResult(
    success: true,
    outcome: outcome,
    feedback: feedback,
  );

  static AccountLabelResult failure({
    PublishOutcome? outcome,
    PublishUserFeedback? feedback,
  }) => AccountLabelResult(
    success: false,
    outcome: outcome,
    feedback: feedback,
  );
}

/// Service for managing account-level content warning labels.
///
/// Allows creators to declare their account contains sensitive content.
/// Persists labels locally and publishes a Kind 1985 self-label event
/// targeting the creator's own pubkey.
class AccountLabelService {
  AccountLabelService({
    required AuthService authService,
    required NostrClient nostrClient,
  }) : _authService = authService,
       _nostrClient = nostrClient;

  final AuthService _authService;
  final NostrClient _nostrClient;

  /// SharedPreferences key for the account content labels.
  static const String _prefsKey = 'account_content_label';

  final Completer<void> _initCompleter = Completer<void>();

  /// A future that completes when [initialize] has finished loading labels
  /// from SharedPreferences. Await this before reading [defaultVideoLabels]
  /// to avoid a race condition where labels appear empty.
  Future<void> get initialized => _initCompleter.future;

  Set<ContentLabel> _accountLabels = {};

  /// The current account-level content labels (empty if none set).
  Set<ContentLabel> get accountLabels => Set.unmodifiable(_accountLabels);

  /// Whether the user has set any account-level content labels.
  bool get hasAccountLabels => _accountLabels.isNotEmpty;

  /// Returns the default content warnings for new videos based on account
  /// labels.
  ///
  /// Returns an empty set if no account labels are set.
  Set<ContentLabel> get defaultVideoLabels => Set.unmodifiable(_accountLabels);

  /// Initialize by loading persisted labels.
  ///
  /// After this completes, [initialized] resolves and [defaultVideoLabels]
  /// returns the persisted labels.
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_prefsKey);
      _accountLabels = ContentLabel.fromCsv(value);
    } catch (e) {
      Log.error(
        'Error loading account labels: $e',
        name: 'AccountLabelService',
        category: LogCategory.system,
      );
    } finally {
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
    }
  }

  /// Set the account-level content labels and publish a Kind 1985 event.
  ///
  /// Pass an empty set to clear account labels. Clearing is a local-only
  /// operation that never reaches the relay — NIP-32 does not define a
  /// kind 1985 "clear labels" event, so the relay retains the previous
  /// self-label until the creator publishes a new one with content-warning
  /// tags. Callers that need to revoke labels should publish a new empty
  /// kind 1985 via a dedicated relay path.
  ///
  /// For non-empty label sets, this method gates the local commit on a
  /// successful publish: on transient or permanent failure the in-memory
  /// and on-disk state is rolled back to the previous value so the UI
  /// can surface a retryable error.
  Future<AccountLabelResult> setAccountLabels(
    Set<ContentLabel> labels,
  ) async {
    final previousLabels = Set<ContentLabel>.of(_accountLabels);

    // Optimistically update local state so downstream readers see the new
    // value while the publish is in flight.
    _accountLabels = Set.of(labels);
    await _persistLabels(labels);

    // Clearing labels is a local-only operation. The relay already has the
    // previous self-label; without a dedicated "revoke" event kind we
    // cannot durably clear it. Report success so the UI reflects local
    // state; callers that need durable revocation must publish a fresh
    // kind 1985 with the empty content-warning namespace.
    if (labels.isEmpty) {
      Log.info(
        'Cleared account labels locally (no kind 1985 publish)',
        name: 'AccountLabelService',
        category: LogCategory.system,
      );
      return AccountLabelResult.successResult();
    }

    final pubkey = _authService.currentPublicKeyHex;
    if (pubkey == null) {
      Log.warning(
        'Cannot publish account labels - not authenticated',
        name: 'AccountLabelService',
        category: LogCategory.system,
      );
      _accountLabels = previousLabels;
      await _persistLabels(previousLabels);
      return AccountLabelResult.failure();
    }

    final result = await _publishAccountLabels(labels: labels, pubkey: pubkey);
    if (!result.success) {
      // Rollback: restore previous labels in memory and on disk.
      _accountLabels = previousLabels;
      await _persistLabels(previousLabels);
    }
    return result;
  }

  Future<void> _persistLabels(Set<ContentLabel> labels) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final csv = ContentLabel.toCsv(labels);
      if (csv != null) {
        await prefs.setString(_prefsKey, csv);
      } else {
        await prefs.remove(_prefsKey);
      }
    } catch (e) {
      Log.error(
        'Error saving account labels: $e',
        name: 'AccountLabelService',
        category: LogCategory.system,
      );
    }
  }

  /// Publish a Kind 1985 self-label event targeting own pubkey.
  ///
  /// Uses [NostrClient.publishEventWithRetry] so transient failures retry
  /// on a bounded schedule. Returns an [AccountLabelResult] carrying the
  /// per-relay [PublishOutcome] and mapped [PublishUserFeedback].
  ///
  /// Format:
  /// ```json
  /// {
  ///   "kind": 1985,
  ///   "tags": [
  ///     ["L", "content-warning"],
  ///     ["l", "<label1>", "content-warning"],
  ///     ["l", "<label2>", "content-warning"],
  ///     ["p", "<own_pubkey>", "wss://relay.divine.video"]
  ///   ]
  /// }
  /// ```
  Future<AccountLabelResult> _publishAccountLabels({
    required Set<ContentLabel> labels,
    required String pubkey,
  }) async {
    final tags = <List<String>>[
      ['L', 'content-warning'],
      for (final label in labels) ['l', label.value, 'content-warning'],
      ['p', pubkey, 'wss://relay.divine.video'],
    ];

    final event = await _authService.createAndSignEvent(
      kind: 1985,
      content: '',
      tags: tags,
    );

    if (event == null) {
      Log.error(
        'Failed to create Kind 1985 event',
        name: 'AccountLabelService',
        category: LogCategory.system,
      );
      return AccountLabelResult.failure();
    }

    final outcome = await _nostrClient.publishEventWithRetry(event);
    final feedback = PublishResultMapper.map(outcome);

    if (!outcome.acceptedByAny) {
      Log.warning(
        'Account-label publish not accepted by any relay: $outcome',
        name: 'AccountLabelService',
        category: LogCategory.system,
      );
      return AccountLabelResult.failure(outcome: outcome, feedback: feedback);
    }

    Log.info(
      'Published account labels: ${labels.map((l) => l.value).join(", ")}',
      name: 'AccountLabelService',
      category: LogCategory.system,
    );
    return AccountLabelResult.successResult(
      outcome: outcome,
      feedback: feedback,
    );
  }

  /// Build NIP-32 content-warning tags for a Kind 0 profile event.
  ///
  /// Returns an empty list if no account labels are set.
  List<List<String>> buildProfileTags() {
    if (_accountLabels.isEmpty) return const [];
    return [
      ['L', 'content-warning'],
      for (final label in _accountLabels) ['l', label.value, 'content-warning'],
    ];
  }
}
