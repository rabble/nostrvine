// ABOUTME: Service that auto-sweeps the outgoing_dms queue for partial-
// ABOUTME: delivery rows and dispatches each to DmRepository.recoverSelfWrap.
// ABOUTME: Triggered by app-foreground transitions, mirrors PendingActionService.

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:meta/meta.dart';
import 'package:unified_logger/unified_logger.dart';

/// Backoff configuration for [OutgoingDmRetryService].
///
/// Defaults match `PendingActionRetryConfig` (5 retries, 2s → 5min,
/// 2× backoff) — same precedent epic #3912 cites.
class OutgoingDmRetryConfig {
  const OutgoingDmRetryConfig({
    this.maxRetries = 5,
    this.initialDelay = const Duration(seconds: 2),
    this.maxDelay = const Duration(minutes: 5),
    this.backoffMultiplier = 2.0,
  });

  final int maxRetries;
  final Duration initialDelay;
  final Duration maxDelay;
  final double backoffMultiplier;

  /// Minimum required gap between attempts for a row whose previous
  /// attempt count is [retryCount]. Clamped at [maxDelay].
  Duration backoffFor(int retryCount) {
    if (retryCount <= 0) return Duration.zero;
    var ms = initialDelay.inMilliseconds.toDouble();
    for (var i = 0; i < retryCount; i++) {
      ms *= backoffMultiplier;
      if (ms >= maxDelay.inMilliseconds) return maxDelay;
    }
    return Duration(milliseconds: ms.round());
  }
}

/// Sweeps the durable `outgoing_dms` queue for rows whose recipient
/// gift wrap landed but whose self-wrap did not, and re-publishes the
/// missing self-wrap via [DmRepository.recoverSelfWrap].
///
/// **Trigger:** [appForegroundStream] transitions to `true`. The
/// provider seeds the stream with the current foreground state on
/// subscription, so the cold-start sweep fires automatically.
///
/// **Re-entrancy:** a sweep already in progress short-circuits the
/// next trigger; the deferred work is picked up on the next foreground
/// transition.
///
/// **Per-row backoff:** rows whose `lastAttemptAt + backoff(retryCount)`
/// is in the future are skipped this pass. `incrementRetry` is called
/// only on a real publish failure so transient repo-not-ready states
/// don't burn the retry budget.
///
/// **Scope today:** `recipient: sent / self: failed` rows dispatch to
/// [DmRepository.recoverSelfWrap]; `recipient: failed` rows dispatch
/// to [DmRepository.recoverFullSend]. App-killed `pending: pending`
/// rows are not in this filter (see
/// [OutgoingDmsDao.getStillPendingForOwner]) and remain the concern of
/// a separate interrupted-send recovery path.
class OutgoingDmRetryService {
  OutgoingDmRetryService({
    required DmRepository dmRepository,
    required OutgoingDmsDao outgoingDmsDao,
    required String userPubkey,
    required Stream<bool> appForegroundStream,
    OutgoingDmRetryConfig retryConfig = const OutgoingDmRetryConfig(),
    DateTime Function() now = DateTime.now,
  }) : _dmRepository = dmRepository,
       _dao = outgoingDmsDao,
       _userPubkey = userPubkey,
       _appForegroundStream = appForegroundStream,
       _retryConfig = retryConfig,
       _now = now;

  final DmRepository _dmRepository;
  final OutgoingDmsDao _dao;
  final String _userPubkey;
  final Stream<bool> _appForegroundStream;
  final OutgoingDmRetryConfig _retryConfig;
  final DateTime Function() _now;

  StreamSubscription<bool>? _foregroundSubscription;
  bool _isInitialized = false;
  bool _isSweeping = false;

  bool get isInitialized => _isInitialized;

  @visibleForTesting
  bool get isSweeping => _isSweeping;

  /// Subscribe to foreground transitions. Idempotent: calling twice is
  /// a no-op so the eager-init read in `main.dart` and any test setup
  /// can coexist safely.
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    _foregroundSubscription = _appForegroundStream.listen((foreground) {
      if (foreground) {
        unawaited(sweep());
      }
    });

