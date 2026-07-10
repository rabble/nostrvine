// ABOUTME: Foreground-triggered sweep that re-drives undelivered DM reactions
// ABOUTME: (publish failed / interrupted) via DmReactionsRepository, giving
// ABOUTME: reactions the durable retry that DM messages already have.

import 'dart:async';

import 'package:dm_repository/dm_repository.dart';
import 'package:meta/meta.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// Stable identifiers for swallowed-failure sites inside
/// [DmReactionRetryService]. Forwarded as the Crashlytics `reason:` suffix so
/// the dashboard aggregates per site. Colocated with the service (rather than a
/// separate file) so it stays out of the untested-services floor.
abstract class DmReactionRetryServiceReportableSites {
  /// Per-reaction throw in the sweep loop — `retry` raised an unexpected
  /// exception.
  static const String perReactionUnexpectedThrow =
      'DmReactionRetryService.perReactionUnexpectedThrow';

  /// Top-level sweep catch — the sweep loop or repository call raised before
  /// per-reaction dispatch completed.
  static const String sweepTopLevel = 'DmReactionRetryService.sweepTopLevel';
}

/// Backoff + budget configuration for [DmReactionRetryService].
///
/// Mirrors `OutgoingDmRetryConfig` (5 retries, 2 s → 5 min, 2× backoff) so
/// reaction and message retries behave the same. Retry accounting is kept in
/// memory rather than on the `dm_message_reactions` row, so the budget resets
/// on a cold start — bounded further by the foreground-only trigger.
class DmReactionRetryConfig {
  /// Construct a retry config.
  const DmReactionRetryConfig({
    this.maxRetries = 5,
    this.initialDelay = const Duration(seconds: 2),
    this.maxDelay = const Duration(minutes: 5),
    this.backoffMultiplier = 2.0,
    this.interruptedPendingMinAge = const Duration(seconds: 30),
  });

  /// Attempts a single reaction gets before the sweep drops it (a manual
  /// re-tap still works).
  final int maxRetries;

  /// Delay before the first retry after a failure.
  final Duration initialDelay;

  /// Ceiling for the exponential backoff gap.
  final Duration maxDelay;

  /// Growth factor applied per attempt.
  final double backoffMultiplier;

  /// A `'pending'` row younger than this is skipped: its original publish may
  /// still be in flight (a reaction publish caps at 15 s), so re-driving it
  /// now would race the in-flight attempt's own DAO write. Older `'pending'`
  /// rows are app-killed-mid-send survivors, safe to replay.
  final Duration interruptedPendingMinAge;

  /// Minimum gap required before re-attempting a reaction whose previous
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

/// Re-drives undelivered own DM reactions on every app-foreground transition,
/// closing the reliability gap that leaves a reaction lost when its recipient
/// gift wrap fails to land on a flaky relay.
///
/// DM *messages* get this durability from the `outgoing_dms` queue +
/// `OutgoingDmRetryService`; reactions previously had only a manual re-tap.
/// This service reuses the reaction's own durable record — the
/// `dm_message_reactions` row keeps the rumor JSON while `publishStatus` is
/// `'failed'`/`'pending'` — and replays it through
/// [DmReactionsRepository.retry], which requires the relay's NIP-20 `OK`
/// before marking the reaction sent.
///
/// **Trigger:** [appForegroundStream] transitions to `true`. The provider
/// seeds the current foreground state, so the cold-start sweep fires
/// automatically.
///
/// **Re-entrancy:** a sweep already in progress short-circuits the next
/// trigger; the deferred work is picked up on the next foreground transition.
///
/// **Backoff/budget:** per-reaction attempts are tracked in memory. A reaction
/// is skipped until `lastAttempt + backoff(attempts)` elapses and dropped from
/// the sweep once it hits [DmReactionRetryConfig.maxRetries] (a manual re-tap
/// still works). Entries for reactions that are no longer retryable (sent,
/// deleted) are pruned each pass so the maps stay bounded to the live set.
class DmReactionRetryService {
  /// Construct the service. [reactionsRepository] must be the same instance
  /// the UI publishes through, so retried rows share its DAO and credentials.
  DmReactionRetryService({
    required DmReactionsRepository reactionsRepository,
    required Stream<bool> appForegroundStream,
    Stream<void>? retryTriggerStream,
    DmReactionRetryConfig retryConfig = const DmReactionRetryConfig(),
    DateTime Function() now = DateTime.now,
    CrashReportingService? crashReporting,
  }) : _repository = reactionsRepository,
       _appForegroundStream = appForegroundStream,
       _retryTriggerStream = retryTriggerStream,
       _config = retryConfig,
       _now = now,
       _crashReporting = crashReporting ?? CrashReportingService.instance;

  final DmReactionsRepository _repository;
  final Stream<bool> _appForegroundStream;

  /// Fires a sweep on each event, independent of foreground transitions.
  /// Wired to connectivity/relay-reconnection so a reaction (or removal) made
  /// during a brief network drop is re-driven the moment the network returns —
  /// without waiting for the user to background and re-foreground the app.
  final Stream<void>? _retryTriggerStream;

  final DmReactionRetryConfig _config;
  final DateTime Function() _now;
  final CrashReportingService _crashReporting;

  /// Tracking-key prefix for the add/publish retry phase.
  static const String _addPhase = 'add';

  /// Tracking-key prefix for the removal (kind-5) retry phase.
  static const String _deletionPhase = 'del';

  /// Backoff/attempt tracking, keyed by `'<phase>:<rumorId>'`. The phase prefix
  /// keeps the add and deletion budgets separate: a row keeps its rumor id when
  /// it flips from a `failed`/`pending` add to a `deletion_pending` removal, so
  /// a bare-id key would let a removal inherit the add phase's exhausted budget
  /// and never re-drive the kind-5 (the counterparty keeps a reaction you
  /// removed until the next cold start).
  final Map<String, int> _attempts = {};
  final Map<String, DateTime> _lastAttempt = {};

  StreamSubscription<bool>? _foregroundSubscription;
  StreamSubscription<void>? _retryTriggerSubscription;
  bool _isInitialized = false;
  bool _isSweeping = false;

  bool get isInitialized => _isInitialized;

  @visibleForTesting
  bool get isSweeping => _isSweeping;

  /// Subscribe to foreground transitions. Idempotent: calling twice is a
  /// no-op so the eager-init read in `main.dart` and any test setup coexist.
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    _foregroundSubscription = _appForegroundStream.listen((foreground) {
      if (foreground) {
        unawaited(sweep());
      }
    });

    _retryTriggerSubscription = _retryTriggerStream?.listen((_) {
      unawaited(sweep());
    });

    Log.info(
      'initialized',
      name: 'DmReactionRetryService',
      category: LogCategory.system,
    );
  }