    Log.info(
      'initialized for $_userPubkey',
      name: 'OutgoingDmRetryService',
      category: LogCategory.system,
    );
  }

  /// Cancel the foreground subscription and mark the service un-init.
  /// Idempotent.
  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    _foregroundSubscription = null;
    _isInitialized = false;
  }

  /// One pass over the retryable queue. Public so tests can drive it
  /// directly without constructing a foreground stream.
  @visibleForTesting
  Future<void> sweep() async {
    if (_isSweeping) {
      Log.debug(
        'sweep already in progress, skipping',
        name: 'OutgoingDmRetryService',
        category: LogCategory.system,
      );
      return;
    }
    _isSweeping = true;

    try {
      final retryable = await _dao.getRetryableForOwner(
        ownerPubkey: _userPubkey,
        maxRetries: _retryConfig.maxRetries,
      );
      if (retryable.isEmpty) return;

      var processedSelfWrap = 0;
      var failedSelfWrap = 0;
      var processedFullSend = 0;
      var failedFullSend = 0;
      var skippedBackoff = 0;
      var abortedNotReady = false;

      for (final row in retryable) {
        if (abortedNotReady) break;

        // Per-row backoff check before any dispatch.
        final lastAttempt = row.lastAttemptAt;
        if (lastAttempt != null) {
          final gap = _now().difference(lastAttempt);
          final required = _retryConfig.backoffFor(row.retryCount);
          if (gap < required) {
            skippedBackoff++;
            continue;
          }
        }

        if (row.recipientWrapStatus == OutgoingWrapStatus.sent &&
            row.selfWrapStatus == OutgoingWrapStatus.failed) {
          // State A: recipient delivered, self-wrap missing. The
          // canonical case #4124 is closing.
          try {
            final result = await _dmRepository.recoverSelfWrap(rumorId: row.id);
            if (result.success) {
              // recoverSelfWrap deleted the row on success. The bumped
              // retryCount would be moot anyway, so skip incrementRetry.
              processedSelfWrap++;
            } else {
              // Publish failed. recoverSelfWrap already wrote
              // selfWrapStatus=failed + lastError + lastAttemptAt via
              // markSelfWrapStatus; bump the retry counter so the next
              // sweep applies backoff and so the row eventually exits
              // the retryable filter at maxRetries.
              await _dao.incrementRetry(row.id);
              failedSelfWrap++;
            }
          } on Object catch (e, stackTrace) {
            // recoverSelfWrap's contract documents StateError (repo or
            // DAO not initialized) and ArgumentError (row missing /
            // foreign owner) as part of the public surface. Catching
            // them — alongside any unexpected throw from the underlying
            // publish — is the correct behavior here, not a code smell.
            if (e is StateError) {
              // No attempt was made because the repo wasn't ready.
              // Don't bump retry; abort this pass and let the next
              // foreground transition retry once auth is ready.
              Log.warning(
                'repo not ready during sweep; aborting pass: $e',
                name: 'OutgoingDmRetryService',
                category: LogCategory.system,
              );
              abortedNotReady = true;
            } else if (e is ArgumentError) {
              // Row went missing or wrong owner between
              // getRetryableForOwner and dispatch. Terminal for this
              // row — don't bump retry.
              Log.warning(
                'skipping row ${row.id}: $e',
                name: 'OutgoingDmRetryService',
                category: LogCategory.system,
              );
            } else {
              // Unexpected throw before publish completed. Bump retry
              // so backoff applies and the row eventually exits the
              // filter.
              await _dao.incrementRetry(row.id);
              Log.error(
                'recoverSelfWrap threw for ${row.id}: $e',
                name: 'OutgoingDmRetryService',
                category: LogCategory.system,
                error: e,
                stackTrace: stackTrace,
              );
            }
          }
        } else if (row.recipientWrapStatus == OutgoingWrapStatus.failed) {
          // State B: recipient publish itself failed. Replay the
          // full send. NIP-17 receiver-side dedup keys on the rumor
          // id (preserved across retries via `rumor_event_json`), so
          // re-publishing is safe even when the original publish
          // actually landed but the local persist failed.
          try {
            final result = await _dmRepository.recoverFullSend(
              rumorId: row.id,
            );
            if (result.success) {
              // recoverFullSend's success path either deletes the row
              // (full delivery) or promotes it to
              // `recipient: sent / self: failed` (partial). Either
              // way the row exits the recipient-failed filter, so
              // skip incrementRetry.
              processedFullSend++;
            } else {
              // Publish failed again. recoverFullSend already
              // re-marked both wraps failed with the new error via
              // _finalizeAfterRecipientFailure (which writes
              // lastAttemptAt through the DAO codec). Bump the retry
              // counter so backoff applies and the row eventually
              // exits the retryable filter at maxRetries.
              await _dao.incrementRetry(row.id);
              failedFullSend++;
            }
          } on Object catch (e, stackTrace) {
            // Same error policy as the recoverSelfWrap dispatch
            // above. recoverFullSend's contract documents StateError
            // (repo or DAO not initialized) and ArgumentError (row
            // missing / foreign owner) as part of its public surface.
            if (e is StateError) {
              Log.warning(
                'repo not ready during sweep; aborting pass: $e',
                name: 'OutgoingDmRetryService',
                category: LogCategory.system,
              );
              abortedNotReady = true;
            } else if (e is ArgumentError) {
              Log.warning(
                'skipping row ${row.id}: $e',
                name: 'OutgoingDmRetryService',
                category: LogCategory.system,
              );
            } else {
              await _dao.incrementRetry(row.id);
              Log.error(
                'recoverFullSend threw for ${row.id}: $e',
                name: 'OutgoingDmRetryService',
                category: LogCategory.system,
                error: e,
                stackTrace: stackTrace,
              );
            }
          }
        }
      }

      Log.info(
        'sweep complete: '
        'self-wrap-recovered=$processedSelfWrap '
        'self-wrap-failed=$failedSelfWrap '
        'full-send-recovered=$processedFullSend '
        'full-send-failed=$failedFullSend '
        'skipped-backoff=$skippedBackoff '
        'aborted-not-ready=$abortedNotReady',
        name: 'OutgoingDmRetryService',
        category: LogCategory.system,
      );
    } on Object catch (e, stackTrace) {
      Log.error(
        'sweep failed: $e',
        name: 'OutgoingDmRetryService',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _isSweeping = false;
    }
  }
}