  /// Cancel the trigger subscriptions and mark the service un-init.
  /// Idempotent.
  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    _foregroundSubscription = null;
    await _retryTriggerSubscription?.cancel();
    _retryTriggerSubscription = null;
    _isInitialized = false;
  }

  /// One pass over the retryable reactions. Public so tests can drive it
  /// directly without constructing a foreground stream.
  @visibleForTesting
  Future<void> sweep() async {
    if (_isSweeping) {
      Log.debug(
        'sweep already in progress, skipping',
        name: 'DmReactionRetryService',
        category: LogCategory.system,
      );
      return;
    }
    // Repo not credentialed yet (cold start before auth) — `retry` would no-op
    // and burn the attempt budget. Skip; the next foreground transition
    // retries once credentials are wired.
    if (!_repository.isInitialized) return;
    _isSweeping = true;

    try {
      final reactionTargets = await _repository.retryableReactions();
      final deletionTargets = await _repository.retryableDeletions();
      _pruneTracking(<String>{
        for (final t in reactionTargets) '$_addPhase:${t.rumorId}',
        for (final t in deletionTargets) '$_deletionPhase:${t.rumorId}',
      });

      // Adds apply the pending min-age guard (a fresh 'pending' row may still
      // have its original publish in flight). Removals do not: a
      // 'deletion_pending' row is never in-flight for the sweep's purposes.
      final r = await _driveTargets(
        reactionTargets,
        phase: _addPhase,
        applyPendingMinAge: true,
        driver: (t) => _repository.retry(
          rumorId: t.rumorId,
          targetMessageAuthor: t.targetMessageAuthor,
        ),
      );
      final d = await _driveTargets(
        deletionTargets,
        phase: _deletionPhase,
        applyPendingMinAge: false,
        driver: (t) => _repository.retryDeletion(
          rumorId: t.rumorId,
          targetMessageAuthor: t.targetMessageAuthor,
        ),
      );

      Log.info(
        'sweep complete: '
        'reactions(recovered=${r.recovered} failed=${r.failed} '
        'skipped-backoff=${r.skippedBackoff} '
        'skipped-exhausted=${r.skippedExhausted} '
        'skipped-too-young=${r.skippedTooYoung}) '
        'deletions(recovered=${d.recovered} failed=${d.failed} '
        'skipped-backoff=${d.skippedBackoff} '
        'skipped-exhausted=${d.skippedExhausted})',
        name: 'DmReactionRetryService',
        category: LogCategory.system,
      );
    } on Object catch (e, stackTrace) {
      Log.error(
        'sweep failed: $e',
        name: 'DmReactionRetryService',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      unawaited(
        _crashReporting.recordError(
          e,
          stackTrace,
          reason: DmReactionRetryServiceReportableSites.sweepTopLevel,
        ),
      );
    } finally {
      _isSweeping = false;
    }
  }

  /// Drive one list of retry [targets] through [driver]. Backoff/attempt
  /// tracking is keyed by `'<phase>:<rumorId>'` so the add and deletion phases
  /// keep independent budgets even though a row keeps its rumor id across the
  /// `failed`/`pending` → `deletion_pending` lifecycle flip.
  Future<
    ({
      int recovered,
      int failed,
      int skippedBackoff,
      int skippedExhausted,
      int skippedTooYoung,
    })
  >
  _driveTargets(
    List<DmReactionRetryTarget> targets, {
    required String phase,
    required bool applyPendingMinAge,
    required Future<DmReactionPublishResult> Function(DmReactionRetryTarget)
    driver,
  }) async {
    var recovered = 0;
    var failed = 0;
    var skippedBackoff = 0;
    var skippedExhausted = 0;
    var skippedTooYoung = 0;

    for (final target in targets) {
      final id = '$phase:${target.rumorId}';
      final attempts = _attempts[id] ?? 0;

      if (attempts >= _config.maxRetries) {
        skippedExhausted++;
        continue;
      }

      final last = _lastAttempt[id];
      if (last != null) {
        final gap = _now().difference(last);
        if (gap < _config.backoffFor(attempts)) {
          skippedBackoff++;
          continue;
        }
      }

      // A still-`pending` reaction may have an in-flight publish (a reaction
      // publish caps at 15 s); only treat it as interrupted once it's older
      // than the guard, so the sweep never races an in-flight attempt.
      if (applyPendingMinAge && target.publishStatus == 'pending') {
        final age = _now().difference(
          DateTime.fromMillisecondsSinceEpoch(target.createdAt * 1000),
        );
        if (age < _config.interruptedPendingMinAge) {
          skippedTooYoung++;
          continue;
        }
      }

      try {
        final result = await driver(target);
        if (result.success) {
          _attempts.remove(id);
          _lastAttempt.remove(id);
          recovered++;
        } else {
          _attempts[id] = attempts + 1;
          _lastAttempt[id] = _now();
          failed++;
        }
      } on Object catch (e, stackTrace) {
        _attempts[id] = attempts + 1;
        _lastAttempt[id] = _now();
        failed++;
        Log.error(
          'reaction retry threw for $id: $e',
          name: 'DmReactionRetryService',
          category: LogCategory.system,
          error: e,
          stackTrace: stackTrace,
        );
        unawaited(
          _crashReporting.recordError(
            e,
            stackTrace,
            reason: DmReactionRetryServiceReportableSites
                .perReactionUnexpectedThrow,
          ),
        );
      }
    }

    return (
      recovered: recovered,
      failed: failed,
      skippedBackoff: skippedBackoff,
      skippedExhausted: skippedExhausted,
      skippedTooYoung: skippedTooYoung,
    );
  }

  void _pruneTracking(Set<String> liveIds) {
    _attempts.removeWhere((id, _) => !liveIds.contains(id));
    _lastAttempt.removeWhere((id, _) => !liveIds.contains(id));
  }
}
